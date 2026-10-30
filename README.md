# Bonxie

A writing application for macOS. Plan an outline, collect notes and sources
on an infinite canvas, and write with reference material beside your draft.

Currently only supports Apple Silicon.

![](docs/write-with-research.png)

*Full workflow, writing with research*

## Features

- **Outlining:** plan your project with a description, coloured sections and section notes.
- **2D planning:** arrange and connect documents and sources on an infinite canvas.
- **Dictation and transcription:** speech-to-text using macOS speech recognition, Parakeet (recommended) or Granite.
- **Grammar and spelling:** review suggestions from [Harper](https://writewithharper.com/) as you write.
- **Flexible structure:** reorder sections and documents, and organise drafts into folders.
- **Sources beside your writing:** view web pages, PDFs, EPUBs, text files and images; pin references and add highlights.
- **Export:** Markdown, plain text, HTML, EPUB (a chapter to each section), OpenDocument, Word and PDF (A4), written by bonxie itself (no other program needed).
- **Themes:** light or dark mode, with optional procedural backgrounds and colour variations.
- **Alternative wordings:** use Reword to keep and compare different versions of a passage.

## TODO

- Better editing workflows
- More places to put notes
- Project-level undo
- Version control
- Backups / syncing
- Cross platform?

Patches welcome!

# Screenshots

![](docs/outline.png)

*Create an outline for your project*

---

![](docs/canvas.png)

*See writing and sources on a 2d canvas, create links between writing and research*

![](docs/canvas-zoomed-out.png)

*Zoomed out view of the infinite canvas*

---

![](docs/write-mode.png)

*Rich text editing*

![](docs/write-mode-dark.png)

*Dark mode supported*

---

![](docs/dictation.png)

*Dictation with macOS or Parakeet (recommended)*

![](docs/pre-reword.png)

*Rewording: give alternative wordings to your writing*

![](docs/post-reword.png)

*Cycle alternative versions of rewordings inline*

![](docs/reordering.png)

*Easily reorder the parts of your project*

---

![](docs/export.png)

*Export your writing*

![](docs/settings.png)

*Configurable themes and colours*

![](docs/homepage.png)

*Projects view*
## macOS app bundle

Run `tools/bundle-macos.py` on macOS to build a release executable and create
`bin/Bonxie.app`. The script includes the application resources and dynamic
libraries and signs the bundle locally with an ad-hoc signature. The resulting
bundle is for local use; distribution to other Macs requires an Apple Developer
signature and notarization. The icon is generated from `share/bonxie/logo.png`;
a higher-resolution source will improve its appearance at larger sizes.

Run `tools/dmg-macos.sh` to build the release app and create `bin/Bonxie.dmg`,
with an Applications shortcut for drag-and-drop installation.
