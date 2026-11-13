-- Headless tests. Run from the repo root:
--   nvim --headless -u NONE -l tests/run.lua
-- The Rust parser comes from nvim-treesitter's install dir if present.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
vim.cmd("filetype on")
vim.cmd("runtime plugin/tour.lua")

-- gitsigns for the Base diff tests, from lazy.nvim's install dir if present.
local gitsigns_dir = vim.fn.stdpath("data") .. "/lazy/gitsigns.nvim"
local have_gitsigns = vim.fn.isdirectory(gitsigns_dir) == 1
if have_gitsigns then
  vim.opt.rtp:append(gitsigns_dir)
  require("gitsigns").setup({})
end

local fx = root .. "/tests/fixtures/"
local failures, passed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failures = failures + 1
    io.stdout:write(("FAIL %s\n  %s\n"):format(name, err))
  end
end

local function eq(want, got, what)
  if not vim.deep_equal(want, got) then
    error(("%s: want %s, got %s"):format(what or "value", vim.inspect(want), vim.inspect(got)), 2)
  end
end

local function has(haystack, needle)
  if not (haystack or ""):find(needle, 1, true) then
    error(("expected %q in %q"):format(needle, tostring(haystack)), 2)
  end
end

local anchor = require("tour.anchor")

local function lines(a)
  local r, err = anchor.resolve(a)
  assert(r, err)
  return { r.start_row + 1, r.end_row + 1 }
end

local function fails(a)
  local r, err = anchor.resolve(a)
  assert(not r, "expected an error, resolved to " .. vim.inspect(r))
  return err
end

local rs = fx .. "sample.rs"
local lua = fx .. "sample.lua"

test("plugin puts bin/ on PATH", function()
  local bin = root .. "/bin"
  assert(vim.tbl_contains(vim.split(vim.env.PATH, ":", { plain = true }), bin), "bin not on PATH")
  eq(1, vim.fn.executable("nvim-tour"), "nvim-tour executable")
end)

-- Anchor resolution ---------------------------------------------------------

test("struct preferred over its impls", function()
  eq({ 4, 6 }, lines({ file = rs, symbol = "Scheduler" }))
end)
test("method through impl", function()
  eq({ 13, 18 }, lines({ file = rs, symbol = "Scheduler::tick" }))
end)
test("method through trait impl", function()
  eq({ 22, 24 }, lines({ file = rs, symbol = "Scheduler::fmt" }))
end)
test("method in two impls is ambiguous", function()
  local err = fails({ file = rs, symbol = "OptimizeHandler::handle" })
  has(err, "ambiguous")
  has(err, "line 34")
  has(err, "line 40")
end)
test("'Trait for Type' picks the trait impl", function()
  eq({ 34, 36 }, lines({ file = rs, symbol = "Handler for OptimizeHandler::handle" }))
end)
test("pattern inside symbol", function()
  eq({ 14, 14 }, lines({ file = rs, symbol = "Scheduler::tick", pattern = "match" }))
end)
test("ambiguous pattern lists matches", function()
  local err = fails({ file = rs, symbol = "Scheduler::tick", pattern = "Ok(" })
  has(err, "matches 2 lines")
  has(err, "line 15")
end)
test("nth picks a pattern match", function()
  eq({ 16, 16 }, lines({ file = rs, symbol = "Scheduler::tick", pattern = "Ok(", nth = 2 }))
end)
test("end_pattern extends the range", function()
  eq({ 14, 17 }, lines({ file = rs, symbol = "Scheduler::tick", pattern = "match", end_pattern = [[^\s*}]] }))
