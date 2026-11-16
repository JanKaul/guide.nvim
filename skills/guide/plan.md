# Plan Walkthrough

A Tour of a Plan, taken before the developer approves it, against the code as it is today. These rules replace steps 3, 5 and 7 of the Tour.

**The Plan** is the plan file named in the description, otherwise this session's plan file. Read every file it touches.

## 3. Build the Itinerary

- Follow the Plan's step order. Give every Stop a `step` field naming its Plan step (`"3"`); it shows in the Label and the quickfix list.
- One Stop per place the Plan changes. Each Anchor is existing code; for code the Plan adds, anchor on the existing code it plugs into (the caller, the module that declares it, the trait it implements).
- Done when every Plan step has at least one Stop.

## 5. Tour

- **Sketch** whenever the Plan adds code at this Stop: real signatures and types in the target language, bodies as `todo!()` / `TODO`, enough to judge whether the design fits.
- **Narration** parts for a Plan:
  - **Change**: what the Plan changes here.
  - **Reason**: why it is built this way, including the alternative it beats.
  - **Dependents**: what relies on this code, each as a possible Detour.
- A change the developer asks for is an **Amendment**: record it and keep touring. When it invalidates a later Stop, say which one now.

## 7. Finish

Call `finish`. List the Amendments, apply them to the plan file, and present the Plan again. Done when every Amendment is in the plan file or the developer dropped it.
