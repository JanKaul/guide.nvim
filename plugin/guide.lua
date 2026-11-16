if vim.g.loaded_guide then
  return
end
vim.g.loaded_guide = true

-- Put bin/ on PATH so Claude, started in a Neovim terminal, can run `nvim-guide`.
local bin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/bin"
if not vim.tbl_contains(vim.split(vim.env.PATH or "", ":", { plain = true }), bin) then
  vim.env.PATH = bin .. ":" .. (vim.env.PATH or "")
end

local function highlights()
  vim.api.nvim_set_hl(0, "GuideStop", { link = "CursorLine", default = true })
  vim.api.nvim_set_hl(0, "GuideBar", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "GuideLabel", { link = "Title", default = true })
end
highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("guide_highlights", { clear = true }),
  callback = highlights,
})

vim.api.nvim_create_user_command("GuideStop", function()
  require("guide").goto_current()
end, { desc = "Jump to the current Tour Stop" })

vim.api.nvim_create_user_command("GuideSend", function(o)
  require("guide").send(o.args)
end, { nargs = "+", desc = "Type text into the agent's terminal and submit it" })

vim.api.nvim_create_user_command("GuideNext", function()
  require("guide").send("next")
end, { desc = "Ask the agent for the next Stop" })

vim.api.nvim_create_user_command("GuideBack", function()
  require("guide").send("back")
end, { desc = "Ask the agent for the previous Stop" })

vim.api.nvim_create_user_command("GuideEnd", function()
  require("guide").finish()
end, { desc = "End the Tour: clear highlights, close the Sketch" })
