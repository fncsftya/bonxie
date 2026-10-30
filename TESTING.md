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
a project's grammar rules (`write-grammar-rules`: ignoring and correcting texts, matched
by kind and whole word, within the room of a result; `write-grammar-rule-cards`: the cards' buttons
make, remove and list-first rules, kept per project), the order Vision's words of a page of columns are
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

## View-models

A screen's rules are tested without drawing it. In three tiers, the cheapest first:

- **The view-model alone** (`settings-vm-*`): `Settings_VM` with a store that writes down what it was told,
  or fails, and a speech model that is as the test says (`Settings_VM_Fakes`). What each command can do and
  when (`Can_Execute`), what is kept for each choice and that a save that fails keeps the choice and does not
  raise, the file that is kept (read back with `Preferences`), what is said of the download in each of
  its states, and how sizes are said. No window, display or event; it runs in a moment.
- **The view, offscreen, through `Pomarine.Testing`** (`settings-by-name`): a `View.Session` driven by
  what the widgets are called ("Dark", "Parakeet", "VSync", "Projects"), not where they are, and read as
  an assistive technology is told of them (`radio button 'Dark' ON`, `button 'Download'`), with the
  view-model's state asked as well. This is where it is checked that the right widget is tied to the right
  command, that a command's widgets are turned on and off as it says, and that what the view-model changed
  shows.
- **Goldens, for drawing only** (`home-settings*`): what the form looks like.

The same three tiers for the other screens: `home-vm-*`, `confirm-vm-*`, `outline-vm-*`, `grammar-vm-*`, `nav-vm-*`, `canvas-vm-*` and `item-list-vm-*` are the
view-models alone (each with fakes for what it is given and, for the database, the real store in memory:
`*-stored`); `home-by-name`, `outline-by-name`, `settings-by-name`, `nav-by-name`, `item-list-by-name` and
`write-grammar-entry-by-name` drive the
session through `Pomarine.Testing` (`tests/src/view_driver.ads` lets it take a `View.Session`'s events and
time); `nav-by-name` also checks toolbar renaming by double press, selected text replacement, Return, blur
and blank-name rejection. These tests found, among others, that the form that makes a grammar rule closed the
list when pressed. The grammar entry uses `Grammar_UI` for its prompt, correction, visibility and
Accept/Cancel commands. Its semantic test checks invalid corrections disable acceptance, Return submits
valid edits, cancellation and reopening; model tests check completion effects run after the rule is saved
and the entry closes, and can be detached. Grammar card actions bind through the same model: `grammar-vm-cards`
checks current diagnostics, suggestion bounds, editable documents, project requirements and command contracts;
the semantic test opens and expands cards, applies a fix, removes a rule, ignores text and closes the popup.

Background cards bind style selection and new-picture requests through `Settings_VM`. `settings-vm-pictures`
checks the injected seed source, style bounds, command contracts, persistence failures and unchanged versions;
`settings-by-name` also checks clicking a picture, reseeding a different style and reuse after reopening settings.

`item-model-*` checks widget-free item details, documents, marks, capture and dictation states, versions and
flush rules. `canvas-vm-*` checks camera and steering, item lifecycle, source origin, links and persistence;
`nav-vm-*` checks navigation, renaming and modal layers. `item-list-vm-*` checks rows, complete long titles,
show/hide/reveal/remove, stable versions, invalid row contracts and stale identities after slot reuse.
`item-list-by-name` checks the list's bindings, while the existing `items-list*` goldens check its drawing.

`view-models-no-widgets` reads the files of `src/view_models/` and fails if one names `Pomarine.Widgets` or
`SDL3`. The parts of a view-model (`Pomarine.View_Models`) and its bindings are tested in `pomarine`.

`editor-vm-*` tests dictation through `Editor_VM` and a fake editor, without widgets: insertion at the caret
without replacing a selection, paragraph placement, provisional text and faint ranges, typing interruptions,
retained speech, final-text undo/redo, failure cleanup, UTF-8 settled offsets, 70,000-byte transcripts, contracts
and item reuse. `editor-by-name` drives the real canvas and writing editors through `Pomarine.Testing`, feeding
transcripts through the test API because it cannot speak. It checks caret insertion, live/final dictation,
undo and shared document content across views. Writing editors are named "Text of <document title>".
The existing `items-dictating*` tests continue to cover dictation through the viewer.

## Web pages

