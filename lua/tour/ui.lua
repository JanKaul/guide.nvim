-- Everything the Tour does to the editor: pick the code window, highlight a
-- Stop with its Label, manage the Sketch split and the quickfix Itinerary.
-- Nothing here moves focus away from the window the developer is in.

local M = {}

M.ns = vim.api.nvim_create_namespace("tour")

local SKETCH_NAME = "tour://sketch"

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
      line_hl_group = "TourStop",
      sign_text = "▎",
      sign_hl_group = "TourBar",
      priority = 50,
    })
  end
  local first = vim.api.nvim_buf_get_lines(r.buf, r.start_row, r.start_row + 1, false)[1] or ""
  local indent = first:match("^%s*")
  vim.api.nvim_buf_set_extmark(r.buf, M.ns, r.start_row, 0, {
    virt_lines = { { { indent .. label, "TourLabel" } } },
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
  vim.wo[sketch_win].winbar = "%#TourLabel#Sketch · " .. title:gsub("%%", "%%%%")
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

function M.quickfix(items)
  vim.fn.setqflist({}, " ", { title = "Tour", items = items })
end

return M
