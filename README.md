# tour.nvim

Plan Walkthroughs in Neovim, driven by [Claude Code](https://claude.com/claude-code). Before you approve a Plan, Claude takes you through it Stop by Stop: the code opens and is highlighted in your editor, a Sketch shows code the Plan would add, and the Narration appears in the chat. See [GLOSSARY.md](GLOSSARY.md) for the terms and [ADR 0001](docs/adr/0001-agent-drives-tour-live.md) for why Claude drives the Tour live.

Tested with Neovim 0.12. Needs Treesitter parsers for the languages you tour.

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
ln -s ~/.local/share/nvim/lazy/tour.nvim/skills/plan-walkthrough ~/.claude/skills/plan-walkthrough
```

```json
"permissions": { "allow": ["Bash(nvim-tour:*)"] }
```

The plugin puts its `bin/` on Neovim's `PATH`, so Claude finds `nvim-tour` when it runs in a Neovim terminal.

## Use

1. Start Claude inside Neovim (e.g. with claudecode.nvim), so `$NVIM` is set.
2. Let Claude write a Plan in plan mode.
3. Run `/plan-walkthrough`. Adjust the Itinerary, then reply `next`, `back`, a Stop number, a question, `show me X`, or a change to the Plan.

| Command | |
| --- | --- |
| `:TourStop` | jump to the current Stop, e.g. after exploring elsewhere (`<C-o>` goes back) |
| `:TourEnd` | clear highlights, close the Sketch |

Highlight groups: `TourStop` (range), `TourBar` (sign), `TourLabel` (Label and Sketch title).

Running Claude outside Neovim: start Neovim with `--listen <socket>`, put `bin/` on your `PATH` and set `TOUR_NVIM=<socket>`.

## Test

```bash
nvim --headless -u NONE -l tests/run.lua
```
