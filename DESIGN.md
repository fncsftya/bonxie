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
  0); Widgets can be hidden (`Set_Visible`) or taken out
  (`Remove`, with their children; build them again top-down). No
  callbacks: widgets are polled (`Take_Click`) and models are pulled in
  `Update`.
- bonxie (`src/`): the app. `Scripts` owns the document, its file and
  saved state. `Projects` keeps projects (id, title, description, created
  and updated times) in SQLite (`Ada_Sqlite3`), at
  `$XDG_CONFIG_HOME/bonxie/projects.db` (`~/.config/bonxie/projects.db`).
  `Viewer` has two screens, built once and swapped with `Set_Visible`:
  the home (recent projects, each to open, rename or delete, with a
  dialog over it to confirm a deletion; New Project, Settings) and a project (the
  document, and a toolbar with Close). Offscreen sessions keep their
  projects in memory. `Viewer` holds the `Session` and the public API,
  the event loop and the window's lifecycle; the rest is in its private
  children: `Style` (sizes, colours), `Build` (widgets, built once),
  `Painting`, `Recent` (the list and renaming), `Deletion` (the
  dialog), `Navigation` (between screens) and `Clicks` (what a click does).
  Icons are SVG files in `share/bonxie/icons`
  (`UI.Icons`, rasterized by SDL3_image, drawn in one colour as a mask);
  a button with an icon falls back to its label if there is none.

`bench/` measures layout (`bin/bench`) and text areas
(`bin/text_area_bench`, on documents of several sizes).