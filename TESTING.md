## Golden image tests

`tests/` draws the viewer offscreen, with SDL's software renderer, in
various setups (window sizes, densities, scrolling, zooming, resizing, other
scripts and emoji, editing, saving), and the `UI.Text_Areas` component by
itself (`textarea-*`: typing, caret movement, clicks and drags, selection,
the clipboard, undo, input methods, blinking, scrolling), and compares each
picture with `tests/golden/<name>.png`. Tests also check text, as edited
or saved, with `Goldens.Check_Text`, and documents and layouts without
drawing (`document-*`, `layout-*`), and the items of a canvas (`items-*`:
added, typed in, dragged, sized, minimised, closed, listed and kept in the
database, by clicks and drags at points of the window), and sources
(`sources-*`: a link's picture taken from a page written to
`/tmp/bonxie-source-page`, so the tests need WebKit but not a network
beyond one name that does not exist; `sources-words` reads the text of a
page's picture with Vision, in the background, and checks the words are
selected and kept in the database, without a golden, as WebKit's text
differs between releases), and highlighting a picture (the tools in the status line, erasing, marks kept, put away
by the cursor or a click outside), and selecting words over a picture
(`pictures-*`, with made-up words: dragging, double and triple clicks,
copying, zooming and scrolling, and reading a page of columns in order).
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