end)
test("missing symbol", function()
  has(fails({ file = rs, symbol = "Nope" }), "symbol 'Nope' not found")
end)
test("missing nested symbol names the scope", function()
  has(fails({ file = rs, symbol = "Scheduler::nope" }), "inside 'Scheduler'")
end)
test("missing file", function()
  has(fails({ file = fx .. "nope.rs", symbol = "X" }), "file not found")
end)
test("anchor needs symbol or pattern", function()
  has(fails({ file = rs }), "symbol' or a 'pattern'")
end)
test("lua: M.fn by short name", function()
  eq({ 7, 13 }, lines({ file = lua, symbol = "compact" }))
end)
test("lua: M.fn by full name", function()
  eq({ 7, 13 }, lines({ file = lua, symbol = "M.compact" }))
end)
test("lua: local function", function()
  eq({ 3, 5 }, lines({ file = lua, symbol = "helper" }))
end)
test("lua: method", function()
  eq({ 15, 17 }, lines({ file = lua, symbol = "method" }))
end)

-- Tour API through rpc --------------------------------------------------------

local tour = require("tour")
local ns = require("tour.ui").ns

local function rpc(cmd, payload)
  local file = vim.fn.tempname()
  vim.fn.writefile(vim.split(vim.json.encode(payload or vim.empty_dict()), "\n"), file)
  return vim.json.decode(tour.rpc({ cmd, file }))
end

-- Layout: a code window, and a "Claude" window (non-file buffer) with focus.
local code_win = vim.api.nvim_get_current_win()
vim.cmd("vsplit")
local claude_buf = vim.api.nvim_create_buf(false, true)
vim.bo[claude_buf].buftype = "nofile"
vim.api.nvim_set_current_buf(claude_buf)
local claude_win = vim.api.nvim_get_current_win()

local STOPS = {
  { file = rs, symbol = "OptimizeHandler", label = "Entry point", step = "1" },
  { file = rs, symbol = "Scheduler::tick", pattern = "match", label = "Where the decision goes", step = "2" },
  { file = lua, symbol = "compact", label = "Lua side" },
}

