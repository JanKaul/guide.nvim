-- Resolves an Anchor ({file, symbol?, pattern?, end_pattern?, nth?}) to a
-- buffer and a 0-based, end-inclusive line range. Never guesses: anything
-- missing or ambiguous is an error naming the candidates.

local M = {}

local DEFINITION_TYPES = { "item$", "declaration$", "definition$", "variant$" }

local function is_definition(node)
  local t = node:type()
  for _, suffix in ipairs(DEFINITION_TYPES) do
    if t:find(suffix) then
      return true
    end
  end
  return false
end

local function text(node, buf)
  return vim.treesitter.get_node_text(node, buf)
end

local function field_text(node, field, buf)
  local child = node:field(field)[1]
  return child and text(child, buf) or nil
end

-- `Foo` matches `Foo` and `Foo<T>`.
local function same_type(seg, txt)
  return txt == seg or txt:sub(1, #seg + 1) == seg .. "<"
end

-- Does this definition node carry the name `seg`?
local function matches(node, seg, buf)
  if node:type() == "impl_item" then
    local ty = field_text(node, "type", buf)
    local trait = field_text(node, "trait", buf)
    if not ty then
      return false
    end
    if same_type(seg, ty) then
      return true
    end
    return trait ~= nil and seg == trait .. " for " .. ty
  end
  local name = field_text(node, "name", buf)
  if not name then
    return false
  end
  -- Lua `function M.foo()` / `function M:foo()` match `foo` and `M.foo`.
  return name == seg or name:sub(-#seg - 1) == "." .. seg or name:sub(-#seg - 1) == ":" .. seg
end

local function collect(root, seg, buf, out)
  for child in root:iter_children() do
    if child:named() then
      if is_definition(child) and matches(child, seg, buf) then
        table.insert(out, child)
      end
      collect(child, seg, buf, out)
    end
  end
end

local function describe(node, buf)
  local row = node:range()
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  line = vim.trim(line)
  if #line > 80 then
    line = line:sub(1, 77) .. "..."
  end
  return ("line %d: %s"):format(row + 1, line)
end

local function split_symbol(symbol)
  local segs = {}
  for seg in (symbol .. "::"):gmatch("(.-)::") do
    if seg ~= "" then
      table.insert(segs, vim.trim(seg))
    end
  end
  return segs
end

local function resolve_symbol(buf, lang, symbol)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if not ok or not parser then
    return nil, ("no treesitter parser for '%s'; use a pattern Anchor instead"):format(lang or "?")
  end
  local root = parser:parse()[1]:root()

  local scopes = { root }
  local segs = split_symbol(symbol)
  for i, seg in ipairs(segs) do
    local found = {}
    for _, scope in ipairs(scopes) do
      collect(scope, seg, buf, found)
    end
    if #found == 0 then
      local where = i == 1 and "" or (" inside '%s'"):format(table.concat(segs, "::", 1, i - 1))
      return nil, ("symbol '%s' not found%s"):format(seg, where)
    end
    scopes = found
  end

  if #scopes > 1 then
    -- `Foo` alone means the definition, not its impl blocks.
    local defs = vim.tbl_filter(function(n)
      return n:type() ~= "impl_item"
    end, scopes)
    if #defs == 1 then
      scopes = defs
    end
  end
  if #scopes > 1 then
    local lines = vim.tbl_map(function(n)
      return "  " .. describe(n, buf)
    end, scopes)
    return nil, ("symbol '%s' is ambiguous; qualify it (Outer::inner, or 'Trait for Type' for impls):\n%s"):format(
      symbol,
      table.concat(lines, "\n")
    )
  end

  local srow, _, erow, ecol = scopes[1]:range()
  if ecol == 0 and erow > srow then
    erow = erow - 1
  end
  return { srow, erow }
end

local function find_lines(buf, pattern, first, last)
  local ok, re = pcall(vim.regex, pattern)
  if not ok then
    return nil, ("invalid pattern '%s': %s"):format(pattern, re)
  end
  local hits = {}
  for row = first, last do
    if re:match_line(buf, row) then
      table.insert(hits, row)
    end
  end
  return hits
end

local function resolve_pattern(buf, a, range)
  local first, last = range[1], range[2]
  local hits, err = find_lines(buf, a.pattern, first, last)
  if not hits then
    return nil, err
  end
  local scope = a.symbol and (" inside '%s'"):format(a.symbol) or ""
  if #hits == 0 then
    return nil, ("pattern '%s' not found%s"):format(a.pattern, scope)
  end
  local row
  if a.nth then
    row = hits[a.nth]
    if not row then
      return nil, ("pattern '%s' has %d matches%s, nth=%d is out of range"):format(a.pattern, #hits, scope, a.nth)
    end
  elseif #hits > 1 then
    local lines = {}
    for i, r in ipairs(hits) do
      if i > 10 then
        table.insert(lines, ("  ... %d more"):format(#hits - 10))
        break
      end
      local l = vim.trim(vim.api.nvim_buf_get_lines(buf, r, r + 1, false)[1])
      table.insert(lines, ("  line %d: %s"):format(r + 1, l))
    end
    return nil, ("pattern '%s' matches %d lines%s; make it unique or pass nth:\n%s"):format(
      a.pattern,
      #hits,
      scope,
      table.concat(lines, "\n")
    )
  else
    row = hits[1]
  end

  local erow = row
  if a.end_pattern then
    local ends, e = find_lines(buf, a.end_pattern, row, last)
    if not ends then
      return nil, e
    end
    if #ends == 0 then
      return nil, ("end_pattern '%s' not found after line %d"):format(a.end_pattern, row + 1)
    end
    erow = ends[1]
  end
  return { row, erow }
end

--- Loads `file` into a buffer without showing it.
function M.load(file)
  local path = vim.fn.fnamemodify(vim.fn.expand(file), ":p")
  if vim.fn.filereadable(path) == 0 then
    return nil, ("file not found: %s"):format(path)
  end
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = true
  if vim.bo[buf].filetype == "" then
    local ft = vim.filetype.match({ buf = buf, filename = path })
    if ft then
      vim.bo[buf].filetype = ft
    end
  end
  return buf, path
end

--- @return table|nil resolved {buf, path, start_row, end_row} (0-based, inclusive)
--- @return string|nil error
function M.resolve(a)
  if type(a) ~= "table" or type(a.file) ~= "string" then
    return nil, "Anchor needs a 'file'"
  end
  if not a.symbol and not a.pattern then
    return nil, "Anchor needs a 'symbol' or a 'pattern'"
  end
  local buf, path = M.load(a.file)
  if not buf then
    return nil, path
  end

  local range = { 0, vim.api.nvim_buf_line_count(buf) - 1 }
  if a.symbol then
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    local r, err = resolve_symbol(buf, lang, a.symbol)
    if not r then
      return nil, err
    end
    range = r
  end
  if a.pattern then
    local r, err = resolve_pattern(buf, a, range)
    if not r then
      return nil, err
    end
    range = r
  end
  return { buf = buf, path = path, start_row = range[1], end_row = range[2] }
end

return M
