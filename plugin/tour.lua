if vim.g.loaded_tour then
  return
end
vim.g.loaded_tour = true

-- Put bin/ on PATH so Claude, started in a Neovim terminal, can run `nvim-tour`.
local bin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/bin"
if not vim.tbl_contains(vim.split(vim.env.PATH or "", ":", { plain = true }), bin) then
  vim.env.PATH = bin .. ":" .. (vim.env.PATH or "")
end

local function highlights()
  vim.api.nvim_set_hl(0, "TourStop", { link = "CursorLine", default = true })
  vim.api.nvim_set_hl(0, "TourBar", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "TourLabel", { link = "Title", default = true })
end
highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("tour_highlights", { clear = true }),
  callback = highlights,
})

vim.api.nvim_create_user_command("TourStop", function()
  require("tour").goto_current()
end, { desc = "Jump to the current Tour Stop" })

vim.api.nvim_create_user_command("TourEnd", function()
  require("tour").finish()
end, { desc = "End the Tour: clear highlights, close the Sketch" })
