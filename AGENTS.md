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

The tokens are `UI.Themes.Light`; the app's own are in `Viewer.Style`.

Panels: light #C6CFCB (the ground), mid #B8C0BB (the home screen's
sidebar, behind the pages), card tint #D6DCD9 (status lines, a card's
foot). Button grey #A9B1AD. Slate bars #4F5B56 (the top bar, the windows'
title bars, the tray).

Green #27722D (the main, positive action, as New project), red #C62828
(what cannot be undone, as deleting), active orange #E5A15F (what is
chosen or typed in: a tab, a tool, the ring round a window), highlight
yellow #FFD428, source-tag blue #2563D4 (the first of the sources'
colours, `Style.Source_Inks`).

Border #8A928E, shadow #AEB6B2.

Shape: no border radius anywhere; 1px borders; shadows only solid and
offset (3px 3px 0), never blurred or a gradient (`UI.Boxes`: the shadow is
inside a box's own bounds, so pad what is in it clear of the right and
foot). Buttons are flat: a face and an outline, no bevel.

Type: Newsreader (serif) for documents and sources' text and display
titles, Instrument Sans for the interface (`UI.Line_Texts`). Both are in
`share/bonxie/fonts` and registered at start-up.

Each source has a colour, by its place among the project's sources
(`Canvas_Items.Source_Ink`); it shows in the Write sidebar, in the square
before the source's title on the canvas and in its windows, and in the
links to it.
