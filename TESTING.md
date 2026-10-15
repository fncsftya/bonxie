## Golden image tests

`tests/` draws the viewer offscreen, with SDL's software renderer, in
various setups (window sizes, densities, scrolling, zooming, resizing, other
scripts and emoji, editing, saving), and compares each picture with
`tests/golden/<name>.png`. Tests also check text, as edited or saved, with
`Goldens.Check_Text`, and the items of a canvas (`items-*`:
added, typed in, dragged, sized, minimised, closed, listed and kept in the
database, by clicks and drags at points of the window), and sources
(`sources-*`: a link's picture taken from a page written to
`/tmp/bonxie-source-page`, so the tests need WebKit but not a network
beyond one name that does not exist; `sources-words` reads the text of a
page's picture with Vision, in the background, and checks the words are
selected and kept in the database, without a golden, as WebKit's text
differs between releases), the writing view (`write-*`: documents on pages,
dragged into another order and kept, typed on a page and seen on the
canvas, a source opened and pinned, its highlights shared with the canvas's
window, which like `sources-pages` needs WebKit), highlighting a picture
(the tools in the status line, erasing, marks kept, put away by the cursor
or a click outside), PDFs and e-books (`sources-documents`, `write-source-documents`: a link to a
PDF, written to `/tmp`, is fetched with curl, not shown with WebKit, and its
pages are drawn with MuPDF, one at a time, on the canvas and in the writing
view; the tests need MuPDF, `brew install mupdf`, which `ebook` links;
`sources-files`: files chosen as the file dialog would, PDFs and text, kept; the
dialog itself is not shown),
the order Vision's words of a page of columns are
read in (`layout-*`), and working it from the keyboard (`home-keys`: Tab and
Return on the home screen and round the dialog that asks before deleting, with
the ring drawn; `items-list-keys`: the list of items by arrows, Space, Delete,
Tab and Return). `sources-words` also checks that the task that finds the words
posted to wake the loop.

The widgets themselves (text areas, fields, the sheet, words selected over
a picture) are tested in pomarine, which this uses for its UI.

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