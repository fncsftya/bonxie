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

## Writing a view-model

A screen that is a form or a list (the settings, the home screen and its deleting dialog, the outline and the grammar
rules: `Settings_VM`, `Home_VM`, `Confirm_VM`, `Outline_VM`, `Grammar_VM`) has a view-model in `src/view_models/`: what the screen means, and nothing of how it looks. The canvas, the
writing editor and gestures (drag, pan, resize) stay with the code that handles events: do not force them in.

DO give the view-model the parts of `Pomarine.View_Models` (`pomarine/vm`): a `Version` that goes up whenever
  anything it shows changes, `Property`/`Text_Property` for what is chosen or typed, and a command
  enumeration with `Can_Execute (What, Index)` and `Execute (What, Index)` (`Command_Models`). `Index` carries
  which of many: a row, a choice; the tree's validator asks with the widget's own Index, so a row's button is
  on while another's is off.
DO keep persistence in the view-model, through a `Store` interface (a file one for the program, a
  failing one for a test), and what it asks of the world (a speech model, a task's download) through a
  source interface it is given, polled from the view's update. Applying a result to the world (the window's
  VSync, the theme the windows are drawn in) is the view's, in reaction to a changed `Version`.
DO NOT `with` `Pomarine.Widgets` or `SDL3` in `src/view_models/`: the test `view-models-no-widgets` fails if
  a file there names either.
DO give what the person types, and what only the program knows, to the view-model through its setters
  and sources, and let the view show it (`Home_VM.Set_Draft`, `Outline_VM.Set_Title`); a rule that needs
  the database goes through a `Library` interface the view-model is given (`Stored` children for the program,
  fakes in `tests/src` for the tests).
DO bind the widgets with `Pomarine.Widgets.Bindings` (`For_Commands`: `Bind`, `Trigger`, `Perform`,
  `Changed`, `Judge`; `Sync_Root`; `Text_Link`). A widget that only says a command (a field's Return)
  is `Trigger`ed, not `Bind`ed, or it is turned off with the command. A window with more than one set of
  commands gives each its own `Tag_Base` and one validator that asks each (see `Viewer.Menus.Validate`).
DO test in three tiers (TESTING.md): the view-model alone, with fakes for the store and the source; the view
  offscreen, through `Pomarine.Testing` by what the widgets are called; goldens for drawing only.

## Testing

See TESTING.md