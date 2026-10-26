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

## Writing a view-model

Keep screen state, command rules and persistence in `src/view_models/`, without `Pomarine.Widgets` or `SDL3`.
Expose modular versions, bump only for changes, and give commands `Can_Execute` contracts. Inject interfaces for
storage, background engines and effects that need the view. Keep widget geometry, focus, painting and event
translation in the view; feed gesture outcomes into the model rather than copying its state into widgets.
Canvas and editor behavior follows the same boundary; continuous widget gestures remain in the view.
Use growing storage for user content. Preserve item identity across slot reuse when a row can outlive its item.
Test rules and contracts without widgets, bindings through `Pomarine.Testing` by semantic name, and drawing
through goldens. See TESTING.md for commands and the existing tiers.
A screen of pomarine widgets that a view owns (components as functions, layouts as expressions, bindings declared with
the controls) is `Pomarine.UI`: see `pomarine/UI.md`; the todo example is its model.
