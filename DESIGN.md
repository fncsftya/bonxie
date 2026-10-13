# Design

From the bottom up; each crate depends only on those before it.

- `texts`: documents, held apart from how they are shown
  (`Texts.Documents`): paragraphs with stable ids and app-defined kinds,
  edits as one splice, a log of changes for views to catch up with, and
  the undo history (with `Begin_Step`/`End_Step` for app commands). No
  graphics.
- `sdl3`, `coretext`, `yoga`: bindings. `webshot` (macOS only) takes a
  picture of a web page: an Objective-C shim (`webshot_wk.m`, built with
  Apple's clang) loads it in an offscreen WKWebView and writes the whole
  length of it, 1024 pixels wide and at most 16384 tall, as a PNG. It is a
  job in a slot, polled (`State`), and goes on only while the main thread
  runs its run loop, which SDL's event wait does.
- `typeset`: a layout of a document for one view (`Typeset.Layouts`):
  lines, made lazily (a long paragraph only as far as shown), heights as
  running sums (`Typeset.Sums`); drawing it (`Typeset.Views`).
- `ui` (crate `bonxie_ui`): components. `UI.Text_Areas` is a view of a
  document the app owns; several may show one document. `UI.Widgets` is
  a retained tree of widgets (`Panels`, `Buttons`, `Labels`, `Editors`,
  which wraps a text area, and `Text_Fields`, an editor of one line) the
  app owns and adds top-down; Yoga lays them out in pixels. Widgets keep their own state and say when it changes
  (`Invalidate`); the tree keeps the damage, repaints only that when
  the target keeps its frame (`Retained`; a window's renderer does, by
  drawing to an image of its own that `Present` copies, which `Fit`
  keeps the window's size), and routes events (hit test, focus, capture,
  hover). A widget can see what part of it is repainted
  (`Painting_Part`) and skip the rest, as `Editors` does for a blinking
  caret. A widget says what cursor it wants (`Cursor`; `Wanted_Cursor`
  gives the tree's, from the one holding a press or under the pointer).
  `Canvases` is an infinite canvas to pan (wheel, trackpad, middle
  button) and zoom (Command with the wheel, a pinch, Command with =, -,
  0); `Grips` is a place to drag by (a title bar, a corner to size by),
  which says how far the pointer has gone; `Scrollers` scrolls its one
  child with the wheel; `Pictures` shows a PNG as wide as its box
  (or a zoom of that, scrolled across too), scrolled with the wheel (read when
  first drawn, let go of by `Unload`); `Sliders` is a knob to drag along a
  track, from 0.0 to 1.0. Widgets can be put last of their parent's
  (`Raise_To_Front`, for those placed by their edges), hidden (`Set_Visible`) or taken out
  (`Remove`, with their children; build them again top-down). No
  callbacks: widgets are polled (`Take_Click`) and models are pulled in
  `Update`.
- bonxie (`src/`): the app. `Scripts` owns the document, its file and
  saved state. `Projects` keeps projects (id, title, description, created
  and updated times) in SQLite (`Ada_Sqlite3`), at
  `$XDG_CONFIG_HOME/bonxie/projects.db` (`~/.config/bonxie/projects.db`).
  `Items` keeps the items of a project's canvas (a window with a title,
  text, a place and size in canvas units, a state: open, minimised
  or closed, and a kind: a note, or a source, whose text is a link and
  which has a picture of the page, as a PNG at
  `<config>/bonxie/<project id>/sources/<item id>.png`, by
  `Projects.Folder`, which goes with its item and its project) in the same database, in a table that refers to the
  project, so that they go with it (`Projects.Connection` shares the
  connection, with foreign keys on). `Items.Windows` is the widgets that
  show one item: its window on the canvas (title bar to drag, a title that
  is text until double-clicked, minimise and close, a text editor, a status line of the word
  count, a corner to size by) and its short bar in the dock; and what has
  to be written back, which it does (`Flush`) when the pointer lets go,
  or typing has stopped for a moment, or its focus has left it. A source's
  window has the link in the place of the text (the one text area, set to
  a single line), then the picture, and in its status line a slider (on a log scale) and a button
  that opens a menu of zooms (the zoom is of the picture within its window,
  kept in the item's `zoom`), and Return in the link has `Viewer`
  start `Webshot` for it. A project
  has at most `Items.Capacity` items, a window to each, in the session:
  a text area is about 124 KB, and a window has two. Together they are
  more than the main thread's usual 8 MB of stack, so the executables
  are linked with 64 MB (`-Wl,-stack_size`).
  `Viewer` has two screens, built once and swapped with `Set_Visible`:
  the home (recent projects, each to open, rename or delete, with a
  dialog over it to confirm a deletion; New Project, Settings) and a project (the
  canvas, with its items' windows as children, so that the wheel pans
  it from anywhere but the text; a dock above the tools bar of
  the minimised items; the tools bar, with Add Item, Add Source and Items, which
  shows a dialog of a scrolling list of the items, each to show or hide
  or remove, or to click the title of, to go to it; and a toolbar with Close). Offscreen sessions keep their
  projects in memory. `Viewer` holds the `Session` and the public API,
  the event loop and the window's lifecycle; the rest is in its private
  children: `Style` (sizes, colours), `Build` (widgets, built once),
  `Painting`, `Recent` (the list and renaming), `Deletion` (the
  dialog), `Navigation` (between screens), `Clicks` (what a click does),
  `Canvas_Items` (the windows of a project's items: loading, adding,
  keeping them where the canvas has them, writing them) and `Listing`
  (the list of items).
  Icons are SVG files in `share/bonxie/icons`
  (`UI.Icons`, rasterized by SDL3_image, drawn in one colour as a mask);
  a button with an icon falls back to its label if there is none.

`bench/` measures layout (`bin/bench`), text areas
(`bin/text_area_bench`, on documents of several sizes) and dragging and
sizing items on a canvas (`bin/item_bench [items [frames [paragraphs
[gpu]]]]`, offscreen in software, or with `gpu` in a hidden window, timing
the drawing but not presenting).