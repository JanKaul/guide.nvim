---
name: guide
description: Show code in the developer's Neovim, Stop by Stop, from a description of what to show.
disable-model-invocation: true
argument-hint: "<what to show>"
---

# Guide

Give the developer a **Tour** of what their description asks for, in their Neovim, one **Stop** at a time, so that afterwards they could make the next change in this area themselves. You drive the editor live; the **Narration** lives here in the chat. Terms are defined in guide.nvim's `GLOSSARY.md`.

When the description refers to a Plan ("the plan", a plan file, "what you are about to change"), this is a **Plan Walkthrough**: read [plan.md](plan.md) now and follow it where it overrides steps 3, 5 and 7.

## Driving Neovim

Every editor action is one call, payload as JSON on stdin:

```bash
nvim-guide <command> <<'JSON'
{ ... }
JSON
```

| Command | Payload |
| --- | --- |
| `status` | none |
| `itinerary` | `{"stops": [Stop, ...]}` |
| `show` | `{"stop": n, "sketch"?: "code", "sketch_ft"?: "rust"}` or `{"detour": Stop}` |
| `finish` | none |

A **Stop** is an Anchor plus a `label` (≤ 6 words):

- `file`: absolute path.
- `symbol`: a definition name, nested with `::` in every language (`Scheduler::tick`, `M.compact`). For a Rust impl: `Type::method`, or `Trait for Type::method` when two impls share the method.
- `pattern`: a Vim regex for one line; with `symbol` it is searched inside that symbol. `nth` picks among several matches; `end_pattern` extends the range to its first match below.
- `base` (optional): a git revision (`"HEAD~1"`, `"main"`). The file opens side by side with that revision, so the Stop shows a change. A Stop with a `base` takes no Sketch.

Output is one JSON line. On `"ok":false` the `error` names the candidates: fix the Stop and call again; the developer never needs to see Anchor errors.

## Steps

1. **Connect.** Run `status`; its `cwd` is Neovim's working directory. When `nvim-guide` is not found, Claude is not running inside a Neovim that has guide.nvim loaded: say so and stop. On any other failure, relay the error and stop.
2. **Read the code** the description is about, until you can name every place it needs.
3. **Build the Itinerary**: one Stop per place, in the order that explains it best. For a flow, that is the order the code runs; for a change, the order a reader needs it. Give a Stop a `base` when it is about what changed (a commit, a branch, your own recent edits). Done when every part of the description has a Stop.
4. **Load it.** Call `itinerary`; repeat until `ok`.
   - **One Stop:** go straight to step 5.
   - **Several:** list them in chat (number, label, `file:line`) and wait for the developer to reorder, drop or add. Reload after changes.
5. **Tour.** For each Stop, call `show`, then write its Narration, then wait for the developer. Narration, 5–10 lines, always these three parts:
   - **What**: what this code does, or what changed here.
   - **Why**: why it is built this way, including the alternative it beats.
   - **Dependents**: what relies on this code (callers, implementations, tests), each as a possible Detour.
6. **Respond** to each reply, then wait again:
   - "next" / "back" / a number: `show` that Stop.
   - A question: answer it; show another place with a **Detour** when that helps, then re-`show` the current Stop.
   - "show me X": Detour to X, then return.
7. **Finish** after the last Stop or when the developer says stop: call `finish`. A `stop` may come from `:GuideEnd`, which has already cleared the editor; `finish` again is harmless, so call it and end without further Narration.