`bin/page_probe <address> [look]` takes the picture of a page and says how tall it is and how many
words are read from it, `bin/links_probe <address>` prints the PDF address Webshot finds in a page,
and `bin/fetch_probe <address>` fetches the file an address is of (see `tests/webshot_probes.gpr`).
`webshot/tests` (`alr exec -- gprbuild -P webshot_test.gpr`, then
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

## Procedural backgrounds

Window backgrounds compile `src/appearance/shaders/backgrounds.metal` into Metal compute pipelines once per
window, one kernel to each style (`Backgrounds.Styles`): the **watercolour**, **paper** (parchment,
linen or vellum, by the seed), **ink wash** (sumi-e hills and mist), **mist** (domain-warped fog),
**grain** (a quiet gradient under film grain), **marbling** (ebru from swirled, warped stripes),
**risograph** (flat inks in halftone, out of register), **contours** (isolines of a noise field) and
**bauhaus** (simple shapes placed by seeded rules). Each is painted light and dark, the shader being
told which, and repainted when the theme changes. The pictures are cached as SDL textures; each render
uses the actual drawable pixel dimensions, including Retina density, without an internal resolution cap.
Metal owns the size-dependent buffer rather than using the Ada stack. One seed, kept, paints them all,
and resizing keeps it. The hue a picture is made in comes from its style and the seed, by one function
in the native code (`bonxie_background_hue`), so that the program's colours can follow it.

How bold the colours are is the seed's too, whatever the style (`Backgrounds.Moods`, from
`bonxie_background_mood`): **pastel** (the commonest), **vivid** (about twice as saturated, brighter),
**rich** (deep and saturated) and **muted** (half as saturated). A picture is held in a band of
brightness (relative luminance in linear light, by scaling, so the hues and their saturation are kept),
not pulled toward a pale ground, so bold colours are possible: a light one is never under 0.34 and a
dark one never over 0.125, which keeps text above 4.5:1 on any of it. The greys of the interface take
more of the hue for the bold moods and less for the muted (`Tint_Strength`).

