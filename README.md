# guide.nvim

Guided Tours of code in Neovim, driven by [Claude Code](https://claude.com/claude-code). Describe what you want to see, and Claude takes you through it Stop by Stop: the code opens and is highlighted in your editor, optionally side by side with an earlier git revision, and the Narration appears in the chat. A Tour of a Plan (a Plan Walkthrough) also shows Sketches of code the Plan would add, before you approve it. See [GLOSSARY.md](GLOSSARY.md) for the terms and [ADR 0001](docs/adr/0001-agent-drives-tour-live.md) for why Claude drives the Tour live.

Tested with Neovim 0.12. Needs Treesitter parsers for the languages you tour, and [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) (part of LazyVim) for Stops with a git Base.

## Install

lazy.nvim, with suggested keys:

```lua
{
  "JanKaul/guide.nvim",
  lazy = false, -- Claude calls require("guide") over RPC at any time
  keys = {
    { "<leader>an", "<cmd>GuideNext<cr>", desc = "Guide: next Stop" },
    { "<leader>aj", "<cmd>GuideStop<cr>", desc = "Guide: jump to current Stop" },
    { "<leader>aq", "<cmd>GuideEnd<cr>", desc = "Guide: end" },
  },
}
```

Claude Code: link the skill and allow the CLI.

```bash
ln -s ~/.local/share/nvim/lazy/guide.nvim/skills/guide ~/.claude/skills/guide
```

```json
"permissions": { "allow": ["Bash(nvim-guide:*)"] }
```

The plugin puts its `bin/` on Neovim's `PATH`, so Claude finds `nvim-guide` when it runs in a Neovim terminal.

## Use

1. Start Claude inside Neovim (e.g. with claudecode.nvim), so `$NVIM` is set.
2. Run `/guide <what to show>`, for example:
   - `/guide where is retry handled` — one Stop, shown at once
   - `/guide how a request flows from the handler to storage` — Claude lists the Itinerary first, which you can adjust
   - `/guide what the last commit changed` — Stops open side by side with the previous revision
   - `/guide the plan` — in plan mode, before you approve: Sketches of new code, and changes you ask for are applied to the Plan at the end
3. Reply `next`, `back`, a Stop number, a question or `show me X`.

| Command | |
| --- | --- |
| `:GuideNext` / `:GuideBack` | type `next` / `back` into the agent's prompt |
| `:GuideSend {text}` | type any text into the agent's prompt and submit it (`require("guide").send(text)` from Lua) |
| `:GuideStop` | jump to the current Stop, e.g. after exploring elsewhere (`<C-o>` goes back) |
| `:GuideEnd` | clear highlights, close the Sketch and the diff |

The agent's terminal is found by itself: each `nvim-guide` call passes its process ID, and the plugin picks the Neovim terminal whose job started it. So the keys work with any agent running in a Neovim terminal, once it has called `nvim-guide`.

Highlight groups: `GuideStop` (range), `GuideBar` (sign), `GuideLabel` (Label and Sketch title).

Running Claude outside Neovim: start Neovim with `--listen <socket>`, put `bin/` on your `PATH` and set `GUIDE_NVIM=<socket>`.

## Test

```bash
nvim --headless -u NONE -l tests/run.lua
```
