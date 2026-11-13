# tour.nvim

Guided Tours of code in Neovim, driven by [Claude Code](https://claude.com/claude-code). Describe what you want to see, and Claude takes you through it Stop by Stop: the code opens and is highlighted in your editor, optionally side by side with an earlier git revision, and the Narration appears in the chat. A Tour of a Plan (a Plan Walkthrough) also shows Sketches of code the Plan would add, before you approve it. See [GLOSSARY.md](GLOSSARY.md) for the terms and [ADR 0001](docs/adr/0001-agent-drives-tour-live.md) for why Claude drives the Tour live.

Tested with Neovim 0.12. Needs Treesitter parsers for the languages you tour, and [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) (part of LazyVim) for Stops with a git Base.

## Install

lazy.nvim, with suggested keys (the `next` / `back` keys use [claudecode.nvim](https://github.com/coder/claudecode.nvim) to type into Claude's prompt):

```lua
{
  "JanKaul/tour.nvim",
  lazy = false, -- Claude calls require("tour") over RPC at any time
  keys = {
    { "<leader>an", function() require("claudecode.terminal").send_to_terminal("next") end, desc = "Tour: next Stop" },
    { "<leader>ap", function() require("claudecode.terminal").send_to_terminal("back") end, desc = "Tour: previous Stop" },
    { "<leader>aj", "<cmd>TourStop<cr>", desc = "Tour: jump to current Stop" },
    { "<leader>aq", "<cmd>TourEnd<cr>", desc = "Tour: end" },
  },
}
```

Claude Code: link the skill and allow the CLI.

```bash
ln -s ~/.local/share/nvim/lazy/tour.nvim/skills/tour ~/.claude/skills/tour
```

```json
"permissions": { "allow": ["Bash(nvim-tour:*)"] }
```

The plugin puts its `bin/` on Neovim's `PATH`, so Claude finds `nvim-tour` when it runs in a Neovim terminal.

## Use

1. Start Claude inside Neovim (e.g. with claudecode.nvim), so `$NVIM` is set.
2. Run `/tour <what to show>`, for example:
   - `/tour where is retry handled` — one Stop, shown at once
   - `/tour how a request flows from the handler to storage` — Claude lists the Itinerary first, which you can adjust
   - `/tour what the last commit changed` — Stops open side by side with the previous revision
   - `/tour the plan` — in plan mode, before you approve: Sketches of new code, and changes you ask for are applied to the Plan at the end
3. Reply `next`, `back`, a Stop number, a question or `show me X`.

| Command | |
| --- | --- |
| `:TourStop` | jump to the current Stop, e.g. after exploring elsewhere (`<C-o>` goes back) |
| `:TourEnd` | clear highlights, close the Sketch and the diff |

Highlight groups: `TourStop` (range), `TourBar` (sign), `TourLabel` (Label and Sketch title).

Running Claude outside Neovim: start Neovim with `--listen <socket>`, put `bin/` on your `PATH` and set `TOUR_NVIM=<socket>`.

## Test

```bash
nvim --headless -u NONE -l tests/run.lua
```
