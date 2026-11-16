-- Public API of guide.nvim. Claude calls these through `bin/nvim-guide`, which goes
-- through `rpc`; every call returns a table that becomes one JSON line.
-- Glossary: see GLOSSARY.md (Tour, Itinerary, Stop, Anchor, Label, Sketch, Detour).

local anchor = require("guide.anchor")
local ui = require("guide.ui")

local M = {}

local state = {
  stops = nil, -- the Itinerary
  current = nil, -- index of the Stop last shown
  code_win = nil,
  sketch_win = nil,
  bufs = {}, -- buffers carrying Tour extmarks
  agent_buf = nil, -- terminal buffer of the agent driving the Tour; kept across Tours
}

local function term_chan(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal") then
    return nil
  end
  local chan = vim.bo[buf].channel
  return chan ~= 0 and chan or nil
end

--- The terminal buffer whose job is `pid` or one of its ancestors.
local function terminal_of(pid)
  local jobs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local chan = term_chan(buf)
    local ok, jpid = pcall(vim.fn.jobpid, chan or -1)
    if chan and ok and jpid > 0 then
      jobs[jpid] = buf
    end
  end
  for _ = 1, 64 do
    if not pid or pid <= 1 then
      return nil
    end
    if jobs[pid] then
      return jobs[pid]
    end
    local ok, info = pcall(vim.api.nvim_get_proc, pid)
    pid = ok and info and info.ppid or nil
  end
end

local function stop_label(i, total, stop)
  local step = stop.step and ("[%s] "):format(stop.step) or ""
  return ("Stop %d/%d · %s%s"):format(i, total, step, stop.label or "")
end

local function has_sketch(args)
  return type(args.sketch) == "string" and args.sketch ~= ""
end

--- Problems with a Stop's Base, checked before anything is shown.
local function base_error(stop, path)
  if stop.base == nil then
    return nil
  end
  return ui.diff_available() or ui.check_base(path, stop.base)
end

--- @return string|nil error
local function render(r, label, stop, args)
  ui.clear(state.bufs)
  ui.close_diff(state.code_win)
  state.code_win = ui.code_win(state.code_win, state.sketch_win)
  ui.show(state.code_win, r, label)
  state.bufs[r.buf] = true

  if has_sketch(args) then
    local ft = args.sketch_ft or vim.bo[r.buf].filetype
    state.sketch_win = ui.sketch(state.code_win, state.sketch_win, args.sketch, ft, label)
  else
    ui.close_sketch(state.sketch_win)
    state.sketch_win = nil
  end

  if stop.base then
    return ui.diff(state.code_win, r.buf, stop.base)
  end
end

--- Sets the Itinerary. `args.stops` is a list of Anchors with `label` and
--- optional `step` (the Plan step it belongs to). Resolves every Anchor and
--- loads the quickfix list; on any failure nothing is set and every error is
--- returned so all of them can be fixed in one go.
function M.itinerary(args)
  local stops = args.stops
  if type(stops) ~= "table" or #stops == 0 then
    return { ok = false, error = "itinerary needs a non-empty 'stops' list" }
  end
  local resolved, errors, items = {}, {}, {}
  for i, stop in ipairs(stops) do
    local r, err = anchor.resolve(stop)
    if r then
      err = base_error(stop, r.path)
    end
    if r and not err then
      resolved[i] = { stop = i, file = r.path, line = r.start_row + 1, end_line = r.end_row + 1 }
      table.insert(items, {
        filename = r.path,
        lnum = r.start_row + 1,
        end_lnum = r.end_row + 1,
        text = stop_label(i, #stops, stop),
      })
    else
      table.insert(errors, { stop = i, error = err })
    end
  end
  if #errors > 0 then
    return { ok = false, error = ("%d of %d Anchors did not resolve"):format(#errors, #stops), errors = errors }
  end

  M.finish()
  state.stops = stops
  ui.quickfix(items)
  return { ok = true, stops = resolved }
end

--- Shows Stop `args.stop` of the Itinerary, or a Detour when `args.detour`
--- (an Anchor with a label) is given. A Detour leaves the position unchanged.
--- Optional `args.sketch` (+ `sketch_ft`) fills the Sketch split; a Stop with
--- a `base` (git revision) instead opens a gitsigns diff against it.
function M.show(args)
  local stop, label, idx
  if args.detour then
    stop = args.detour
    label = "Detour · " .. (stop.label or "")
  else
    if not state.stops then
      return { ok = false, error = "no Itinerary; call itinerary first" }
    end
    idx = tonumber(args.stop)
    stop = idx and state.stops[idx]
    if not stop then
      return { ok = false, error = ("no Stop %s; the Itinerary has %d"):format(tostring(args.stop), #state.stops) }
    end
    label = stop_label(idx, #state.stops, stop)
  end

  if stop.base and has_sketch(args) then
    return { ok = false, error = "a Stop shows either a Sketch or a Base diff, not both" }
  end
  local r, err = anchor.resolve(stop)
  if r then
    err = base_error(stop, r.path)
  end
  if not r or err then
    return { ok = false, error = err }
  end
  err = render(r, label, stop, args)
  if err then
    return { ok = false, error = err }
  end
  if idx then
    state.current = idx
  end
  return {
    ok = true,
    stop = idx,
    detour = args.detour and true or nil,
    total = state.stops and #state.stops or nil,
    file = r.path,
    line = r.start_row + 1,
    end_line = r.end_row + 1,
  }
end

--- Ends the Tour: clears highlights and closes the Sketch. The quickfix
--- Itinerary is kept so Stops can be revisited.
function M.finish()
  ui.clear(state.bufs)
  ui.close_diff(state.code_win)
  ui.close_sketch(state.sketch_win)
  state.stops, state.current, state.code_win, state.sketch_win, state.bufs = nil, nil, nil, nil, {}
  return { ok = true }
end

function M.status()
  return {
    ok = true,
    active = state.stops ~= nil,
    current = state.current,
    total = state.stops and #state.stops or nil,
    cwd = vim.fn.getcwd(),
  }
end

--- Jumps the cursor to the current Stop (for :GuideStop).
function M.goto_current()
  if not (state.stops and state.current) then
    vim.notify("guide: no Stop shown yet", vim.log.levels.WARN)
    return
  end
  local r, err = anchor.resolve(state.stops[state.current])
  if not r then
    vim.notify("guide: " .. err, vim.log.levels.WARN)
    return
  end
  -- The developer may have wandered off (another file, closed window): bring
  -- the Stop back into the code window, and leave a jumplist entry so <C-o>
  -- returns to where they were.
  vim.cmd("normal! m'")
  state.code_win = ui.code_win(state.code_win, state.sketch_win)
  vim.api.nvim_set_current_win(state.code_win)
  if vim.api.nvim_win_get_buf(state.code_win) ~= r.buf then
    vim.api.nvim_win_set_buf(state.code_win, r.buf)
  end
  vim.api.nvim_win_set_cursor(state.code_win, { r.start_row + 1, 0 })
end

--- Types `text` into the agent's terminal and submits it, as if the developer
--- had typed it there. The agent's terminal is the one the last `nvim-guide`
--- call came from.
--- @return boolean sent
function M.send(text)
  local chan = term_chan(state.agent_buf)
  if not chan then
    vim.notify("guide: no agent terminal known yet; start a Tour from an agent running in Neovim", vim.log.levels.WARN)
    return false
  end
  -- The trailing CR is the only Enter: interior line breaks become LF, and
  -- multi-line text goes in as one bracketed paste.
  local payload = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  if payload:find("\n", 1, true) then
    payload = "\27[200~" .. payload .. "\27[201~"
  end
  local ok, written = pcall(vim.fn.chansend, chan, payload .. "\r")
  if not ok or written == 0 then
    vim.notify("guide: the agent terminal has exited", vim.log.levels.WARN)
    return false
  end
  return true
end

local COMMANDS = { itinerary = M.itinerary, show = M.show, finish = M.finish, status = M.status }

--- Entry point for `bin/nvim-guide`: `{cmd, payload_file, caller_pid}` in, one
--- JSON string out. The caller's pid identifies the agent's terminal for `send`.
function M.rpc(argv)
  local ok, result = pcall(function()
    local cmd, file = argv[1], argv[2]
    state.agent_buf = terminal_of(tonumber(argv[3])) or state.agent_buf
    local fn = COMMANDS[cmd]
    if not fn then
      return { ok = false, error = ("unknown command '%s'"):format(tostring(cmd)) }
    end
    local args = {}
    if file and file ~= "" then
      local raw = table.concat(vim.fn.readfile(file), "\n")
      if vim.trim(raw) ~= "" then
        local dok, decoded = pcall(vim.json.decode, raw, { luanil = { object = true, array = true } })
        if not dok then
          return { ok = false, error = "payload is not valid JSON: " .. tostring(decoded) }
        end
        args = decoded
      end
    end
    return fn(args)
  end)
  if not ok then
    result = { ok = false, error = "internal error: " .. tostring(result) }
  end
  return vim.json.encode(result)
end

function M.setup()
  -- Highlights are defined in plugin/guide.lua; nothing to configure yet.
end

return M
