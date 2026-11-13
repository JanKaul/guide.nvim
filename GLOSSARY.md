# tour.nvim

Guided walkthroughs of code inside Neovim, narrated by an agent, so the developer understands code or a change well enough to make the next change in that area themselves.

## Language

**Plan Walkthrough**:
A Tour of an implementation Plan, taken before the Plan is approved, against the code as it is today.
_Avoid_: plan review, plan tour

**Plan**:
An agent's proposed set of changes that has not been implemented yet.
_Avoid_: spec, proposal

**Tour**:
An ordered visit through code, made of Stops, that the agent narrates one Stop at a time; the developer asks for one by describing what to show. A Tour may have a single Stop.
_Avoid_: walkthrough (as a noun for the object), guide, session

**Itinerary**:
The ordered list of Stops the agent proposes before a Tour starts, which the developer may reorder, trim or extend.
_Avoid_: agenda, outline, table of contents

**Stop**:
One place in the code the Tour visits, with its Anchor, Label and narration.
_Avoid_: step, location, waypoint

**Anchor**:
The existing code a Stop points at; for code a Plan would add, the existing code it plugs into.
_Avoid_: line number, position

**Label**:
The short title of a Stop shown in the editor; the full explanation lives in the narration.
_Avoid_: note, comment, annotation

**Narration**:
The agent's explanation of a Stop: what changes, why it is built that way, and what depends on it.
_Avoid_: description, note

**Sketch**:
Proposed code for something a Plan would add, shown beside the Anchor, illustrating intent rather than final implementation.
_Avoid_: preview, draft, stub

**Base**:
The git revision a Stop's file is compared against, shown side by side with the file as it is now.
_Avoid_: diff target, revision, ref

**Amendment**:
A change to the Plan that the developer asks for during a Plan Walkthrough, collected and applied to the Plan after the Tour ends.
_Avoid_: edit, revision, fix

**Detour**:
A Stop outside the Itinerary that the developer asks for, after which the Tour resumes where it left off.
_Avoid_: side trip, tangent