test("itinerary reports every bad Anchor and sets nothing", function()
  local res = rpc("itinerary", { stops = { STOPS[1], { file = rs, symbol = "Nope", label = "x" }, { file = rs, label = "y" } } })
  eq(false, res.ok, "ok")
  eq(2, #res.errors, "errors")
  eq(2, res.errors[1].stop, "first bad stop")
  eq(false, rpc("status").active, "active")
end)

test("itinerary resolves and loads quickfix", function()
  local res = rpc("itinerary", { stops = STOPS })
  eq(true, res.ok, "ok")
  eq(3, #res.stops, "stops")
  eq(14, res.stops[2].line, "stop 2 line")
  local qf = vim.fn.getqflist({ title = 1, items = 1 })
  eq("Tour", qf.title, "qf title")
  eq(3, #qf.items, "qf items")
  has(qf.items[2].text, "Stop 2/3 · [2] Where the decision goes")
end)

test("show highlights in code window and keeps focus", function()
  local res = rpc("show", { stop = 2 })
  eq(true, res.ok, "ok")
  eq(claude_win, vim.api.nvim_get_current_win(), "focus")
  eq(rs, vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(code_win)), "code buffer")
  eq(14, vim.api.nvim_win_get_cursor(code_win)[1], "cursor")
  local buf = vim.api.nvim_win_get_buf(code_win)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  local label
  for _, m in ipairs(marks) do
    if m[4].virt_lines then
      label = m[4].virt_lines[1][1][1]
    end
  end
  has(label, "Stop 2/3 · [2] Where the decision goes")
  eq("rust", vim.bo[buf].filetype, "filetype")
end)

test("show with sketch opens the split, without closes it", function()
  local before = #vim.api.nvim_tabpage_list_wins(0)
  eq(true, rpc("show", { stop = 1, sketch = "pub struct CompactionScheduler {\n    todo: (),\n}" }).ok, "ok")
  eq(before + 1, #vim.api.nvim_tabpage_list_wins(0), "sketch opened")
  local sb = vim.fn.bufnr("tour://sketch")
  eq("pub struct CompactionScheduler {", vim.api.nvim_buf_get_lines(sb, 0, 1, false)[1], "sketch text")
  eq("rust", vim.bo[sb].filetype, "sketch ft")
  eq(claude_win, vim.api.nvim_get_current_win(), "focus")

  -- A second Sketch reuses the split.
  rpc("show", { stop = 2, sketch = "fn x() {}" })
  eq(before + 1, #vim.api.nvim_tabpage_list_wins(0), "sketch reused")

  rpc("show", { stop = 3 })
  eq(before, #vim.api.nvim_tabpage_list_wins(0), "sketch closed")
end)

test("only the shown Stop is highlighted", function()
  local rsbuf = vim.fn.bufnr(rs)
  eq(0, #vim.api.nvim_buf_get_extmarks(rsbuf, ns, 0, -1, {}), "old stop cleared")
end)

test("detour keeps the position", function()
  local res = rpc("show", { detour = { file = rs, symbol = "Scheduler::new", label = "constructor" } })
  eq(true, res.ok, "ok")
  eq(true, res.detour, "detour flag")
  eq(3, rpc("status").current, "current unchanged")
end)

test("show errors", function()
  has(rpc("show", { stop = 9 }).error, "no Stop 9")
  has(rpc("bogus").error, "unknown command")
end)

test("bad JSON is reported", function()
  local file = vim.fn.tempname()
  vim.fn.writefile({ "{nope" }, file)
  has(vim.json.decode(tour.rpc({ "show", file })).error, "not valid JSON")
end)

test("finish clears everything but quickfix", function()
  rpc("show", { stop = 1, sketch = "x" })
  eq(true, rpc("finish").ok, "ok")
  eq(0, #vim.api.nvim_buf_get_extmarks(vim.fn.bufnr(rs), ns, 0, -1, {}), "marks")
  eq(2, #vim.api.nvim_tabpage_list_wins(0), "sketch closed")
  eq(false, rpc("status").active, "inactive")
  eq(3, #vim.fn.getqflist(), "quickfix kept")
end)

test(":TourStop returns from another file, <C-o> goes back", function()
  rpc("itinerary", { stops = STOPS })
  rpc("show", { stop = 2 })
  -- Wander off in the code window to another file.
  vim.api.nvim_set_current_win(code_win)
  vim.cmd("edit " .. lua)
  vim.api.nvim_win_set_cursor(code_win, { 10, 0 })
  vim.cmd("TourStop")
  eq(code_win, vim.api.nvim_get_current_win(), "window")
  eq(rs, vim.api.nvim_buf_get_name(0), "back in the Stop's file")
  eq(14, vim.api.nvim_win_get_cursor(0)[1], "at the Stop")
  vim.cmd([[execute "normal! \<C-o>"]])
  eq(lua, vim.api.nvim_buf_get_name(0), "<C-o> file")
  eq(10, vim.api.nvim_win_get_cursor(0)[1], "<C-o> line")
  -- A Detour does not move the Stop :TourStop returns to.
  rpc("show", { detour = { file = lua, symbol = "helper", label = "d" } })
  vim.cmd("TourStop")
  eq(rs, vim.api.nvim_buf_get_name(0), "after detour")
  eq(14, vim.api.nvim_win_get_cursor(0)[1], "after detour line")
  vim.api.nvim_set_current_win(claude_win)
  rpc("finish")
end)

-- Base diffs --------------------------------------------------------------------

local function git(dir, ...)
  local res = vim.system({ "git", "-C", dir, ... }, { text = true }):wait()
  assert(res.code == 0, table.concat({ ... }, " ") .. ": " .. (res.stderr or ""))
end

local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")
local repo_file = repo .. "/lib.rs"
git(repo, "init", "-q")
git(repo, "config", "user.email", "test@example.com")
git(repo, "config", "user.name", "test")
vim.fn.writefile({ "pub fn retry() -> u32 {", "    1", "}" }, repo_file)
git(repo, "add", ".")
git(repo, "commit", "-q", "-m", "one")
vim.fn.writefile({ "pub fn retry() -> u32 {", "    3", "}" }, repo_file)
git(repo, "commit", "-q", "-am", "two")

local function gitsigns_wins()
  local n = 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match("^gitsigns://") then
      n = n + 1
    end
  end
  return n
end

local BASE_STOPS = {
  { file = repo_file, symbol = "retry", label = "with base", base = "HEAD~1" },
  { file = repo_file, symbol = "retry", label = "without base" },
}

test("itinerary reports an unknown Base", function()
  local res = rpc("itinerary", { stops = { { file = repo_file, symbol = "retry", label = "x", base = "nope" } } })
  eq(false, res.ok, "ok")
  has(res.errors[1].error, "base 'nope' is not a commit")
end)

test("a Stop with a Base cannot also have a Sketch", function()
  eq(true, rpc("itinerary", { stops = BASE_STOPS }).ok, "itinerary")
  has(rpc("show", { stop = 1, sketch = "x" }).error, "either a Sketch or a Base")
  rpc("finish")
end)

if have_gitsigns then
  test("Base opens a gitsigns diff and keeps focus", function()
    vim.api.nvim_set_current_win(claude_win)
    eq(true, rpc("itinerary", { stops = BASE_STOPS }).ok, "itinerary")
    local res = rpc("show", { stop = 1 })
    eq(true, res.ok, "show: " .. tostring(res.error))
    eq(1, gitsigns_wins(), "diff window")
    eq(claude_win, vim.api.nvim_get_current_win(), "focus")
    local diffs = 0
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.wo[w].diff then
        diffs = diffs + 1
      end
    end
    eq(2, diffs, "both sides in diff mode")
  end)

  test("next Stop without Base closes the diff", function()
    eq(true, rpc("show", { stop = 2 }).ok, "show")
    eq(0, gitsigns_wins(), "diff closed")
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      eq(false, vim.wo[w].diff, "diff off in window " .. w)
    end
  end)

  test("finish closes the diff", function()
    eq(true, rpc("show", { stop = 1 }).ok, "show")
    eq(1, gitsigns_wins(), "diff open")
    rpc("finish")
    eq(0, gitsigns_wins(), "diff closed")
  end)

  test("Detour with a Base", function()
    rpc("itinerary", { stops = BASE_STOPS })
    rpc("show", { stop = 2 })
    local res = rpc("show", { detour = { file = repo_file, symbol = "retry", label = "d", base = "HEAD~1" } })
    eq(true, res.ok, "detour: " .. tostring(res.error))
    eq(1, gitsigns_wins(), "diff open")
    eq(2, rpc("status").current, "position unchanged")
    rpc("finish")
  end)
else
  io.stdout:write("SKIP gitsigns diff tests: " .. gitsigns_dir .. " not found\n")
end

test("without gitsigns a Base is an error", function()
  local saved = package.loaded.gitsigns
  local saved_preload = package.preload.gitsigns
  package.loaded.gitsigns = nil
  package.preload.gitsigns = function()
    error("not installed")
  end
  local res = rpc("itinerary", { stops = BASE_STOPS })
  package.preload.gitsigns = saved_preload
  package.loaded.gitsigns = saved
  eq(false, res.ok, "ok")
  has(res.errors[1].error, "requires gitsigns.nvim")
end)

test("code window falls back when the remembered one is gone", function()
  rpc("itinerary", { stops = STOPS })
  vim.api.nvim_win_close(code_win, true)
  eq(true, rpc("show", { stop = 1 }).ok, "ok")
  eq(claude_win, vim.api.nvim_get_current_win(), "focus")
  eq(2, #vim.api.nvim_tabpage_list_wins(0), "new split")
  rpc("finish")
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failures))
vim.cmd(failures == 0 and "qa!" or "cq!")
