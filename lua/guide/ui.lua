-- Everything the Tour does to the editor: pick the code window, highlight a
-- Stop with its Label, manage the Sketch split and the quickfix Itinerary.
-- Nothing here moves focus away from the window the developer is in.

local M = {}

M.ns = vim.api.nvim_create_namespace("guide")

local SKETCH_NAME = "guide://sketch"

local function is_code_win(win, exclude)
  if not win or win == 0 or not vim.api.nvim_win_is_valid(win) or win == exclude then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= SKETCH_NAME
end

--- The window Stops are shown in. Prefers `remembered`, then the previous
--- window, then the widest code window in the tab, else splits off a new one.
function M.code_win(remembered, sketch_win)
  if is_code_win(remembered, sketch_win) then
    return remembered
  end
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if is_code_win(prev, sketch_win) then
    return prev
  end
  local best, width = nil, -1
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_code_win(win, sketch_win) and vim.api.nvim_win_get_width(win) > width then
      best, width = win, vim.api.nvim_win_get_width(win)
    end
  end
  if best then
    return best
  end
  local scratch = vim.api.nvim_create_buf(true, false)
  return vim.api.nvim_open_win(scratch, false, { split = "left", win = vim.api.nvim_get_current_win() })
end

function M.clear(bufs)
  for buf in pairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    end
  end
end

--- Shows a resolved Anchor in `win`, highlighted, with `label` above it.
function M.show(win, r, label)
  if vim.api.nvim_win_get_buf(win) ~= r.buf then
    vim.api.nvim_win_set_buf(win, r.buf)
  end

  for row = r.start_row, r.end_row do
    vim.api.nvim_buf_set_extmark(r.buf, M.ns, row, 0, {
      line_hl_group = "GuideStop",
      sign_text = "▎",
      sign_hl_group = "GuideBar",
      priority = 50,
    })
  end
  local first = vim.api.nvim_buf_get_lines(r.buf, r.start_row, r.start_row + 1, false)[1] or ""
  local indent = first:match("^%s*")
  vim.api.nvim_buf_set_extmark(r.buf, M.ns, r.start_row, 0, {
    virt_lines = { { { indent .. label, "GuideLabel" } } },
    virt_lines_above = true,
  })

  -- A few lines of context above, so the Label's virtual line is visible.
  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview({
      lnum = r.start_row + 1,
      col = 0,
      topline = math.max(1, r.start_row + 1 - 3),
    })
  end)
end

local function sketch_buf()
  local buf = vim.fn.bufnr(SKETCH_NAME)
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, SKETCH_NAME)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  return buf
end

--- Shows `text` in the Sketch split next to `code_win`; returns the window.
function M.sketch(code_win, sketch_win, text, ft, title)
  local buf = sketch_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  if ft and ft ~= "" and vim.bo[buf].filetype ~= ft then
    vim.bo[buf].filetype = ft
  end

  if not (sketch_win and vim.api.nvim_win_is_valid(sketch_win)) then
    sketch_win = vim.api.nvim_open_win(buf, false, {
      split = "right",
      win = code_win,
      width = math.floor(vim.api.nvim_win_get_width(code_win) / 2),
    })
  else
    vim.api.nvim_win_set_buf(sketch_win, buf)
  end
  vim.wo[sketch_win].winbar = "%#GuideLabel#Sketch · " .. title:gsub("%%", "%%%%")
  vim.wo[sketch_win].wrap = false
  vim.api.nvim_win_call(sketch_win, function()
    vim.fn.winrestview({ lnum = 1, topline = 1 })
  end)
  return sketch_win
end

function M.close_sketch(sketch_win)
  if sketch_win and vim.api.nvim_win_is_valid(sketch_win) then
    if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(sketch_win)) > 1 then
      vim.api.nvim_win_close(sketch_win, true)
    end
  end
end

local GITSIGNS_MISSING = "a Base requires gitsigns.nvim (LazyVim core; disabled by the mini-diff extra)"

--- Whether gitsigns is available; returns an error string otherwise.
function M.diff_available()
  if not pcall(require, "gitsigns") then
    return GITSIGNS_MISSING
  end
end

--- Runs an async gitsigns action and waits for its callback.
local function gitsigns_sync(fn, timeout)
  local done, err = false, nil
  fn(function(e)
    done, err = true, e
  end)
  if not vim.wait(timeout or 3000, function()
    return done
  end, 10) then
    return "gitsigns timed out"
  end
  return err
end

local function diff_wins(tab)
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)):match("^gitsigns://") then
      table.insert(wins, win)
    end
  end
  return wins
end

--- Shows the code window's file side by side with `base`, using gitsigns.
--- Keeps the developer in the window (and mode) they were in.
--- @return string|nil error
function M.diff(code_win, buf, base)
  local ok, gs = pcall(require, "gitsigns")
  if not ok then
    return GITSIGNS_MISSING
  end
  local cache = require("gitsigns.cache").cache
  if not cache[buf] then
    -- Loading the file may already have started an attach; a second call
    -- returns at once while that runs, so wait for the cache, not the callback.
    gs.attach({ bufnr = buf })
    if not vim.wait(3000, function()
      return cache[buf] ~= nil
    end, 10) then
      return ("gitsigns could not attach to %s; is it tracked by git?"):format(vim.api.nvim_buf_get_name(buf))
    end
  end

  local tab = vim.api.nvim_win_get_tabpage(code_win)
  local prev_win = vim.api.nvim_get_current_win()
  local was_terminal = vim.api.nvim_get_mode().mode:sub(1, 1) == "t"
  vim.api.nvim_set_current_win(code_win)
  local err = gitsigns_sync(function(cb)
    gs.diffthis(base, { vertical = true }, cb)
  end)
  if vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
    if was_terminal then
      vim.cmd("startinsert")
    end
  end

  if err then
    return ("gitsigns diff against '%s' failed: %s"):format(base, err)
  end
  if #diff_wins(tab) == 0 then
    return ("gitsigns opened no diff against '%s'"):format(base)
  end
end

--- Closes the gitsigns diff (if any) in the code window's tab.
function M.close_diff(code_win)
  if not (code_win and vim.api.nvim_win_is_valid(code_win)) then
    return
  end
  local wins = diff_wins(vim.api.nvim_win_get_tabpage(code_win))
  for _, win in ipairs(wins) do
    pcall(vim.api.nvim_win_close, win, true)
  end
  if #wins > 0 or vim.wo[code_win].diff then
    vim.api.nvim_win_call(code_win, function()
      vim.cmd("diffoff")
    end)
  end
end

--- Checks that `base` names a commit in the repo containing `path`.
--- @return string|nil error
function M.check_base(path, base)
  if type(base) ~= "string" or base == "" then
    return "base must be a non-empty string"
  end
  local res = vim
    .system({ "git", "-C", vim.fn.fnamemodify(path, ":h"), "rev-parse", "--verify", "--quiet", base .. "^{commit}" })
    :wait()
  if res.code ~= 0 then
    return ("base '%s' is not a commit in the repository of %s"):format(base, path)
  end
end

function M.quickfix(items)
  vim.fn.setqflist({}, " ", { title = "Tour", items = items })
end

return M
