# Vendored: SDLBook

- Upstream: https://github.com/rofl0r/SDLBook
- Commit: 9ebf64275bc8a0c35ce38dea989f8af7d54f4999 (2026-08-17)
- License: GPL-3.0 (see COPYING), as bonxie is.
- Taken: the upstream files as they are, except `.git`. Not built: bonxie
  uses SDL3 and Pomarine's widgets, and SDLBook is SDL1/SDL2.

What bonxie uses of it is the way it renders a page with mupdf
(`render_pdf_page`, `open_pdf`): see `ebook/src/ebook_mu.c`, which follows
those with mupdf's current API (SDLBook's calls are of 1.x before 1.17).