Settings > Display > Background is a row of cards, scrolled across, each with a small picture of a window
drawn the way it would be (`Backgrounds.Sample`): **Fixed** (the theme's own colours on a plain
background, as before the shaders) and one for each picture, which takes on the picture's hue in the
theme's neutral greys (`Adaptive_Themes`, more of it for the colourful, less for the nearly grey: see
`Backgrounds.Tint_Strength`), light or dark as Theme says. The button on a picture's card paints another
(a new seed, for all of them) and chooses that card. The seed, an integer, is kept as `watercolour_seed=`
beside the choice (`background=fixed|watercolour|paper|ink_wash|mist|grain|marbling|risograph|contours|bauhaus`;
`adaptive`, the watercolour's old name, still reads as it), so it is the same on every run until the
button is pressed. Only the hue of a grey changes, never its brightness, so contrasts hold for every hue
and strength; what means something (primary, danger, accent, focus, the model's purple) stays.

Offscreen there is no painting, so goldens always draw Fixed. `home-settings` draws the cards (the colours
of a picture's come from its style and seed 0, so they do not change), chooses every one by name, and
checks the row scrolls to the chosen; `home-settings-reseed` checks the buttons, which paint from the
clock and so are not drawn for a golden; `adaptive-palettes` checks, for 48 hues at three strengths in both
themes, that text keeps at least 97% of its contrast on every surface and on the bars, that the hue lands
where the colour wheel says, that the meaningful colours do not move, and that the styles and the choices
are the same list; `preferences-kept` checks every choice and the seed are kept, a garbled seed is none,
and 0 and the largest are kept whole.

Ink is drawn straight on the painting in places (a heading, a count, "New project"), so each picture
is held in that band, and the probe checks every pixel of every style and mood (40 seeds, light and dark,
as well as the clock's), that a mood is a function of the seed alone, and that vivid pictures are at
least 1.4 times as saturated as pastel, rich 1.2 times, and muted less than 0.8 times.

The GPU probe checks, for every style, MSL compilation, identical pixels for a repeated seed,
different pixels for a different seed, a hue that follows the seed, a dark painting that is
opaque and darker than the light, opaque output, portrait resizing,
2049 × 1601 rendering beyond the former cap, invalid dimensions, and identical
pixels after resizing back. Run from the project root on macOS:

```sh
clang -fobjc-arc -O2 -Wall -Wextra -c src/appearance/backgrounds_native.m -o /tmp/backgrounds_native.o
clang -O2 tests/run/background_probe.c /tmp/backgrounds_native.o \
  -framework Metal -framework Foundation -o /tmp/background_probe
/tmp/background_probe src/appearance/shaders/backgrounds.metal
```

It also writes `/tmp/bonxie-background-<style>-light.ppm` and `-dark.ppm` for visual inspection.

## Canvas find

`items-search` checks Command-F from the focused or hovered item, live case-insensitive
Unicode matching, F3/Shift-F3 navigation and wraparound, buttons, no matches, Escape,
leaving the canvas, 700 matches and a 700-character query. Its goldens show the bottom
bar inside the searched canvas item and blue underlined search matches. `sources-search` searches across PDF and EPUB
pages in the background, scrolls to a match on another page, searches text files and
excludes images. `sources-words` also searches recognized web-page text and phrases.
`write-search` checks matches across all writing documents, including pages hidden by a folder,
F3 and Shift+F3 navigation across pages, wrapping, buttons, and clearing every page on Escape.
Search decorations are transient and separate from saved highlighter marks.

`search-vm-lifecycle` tests `Search_VM` without widgets, through a fake Finder: query retention and long queries,
command contracts, no-op versions, asynchronous results and busy state, scope changes, invalid contexts and
stale target identity. The Finder owns match navigation and wrapping; the view-model owns search lifecycle,
scope, target, query, result summary and command availability. `search-by-name` checks the field, result count,
Previous/Next, disabled controls with no matches, and Close through `Pomarine.Testing`.
The production Finder in `View.Search` adapts the text-area and picture/page engines and clears their
transient decorations when the search closes. `Search_UI` binds the query, summary, visibility and navigation
commands; `search-by-name` also checks closing and reopening the bar and moving it into the writing view.

`writing-vm-navigation` checks directory ancestry, section lookup, subtree visibility, selection by stable key,
reordering, deletion/replacement, no-op versions, reset and selection contracts without widgets.

`writing-vm-ordering` checks tree/page ordering, subtree moves in both directions, section/cycle and insertion
boundary contracts, document membership, persisted positions and parents, no-op versions/writes, insertion,
delete/reset, unplaced ties and growth to 2,048 documents using a fake persistence interface. The model maintains
page and membership indexes internally; tests check those indexes after moves and removal.
`writing-by-name` creates and selects a folder, checks filtering, adds a document in it, switches tabs and returns
to Overview through semantic controls. Tree rows expose Overview, Directory <title> and Document <title> names;
the sidebar's document button is named Add document.

## Declarative screen bindings

Most screen structures use `Pomarine.UI`: home project cards (each with its own rename field), settings,
the publish pane, outline blocks and buttons, the writing structure, grammar popups, links and search bars.
The semantic view tests above exercise their bindings; the existing goldens check their drawing.
The canvas tray's Add document and Add source buttons declare navigation commands. `nav-vm-creating`
checks their mode and modal-layer rules, refused-command contracts, effects and unchanged navigation
versions. The writing sidebar binds Add document to the same command and New folder to `Add_Folder`;
`writing-by-name` checks default document titles, insertion into the selected directory, nested folders,
focus in a new folder's name field and persistence after reopening. `nav-create-by-name` creates both
item kinds through their semantic names and checks their titles after reopening the project. Creation
geometry and focus remain in the view.
Writing section headers and empty sections bind indexed Add document and Notes commands.
`nav-vm-writing-sections` checks section bounds, modes, modal layers and effects;
`writing-sections-by-name` checks notes editing and focus, document placement after section reordering,
and bindings for sections added after mounting.
The writing sidebar headings bind `Sidebar_VM` commands. `sidebar-vm` checks saved choices,
mode and modal-layer rules, refused-command contracts, versions and failed preference writes.
`writing-sidebar-by-name` folds and unfolds all three sections, checks their controls disappear and return,
and creates a document after unfolding. The view retains sidebar geometry and continuous drags.
Publishing heading switches and the format select/menu bind `Publish_VM` commands. `publish-vm` checks
mode and modal-layer rules, invalid menu rows, refused commands and separate content/menu versions.
`publish-by-name` checks copied Markdown with each heading option, select and outside dismissal, and
choices retained after leaving Publish. `write-publishing` checks the existing preview and menu goldens.
Export and Copy also declare `Publish_VM` commands, with injected dialog, clipboard, clock and file interfaces.
`publish-output-vm` checks capability and modal rules, duplicate-export refusal, cancellation, empty paths,
write failures and retries, a captured 200,000-byte export completed after leaving its project, long paths,
extensions, real file output, copy verification and exact confirmation expiry/renewal. `publish-by-name`
checks the clipboard contents and Copied label, declared through `Caption_From`; the offscreen Export button
is disabled without a native window.
`publish-formats-vm` checks the seven formats of the menu (rows, extensions, which are text and so have a source
and Copy), re-choosing one, and that an export keeps the format it was asked for if the menu changes meanwhile;
`publish-by-name` checks that an EPUB has a chapter for a section. `write-publishing` also picks PDF, which hides the source. The writers are tested in `export-*` on a document with
every block and mark: plain text and HTML as strings, and EPUB, ODT, DOCX and PDF as files that are opened again
(`Ebook.Zip` for the zips, PDFium for the PDF's pages and title) and checked in their XML. They are also
worth opening in the real programs (Pages, Word, LibreOffice, Books) when a writer changes; `unzip -t` and
`xmllint --noout` on the parts, and `pandoc` reading a file back, are quick checks on a development machine.

Home-card Delete buttons declare `Home_VM.Ask_Delete`; the model cancels renaming and asks the injected
confirmation model. Confirmation retains a project key across changes to the recent list. `home-vm-deleting`
checks cancellation, unavailable rows, missing dialogs and deletion after reordering; `home-by-name` checks
confirmation, Escape, rename cancellation and cards added after mounting.
`pomarine/docs/ui.md` describes grips, app-owned containers, indexed bindings, late mounting, observers and
conditional focus. Their library checks live in `pomarine/examples/tests` (see `pomarine/docs/testing.md`).

Item windows and readers in `src/items/` now declare their content, toolbars and overlays with `Pomarine.UI`.
Pomarine's frame chrome is also composed through an embedded view. Their drawing and interactions remain
covered by `items-*`, `sources-*`, `write-source*`, context-menu and search checks. Section-link, linked-source,
writing context, grammar and publish menu rows use `Pomarine.UI.Menus` snapshots.

Item-list Click, Return and row actions bind beside the list through `On_Event` and `On_List_Actions`.
`item-list-vm-layers` checks that commands require the list's layer and revealing closes it before the surface acts.
`item-list-vm-rows-actions` checks stable row identities across changes and fresh identities for reused slots;
`item-list-by-name` and `items-list*` cover the production bindings by semantic name, keyboard and drawing.
Pomarine's `ui_controls_test` checks selection routing, action maps, invalid actions, model refusals and teardown.

Item-window and reader toolbar commands now bind through `Item_Window_VM` and `Reader_VM`. Their rules
are checked without widgets by `item-window-vm-rules` and `reader-vm-rules`; `item-controls-by-name` exercises
tool selection and zoom presets on the production item window. `reader-controls-by-name` checks the
production reader, external tool changes and reuse after release.

Item/source editor submit and path clicks, title-edit completion, minimize/restore/close, and both zoom
sliders now bind through `Pomarine.UI`. Source, writing-context, section-link, grammar-inline and publish-format
menu choices bind through `Menu_VM`; it checks current row availability through an injected router. The
widget-free rule tests cover minimized/closed frames, slider updates and invalid or disabled menu rows.

App-owned editor tool/follow operations, canvas widgets and continuous frame gestures still use view hooks. `Pomarine.Widgets.Layouts` remains the layout engine, and the native menu bar
retains `Nav_Binding`.

`writing-page-vm` tests page command ranks against the current document tree, modal guards,
released or reused item slots, transcription availability and injected menu/speech effects without widgets.
The writing semantic-name tests also open and close Sources through its declarative button binding.

`writing-sources-vm` checks source row commands, growing order, removal, modal layers and stored identities
across slot reuse. `write-sources` opens a production source row by semantic name and covers reader opening,
closing, pinning and drawing. Source rows declare their Click binding beside their layout; the generic widget callback
adapter is removed from `View.Responses`, leaving its continuous editor hooks.

## Updating

`update-vm-*` runs `Update_VM` on fake services (no network, disk or script): what a check finds, that nothing is
fetched before Install, Skip and Later, the install step by step and where it can fail, and when the program
looks by itself. The updater crate's own tests (versions, manifests, release JSON, Ed25519, staging a real disk
image, the swap script) are in `updater/tests`; see docs/UPDATING.md.
