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

The tokens are `UI.Themes.Light` and `UI.Themes.Dark`; the app's own are
in `Viewer.Style`. Each theme is a record of colours (the dark one is the
spec's dark palette). A widget never keeps a `Themes.Color`: it keeps a
`Themes.Slot` (a role, as `Page` or `Rail`), resolved with the theme it is
drawn in, so a window changes theme without being built again. `Colors`
in `Viewer.Style` is the theme in use. The light theme's derived tones
are computed from its base colours exactly as they were before the dark
theme, and the goldens hold the light theme pixel for pixel, so a change
to a light colour changes the goldens.

Dark is chosen in Settings (Light, Dark, or System, which follows the
system's appearance and updates when it changes).

Panels: light #C6CFCB (the ground), mid #B8C0BB (the home screen's
sidebar, behind the pages), card tint #D6DCD9 (status lines, a card's
foot). Button grey #A9B1AD. Slate bars #4F5B56 (the top bar, the windows'
title bars, the tray).

Green #27722D (the main action, as New project, Add source, OK), grey
#A9B1AD (every other button), red #C62828 (what cannot be undone, as
deleting), active orange #E5A15F (what is chosen or switched on: a tab, a
tool, a toggle, the ring round a window; and the caret), highlight yellow
#FFD428, blue #2563D4 (the ring of the keyboard's focus, as round a field
being typed in; and the first of the sources' colours,
`Style.Source_Inks`). Ink #111111.

Border #8A928E, shadow #AEB6B2.

Shape: no border radius anywhere; 1px borders; shadows only solid and
offset (3px 3px 0), never blurred or a gradient (`UI.Boxes`: the shadow is
inside a box's own bounds, so pad what is in it clear of the right and
foot).

Controls stand up (`UI.Boxes.Draw_Raised`): a face, outlined, bevelled
(a light 1px edge at its top and left, a dark one at its foot and right:
`Themes.Highlight`, `Themes.Shade`; flat colours) and a small solid shadow
(2px 2px, `Themes.Drop`), as `inset 1px 1px 0 light, inset -1px -1px 0
dark, 2px 2px 0 shadow`. Pressed, the insets swap, the shadow goes and the
face moves 1px down and right; a toggle that is on stays pressed, in
orange. Turned off, a control is flat and dull (`Themes.Dull`). Grooves and
the boxes to tick are sunk (the bevel the other way). Fields are white,
outlined; with the focus, outlined in blue, 2px; invalid, in red.

The widgets, in `ui/src`, are drawn on one board by the `sheet-*` tests
(`tests/golden/sheet-board.png`), as the design's Widgets sheet shows them.

Type: Georgia (serif) for documents, sources' text and the display titles
of a screen, and the system's user interface font for the interface
(`UI.Line_Texts`). Both ship with macOS, so no fonts are bundled.

Each source has a colour, by its place among the project's sources
(`Canvas_Items.Source_Ink`); it shows in the Write sidebar, in the square
before the source's title on the canvas and in its windows, and in the
links to it.
