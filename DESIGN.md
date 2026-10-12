# Design

From the bottom up; each crate depends only on those before it.

- `texts`: documents, held apart from how they are shown
  (`Texts.Documents`): paragraphs with stable ids and app-defined kinds,
  edits as one splice, a log of changes for views to catch up with, and
  the undo history (with `Begin_Step`/`End_Step` for app commands). No
  graphics.
- `sdl3`, `coretext`, `yoga`: bindings.
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
  child with the wheel. Widgets can be put last of their parent's
  (`Raise_To_Front`, for those placed by their edges), hidden (`Set_Visible`) or taken out
  (`Remove`, with their children; build them again top-down). No
  callbacks: widgets are polled (`Take_Click`) and models are pulled in
  `Update`.
- bonxie (`src/`): the app. `Scripts` owns the document, its file and
  saved state. `Projects` keeps projects (id, title, description, created
  and updated times) in SQLite (`Ada_Sqlite3`), at
  `$XDG_CONFIG_HOME/bonxie/projects.db` (`~/.config/bonxie/projects.db`).
  `Items` keeps the items of a project's canvas (a window with a title,
  text, a place and size in canvas units, and a state: open, minimised
  or closed) in the same database, in a table that refers to the
  project, so that they go with it (`Projects.Connection` shares the
  connection, with foreign keys on). `Items.Windows` is the widgets that
  show one item: its window on the canvas (title bar to drag, a title that
  is text until double-clicked, minimise and close, a text editor, a status line of the word
  count, a corner to size by) and its short bar in the dock; and what has
  to be written back, which it does (`Flush`) when the pointer lets go,
  or typing has stopped for a moment, or its focus has left it. A project
  has at most `Items.Capacity` items, a window to each, in the session:
  a text area is about 124 KB, and a window has two.
  `Viewer` has two screens, built once and swapped with `Set_Visible`:
  the home (recent projects, each to open, rename or delete, with a
  dialog over it to confirm a deletion; New Project, Settings) and a project (the
  canvas, with its items' windows as children, so that the wheel pans
  it from anywhere but the text; a dock above the tools bar of
  the minimised items; the tools bar, with Add Item and Items, which
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

`bench/` measures layout (`bin/bench`) and text areas
(`bin/text_area_bench`, on documents of several sizes).