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
differs between releases), the outline view (`outline-*`: a project opens to the tab it was last left at, Outline at first; sections added, typed in, moved, removed and kept in the database), the writing view (`write-*`: documents on pages,
dragged into another order and kept, typed on a page and seen on the
canvas, a source opened and pinned, its highlights shared with the canvas's
window, including vertical and diagonal strokes, shared undo/redo, and marks
kept when reopened; like
`sources-pages`, this needs WebKit), highlighting a picture
(the tools in the status line, erasing, marks kept, put away by the cursor
or a click outside), PDFs (`sources-documents`, `write-source-documents`: a link to a
PDF, written to `/tmp`, is fetched with curl, not shown with WebKit, and its
pages are drawn from PDFium's objects as shapes and text (no picture file), one at a time, on the canvas and in the writing
view; the tests need PDFium, `ebook/fetch-pdfium.sh`, which `ebook` links;
`sources-files`: files chosen as the file dialog would, PDFs, EPUBs (a small one is written by the test) and text, kept; the
dialog itself is not shown),
the order Vision's words of a page of columns are
read in (`layout-*`), and working it from the keyboard (`home-keys`: Tab and
Return on the home screen and round the dialog that asks before deleting, with
the ring drawn; `items-list-keys`: the list of items by arrows, Space, Delete,
Tab and Return). `sources-words` also checks that the task that finds the words
posted to wake the loop.

Nothing a person makes has a number it stops at, and the tests say so with
more than there was once room for: `items-full` (250 items, all with their
windows), `outline-many-sections` (90 sections, one with a title of 300 bytes, kept),
`write-many-directories` (140 folders), `items-long-title` (a title of 300 bytes,
kept whole) and `items-many-marks-and-words` (400 highlights and 5,000 words of one
picture, kept). The tree of widgets holds up to 2,097,151 (what a widget's number
keeps of its place), and the memory of those that are made.

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

`outline-section-folders` checks folders dragged into and out of sections,
nested folder drops and cycle rejection, document and folder creation from context
menus in Overview and folders, Escape dismissal,
document outline membership at multiple depths, and persistence after reopening.

`outline-folder-operations` checks folder ordering before and after sibling
documents at multiple levels, deleting whole folder subtrees while retaining
documents, the optional deletion of documents, cancellation, checkbox defaults,
and persistence after reopening.

## Find Sources

`finding-queries` and `finding-evaluations` check how the model's replies are
read (`Source_Finding`): what is wrong with a reply, and what is passed over. No
model is run. `finding-button` checks the Find Sources button of a note on the
canvas and of a page in the writing view: off while the AI is off or the text is
blank, and, with no model chosen, a click is answered by the toast. `finding-review`
fakes what the finder found (`Source_Finder.Offer`, with pictures copied from the
goldens) and checks the toast and its list, adding one source, all of them, none, and
leaving the project. `finding-messages` checks what the toast says when nothing passed.

`finding-banners` and `finding-links` check how the model's reply about what covers a page is
read (the button to press, from a reply with thoughts and braces round it; a page said to be
covered with no button is not covered) and which addresses are of PDFs, and which pages are the
front of one (arXiv's abstract and HTML pages and the PDF at an address with no `.pdf`;
Taylor & Francis's preview pages; the endings and the segments that say PDF, and not what only
looks like one). `finding-documents` offers a PDF as found and checks it is shown in the preview as
pages and added as a document (paged, its file moved, linked from the note), the page after it as a
picture.

`finding-cancel` stops a run half way by the toast's button (held there, with no model:
`Source_Finder.Hold`), and checks the toast, the state and that work can begin again.

The work itself (the model, DuckDuckGo, WebKit and Vision, together) needs a model and a
network, so it is not in `bin/golden`: run `tests/bin/finder_run <model folder>` (see
`tests/finder_run.gpr`), which prints how it goes and what it finds, and
`tests/bin/finder_run --cancel <writing|searching|reading|judging> <model folder>`,
which stops it at that stage and checks it stops in good time, keeps nothing, leaves no
files (pictures, PDFs, looks and screens) and can be begun again; `bin/banner_probe <model folder>
<address>` tries the step that clears what covers a page, with the model, on one page (it says
what the model named and whether pressing it worked), and `bin/page_probe <address> [look]` takes a
page as finding sources does and says how tall it is and how many words are read from it. `websearch/tests` checks the search, its limits and its
cache alone; `webshot/tests` (`alr exec -- gprbuild -P webshot_test.gpr`, then
`bin/webshot_test`) checks, on pages it writes to `/tmp`, that a very long page is all in its
picture, with the first screens of it beside, and that cookie banners are pressed, by the page's own
way (in the page, a shadow root and a frame; the accepting button first; a second notice; and not a
button that is no cookie banner's) or as told (the top looked at first; a button found by words a
letter wrong or by part of them; none pressed that costs something; a notice that comes late is looked
at again; the PDF a page says it is of, by its meta tag or by its one PDF button; a file fetched as a
browser would download it, and a page that is no file failing).

## Harper bindings

The `write-grammar` viewer test covers the default switch state, concurrent
document checks, the idle timer, stale results, switching off, document
reordering, excluding notes, and documents longer than one request buffer.
Its golden images check Harper's highlight colors and the switch states.

The standalone `harper/tests` crate checks the vendored Harper library through
the C ABI and Ada tasks, without starting Bonxie or SDL:

```sh
cd harper/tests
alr build
alr exec -- bin/check_harper
```

See `harper/README.md` for the API, bounds, and build requirements.


## Rich text persistence

`items-stored` also checks all four styles through item content in the `<version>` markup,
project descriptions, section notes, and saved script files. Plain summaries
remain plain text. Editor geometry, rendering, formatting, and undo are covered
by pomarine's `document-rich-text` and `textarea-rich-text` tests.

`outline-colours` checks the enlarged swatch and its hover border, the continuous RGB picker and saturation slider,
Cancel without changes, OK, exact black, white and arbitrary RGB values, and the chosen colour after reopening the project.
