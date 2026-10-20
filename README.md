# Bonxie

A MacOS-only tool for planning and writing podcasts.

## Grammar suggestions

In Write mode, **Show Grammar Suggestions** at the top of the sidebar is on
by default. Document text is checked locally with Harper, using four Ada
worker tasks. Edits are checked after a 500 ms pause. Notes are excluded.
Suggestions use Harper's category colors, with a tinted background and an
underline. Turning the switch off clears the highlights.

Before the first build, run `harper/fetch-harper.sh` to fetch the pinned Harper
source and dictionary into its ignored vendor directory.

The button beside the switch counts diagnostics with a suggested correction.
It turns amber when there are fixes available. Press it to open a scrollable
list of all diagnostics, then expand a card to read its explanation and
apply a correction. Each correction can be undone separately. Click outside
the popout, press its button again, or press Escape to close it.

Click an inline diagnostic to see a compact list of suggested fixes. Click
a replacement to apply it, or **Delete** to remove the marked text. Typing,
scrolling the document, clicking elsewhere, or pressing Escape dismisses
this popover. Fixes remain undoable.

## Find Sources (experimental)

The toolbar of a note, on the canvas or in the writing view, has a purple **Find
Sources** button at its right. It can be used when the AI is on in Settings and
the note has text. The local model (`mlx`; it is made for Gemma 4, which is asked
not to think aloud) reads the text and writes one to three web searches; they are run on
DuckDuckGo (`websearch`: WebKit loads the results page offscreen, and the links are read
from it), spaced at least five seconds apart, and for longer after DuckDuckGo asks for proof
of a person; the links a search found are kept for fifteen minutes (sixteen queries at most),
so that the same query asked again is answered from memory and DuckDuckGo is not.

Up to five of what is found are taken at once, and the model scores each as a source of
the text, on relevance, support and quality; those that score 80% or more are kept.

- **PDFs are preferred.** A PDF is drawn well in a project, so a link to one is fetched
  and its own text is read, and so is the PDF that a page is the front of: arXiv's
  abstract and HTML pages and Taylor & Francis's preview pages are taken as their PDFs, and
  any page that says which PDF it is of (`citation_pdf_url`) is taken as that, and so is
  one whose only PDF button (PDF, Download PDF, PDF/ePub) leads to one, as the ACM Digital
  Library's do. They go first. A PDF is fetched plainly, within a minute; if the site turns
  that away (some sites will give a file only to a browser) the browser is asked for it, as
  it would download it, and if that fails too, the page it is the front of is taken in its
  place. Its text is read from the PDF as it is, with no drawing of pages.
- **A page is photographed** by `webshot`: the whole of it, however long (it is shrunk to
  fit a picture 16,384 pixels tall when it is longer than 8,192 points), and so that its
  words can be read all the same, the first four screens of it at full size, which `vision`
  reads for the model to judge.
- **Cookie banners are cleared by the model.** `webshot` first takes the top of the page (a
  window 1024 points high, for a notice to be in one screen), and the words `vision` reads
  from that are given to the model, which cannot see; it says if something covers the page
  and the exact words of the button that closes it, and `webshot` presses the button with
  those words (a letter wrong, or the start of them, is found), and looks again. Notices are
  put up a while after a page has loaded, more so when many are loading: so when the whole
  page is to be taken, `webshot` looks once more for one that has come since (and waits a few
  seconds for a known consent tool that has not yet shown), and the model is asked again. Cookies are accepted (the page is read in a window that keeps nothing); a
  button that subscribes, pays or signs in is never pressed, however it is asked for, and the
  model is told when a button could not be, to choose another. Ordinary captures of a source
  use a plainer way, by what the page says of itself.
- Each ask of the model has up to 8,192 tokens.

A toast at the top right of the project says how far on it is, and has a button
to stop it. When it is done its button, **Review**, lists what was found, best first, and shows
the page of the source under the pointer (the best, to begin with) in a window beside the list, as
a source is in the writing view (a PDF as its pages), to move, size and look at before choosing:
click one to add it as a source (a window of the page's picture, or the PDF, with a line from the
note), or **Add all**, or **Dismiss**. The pictures and PDFs were had while it worked, so
adding a source does not load it again. What is not added is thrown away
when the toast is dismissed or the project is left.

The prompts and how replies are read are `Source_Finding` (`src/ai`); which addresses are of
PDFs is `Source_Links`; the work, a state machine that is polled as the event loop runs, is
`Source_Finder`. To try it without the app: `cd tests && alr exec -- gprbuild -P finder_run.gpr`,
then `bin/finder_run <model folder> ["text"]`.

## Menus and accessibility

The menu bar (File, Edit, Go) is the system's, and says the same commands as
the buttons do; what is possible when is dimmed or ticked as the screen
changes. The window is described to VoiceOver through AccessKit (Pomarine's
`native/` crate): buttons, headings, text and the settings can be read and
pressed, and what is changed is told as it changes.

## PDFs and text

A new source window asks where it comes from: **From URL** (a link, as before) or
**From File** (the system's file dialog; the path is then shown where the link was, and
pressing it chooses another file).

A link or file ending `.pdf` is
copied into the project's `sources` folder (a link is downloaded; WebKit is not used), and
its pages are drawn, one at a time, from PDFium's objects: shapes, text (set by CoreText, one character at
each place the PDF puts it) and pictures are drawn by SDL at any zoom, so a page stays sharp, and its words
are the PDF's own text (the `ebook` crate; `Pomarine.Pages` and `Pomarine.Widgets.Pictures.Set_Page`). A
page PDFium has to draw itself (rotated, rotated text, shading) is shown as a picture, as before. Buttons
over the page turn it. A link or file ending
`.txt`, `.text`, `.md` or `.markdown` is copied and shown as text that can be selected and
copied, but not changed.

Build with PDFium fetched: `ebook/fetch-pdfium.sh` (prebuilt, from pdfium-binaries, into
`ebook/pdfium`; `PDFIUM_PREFIX` says where else it is). EPUB e-books are read and set in pages by the crate's own Ada code (zip, inflate, XHTML, layout in
`Ebook.Books`), needing no library; their style sheets and pictures are not used.
