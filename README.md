# tour.nvim

Plan Walkthroughs in Neovim, driven by Claude Code. Before you approve a Plan, Claude takes you through it Stop by Stop: the code opens and is highlighted in your editor, a Sketch shows code the Plan would add, and the Narration appears in the chat. See [GLOSSARY.md](GLOSSARY.md) for the terms and [ADR 0001](docs/adr/0001-agent-drives-tour-live.md) for why Claude drives the Tour live.

## Install

lazy.nvim:

```lua
{ dir = "~/workspace/tour.nvim", name = "tour.nvim", lazy = false }
```

Claude Code:

```bash
ln -s ~/workspace/tour.nvim/skills/plan-walkthrough ~/.claude/skills/plan-walkthrough
```

and in `~/.claude/settings.json`:

```json
"permissions": { "allow": ["Bash(/home/work/workspace/tour.nvim/bin/tour:*)"] }
```

## Use

1. Start Claude inside Neovim (e.g. claudecode.nvim), so `$NVIM` is set. Otherwise set `TOUR_NVIM` to the socket of a Neovim started with `--listen`.
2. Let Claude write a Plan in plan mode.
3. Run `/plan-walkthrough`. Adjust the Itinerary, then reply `next`, `back`, a Stop number, a question, `show me X`, or a change to the Plan.

| Command | Key | |
| --- | --- | --- |
| `:TourStop` | `<leader>aj` | jump to the current Stop |
| `:TourEnd` | `<leader>aq` | clear highlights, close the Sketch |

For `next` and `back` without leaving the code, map keys to claudecode.nvim's sender:

```lua
{ "<leader>an", function() require("claudecode.terminal").send_to_terminal("next") end, desc = "Tour: next Stop" },
{ "<leader>ap", function() require("claudecode.terminal").send_to_terminal("back") end, desc = "Tour: previous Stop" },
```

Highlight groups: `TourStop` (range), `TourBar` (sign), `TourLabel` (Label and Sketch title).

## Test

```bash
nvim --headless -u NONE -l tests/run.lua
```
