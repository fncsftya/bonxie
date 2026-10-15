# Bonxie

A MacOS-only tool for planning and writing podcasts.

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
