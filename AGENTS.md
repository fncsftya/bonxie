We are using Ada and Alire.

## General guidelines

DO use assertions to improve robustness.
PREFER static/fixed memory or arena allocation where relevant/possible.

## Golden-image tests

`tests/` draws the viewer offscreen, with SDL's software renderer, in
various setups (window sizes, densities, scrolling, zooming, resizing, other
scripts and emoji, editing, saving), and the `UI.Text_Areas` component by
itself (`textarea-*`: typing, caret movement, clicks and drags, selection,
the clipboard, undo, input methods, blinking, scrolling), and compares each
picture with `tests/golden/<name>.png`. Tests also check text, as edited
or saved, with `Goldens.Check_Text`.
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