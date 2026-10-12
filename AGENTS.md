We are using Ada and Alire.

## General guidelines

DO use assertions to improve robustness.
PREFER static/fixed memory or arena allocation.
AVOID dynamic allocation unless strictly required.
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

## Layers

See DESIGN.md

## Testing

See TESTING.md

## UI Theme

### Light mode

Background: #CDD5D1
Foreground: #090A0B
Accent: #FF7F11

Beyond those: Primary #2E7D32 (the main, positive action, as New Project);
Danger #C62828 (what cannot be undone, as deleting). Buttons
are not flat: a bevel (light on the top and left, shade on the bottom and
right, reversed when pressed) and no outline.
