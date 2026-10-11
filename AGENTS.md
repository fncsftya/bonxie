We are using Ada and Alire.

## General guidelines

DO use assertions to improve robustness.
PREFER static/fixed memory or arena allocation where relevant/possible.

## Layers

From the bottom up; each crate depends only on those before it.

- `texts`: documents, held apart from how they are shown
  (`Texts.Documents`): paragraphs with stable ids and app-defined kinds,
  edits as one splice, a log of changes for views to catch up with, and
  the undo history (with `Begin_Step`/`End_Step` for app commands). No
  graphics.
- `sdl3`, `coretext`, `yoga`: bindings.
- `typeset`: a layout of a document for one view (`Typeset.Layouts`):
  lines, made lazily (a long paragraph only as far as shown), heights as
  running sums (`Typeset.Sums`); drawing it (`Typeset.Views`).
- `ui` (crate `bonxie_ui`): components. `UI.Text_Areas` is a view of a
  document the app owns; several may show one document.
- bonxie (`src/`): the app. `Scripts` owns the document, its file and
  saved state.

`bench/` measures layout (`bin/bench`) and text areas
(`bin/text_area_bench`, on documents of several sizes).

## Golden-image tests

`tests/` draws the viewer offscreen, with SDL's software renderer, in
various setups (window sizes, densities, scrolling, zooming, resizing, other
scripts and emoji, editing, saving), and the `UI.Text_Areas` component by
itself (`textarea-*`: typing, caret movement, clicks and drags, selection,
the clipboard, undo, input methods, blinking, scrolling), and compares each
picture with `tests/golden/<name>.png`. Tests also check text, as edited
or saved, with `Goldens.Check_Text`, and documents and layouts without
drawing (`document-*`, `layout-*`).
The software renderer gives the same pixels every run, so no pixel may
differ.

```sh
cd tests
alr build
bin/golden                     # every test; exits non-zero on a failure
bin/golden zoom                # the tests whose names contain "zoom"
UPDATE_GOLDEN=1 bin/golden     # rewrite the goldens from what is drawn now
```

A mismatch writes `tests/out/<name>-actual.png` and `<name>-diff.png`
(differing pixels in red over a dimmed golden). Check that a change is
intended before regenerating the goldens.

The software renderer samples geometry without smoothing, so these tests
do not see how the GPU smooths scaled glyphs. CoreText may also rasterize
slightly differently on another macOS release; if so, regenerate the
goldens there or pass a tolerance to `Goldens.Check`.

## UI Theme

### Light mode

Background: #CDD5D1
Foreground: #090A0B
Accent: #FF7F11