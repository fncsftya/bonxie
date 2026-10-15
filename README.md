# Bonxie

A MacOS-only tool for planning and writing podcasts.

## Menus and accessibility

The menu bar (File, Edit, Go) is the system's, and says the same commands as
the buttons do; what is possible when is dimmed or ticked as the screen
changes. The window is described to VoiceOver through AccessKit (Pomarine's
`native/` crate): buttons, headings, text and the settings can be read and
pressed, and what is changed is told as it changes.

## PDFs, e-books and text

A new source window asks where it comes from: **From URL** (a link, as before) or
**From File** (the system's file dialog; the path is then shown where the link was, and
pressing it chooses another file).

A link or file ending `.pdf`, `.epub`, `.fb2`, `.xps`, `.oxps`, `.cbz` or `.mobi` is
copied into the project's `sources` folder (a link is downloaded; WebKit is not used), and
its pages are drawn, one at a time, with MuPDF (the `ebook` crate; the way it draws a page
follows `vendor/SDLBook`). Buttons over the picture turn the page. A link or file ending
`.txt`, `.text`, `.md` or `.markdown` is copied and shown as text that can be selected and
copied, but not changed.

Build with MuPDF installed: `brew install mupdf` (`MUPDF_PREFIX` says where it is, if not
Homebrew's on Apple silicon).
