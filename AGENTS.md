We are using Ada and Alire.

## General guidelines

DO use assertions to improve robustness.
PREFER static/fixed memory or arena allocation.
AVOID dynamic allocation unless strictly required.
DO NOT cap what a person makes or types (items, sections, links, folders, titles, notes, paths):
  hold it in growing storage (Growing, Slot_Tables, Long_Texts). A fixed capacity is for what the
  program itself bounds (buffers, protocol and token limits, what a widget library holds).
PREFER design by contract (DbC), e.g.
  - pre and post conditions
  - static and dynamic predicates
  - type invariants
DO use DbC to inform test design.
PREFER features from the Ada 2022 standard, e.g.
  - Advanced array aggregates (Square brackets, Iterated Component Association)
  - Container aggregates
  - Delta aggregates
  - Target name symbol (`@`)
PREFER to refactor existing code if it can be improved.
KEEP lines to at most 120 columns (`-gnatyM120` in each project).

## Testing

See TESTING.md