---
name: plan-walkthrough
description: Walk the developer through a Plan in Neovim, Stop by Stop, before they approve it.
disable-model-invocation: true
argument-hint: "[path to plan file]"
---

# Plan Walkthrough

Take the developer through the Plan in their Neovim, one **Stop** at a time, so that afterwards they could make the next change in this area themselves. You drive the editor live; the **Narration** lives here in the chat. Terms: `~/workspace/tour.nvim/GLOSSARY.md`.

## Driving Neovim

Every editor action is one call, payload as JSON on stdin:

```bash
/home/work/workspace/tour.nvim/bin/tour <command> <<'JSON'
{ ... }
JSON
```

| Command | Payload |
| --- | --- |
| `status` | none |
| `itinerary` | `{"stops": [Stop, ...]}` |
| `show` | `{"stop": n, "sketch"?: "code", "sketch_ft"?: "rust"}` or `{"detour": Stop}` |
| `finish` | none |

A **Stop** is an Anchor plus `label` (≤ 6 words) and `step` (the Plan step it belongs to, e.g. `"3"`):

- `file`: absolute path.
- `symbol`: a definition name, nested with `::` in every language (`Scheduler::tick`, `M.compact`). For a Rust impl: `Type::method`, or `Trait for Type::method` when two impls share the method.
- `pattern`: a Vim regex for one line; with `symbol` it is searched inside that symbol. `nth` picks among several matches; `end_pattern` extends the range to its first match below.

Output is one JSON line. On `"ok":false` the `error` names the candidates: fix the Anchor and call again; the developer never needs to see Anchor errors.

## Steps

1. **Connect.** Run `status`. On failure, relay the error and stop. Its `cwd` is Neovim's working directory.
2. **Read the Plan.** The argument if given, otherwise this session's plan file. Read every file the Plan touches, so each Narration rests on the code as it is today.
3. **Build the Itinerary** in the Plan's step order. One Stop per place the Plan changes. Each Anchor is existing code; for code the Plan adds, anchor on the existing code it plugs into (the caller, the module that declares it, the trait it implements). Done when every Plan step has at least one Stop.
4. **Load it.** Call `itinerary`; repeat until `ok`. Then list the Stops in chat (number, step, label, `file:line`) and wait for the developer to reorder, drop or add. Reload after changes.
5. **Tour.** For each Stop, call `show`, then write its Narration, then wait for the developer.
   - **Sketch** whenever the Plan adds code at this Stop: real signatures and types in the target language, bodies as `todo!()` / `TODO`, enough to judge whether the design fits.
   - **Narration**, 5–10 lines, always these three parts:
     - **Change**: what the Plan changes here.
     - **Reason**: why it is built this way, including the alternative it beats.
     - **Dependents**: what relies on this code (callers, implementations, tests), each as a possible Detour.
6. **Respond** to each reply, then wait again:
   - "next" / "back" / a number: `show` that Stop.
   - A question: answer it; show another place with a **Detour** when that helps, then re-`show` the current Stop.
   - "show me X": Detour to X, then return.
   - A change to the Plan: record it as an **Amendment** and keep touring. When it invalidates a later Stop, say which one now.
7. **Finish** after the last Stop or when the developer says stop: call `finish`. List the Amendments, apply them to the plan file, and present the Plan again. Done when every Amendment is in the plan file or the developer dropped it.
