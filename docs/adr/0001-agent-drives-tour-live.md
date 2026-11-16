# The agent drives the Tour live over the Neovim socket

Claude Code shows each Stop by calling `guide.show` over `$NVIM` (`nvim --server "$NVIM" --remote-expr …`) and waits in the chat for "next", a question or a Detour before it shows the next Stop. We chose this over writing a tour file that Neovim plays back on its own. Doing it live lets the Tour adapt to questions mid-way, lets Claude correct an unresolvable Anchor from the error it gets back, and lets Amendments be collected as they come up. These matter more for a Plan Walkthrough than replayability does.

## Considered Options

- **Artifact-first:** Claude writes a tour file, and Neovim steps through it with keymaps; Claude is only consulted for questions. Rejected because it is fast and replayable but cannot adapt during a Tour, and a Plan Walkthrough happens once, before approval, so replays have little value.
- **Dedicated MCP server with a blocking `show_stop` tool:** Deferred. It is the natural next step if shell calls prove too slow or too noisy for permissions.

## Consequences

- Every Stop is one Bash tool call. In plan mode it goes through the permission check, so it needs an allow rule or the auto-mode classifier.
- The Tour ends with the Claude session; only the quickfix Itinerary remains in Neovim.
- The Narration lives in the chat, not in Neovim.
