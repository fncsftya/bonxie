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
  length of it, 1024 points wide (pictured at twice that in pixels, or fewer
  for a very long page: at most 16384 tall) and at most 16384 points tall, as a PNG. It is a
  job in a slot, polled (`State`), and goes on only while the main thread
  runs its run loop, which SDL's event wait does. `vision` (macOS only)
  finds the text in a PNG with Apple's Vision (`VNRecognizeTextRequest`, an
  Objective-C shim, `vision_ocr.m`), on the file at the size it is: each
  word, in reading order, with its box as fractions of the picture
  (`Vision.Recognize`; at most `Max_Words`), put in reading order by
  `Vision.Layout`, which cuts the lines apart at the gutters between
  columns and the gaps between bands, and reads down each column in turn. `Vision.Jobs` does it in the
  background, a task to each slot (the same slots as `Webshot`), polled the
  same way and taken (`Take`) when `Done`.
  `speech` (macOS 26 or later; the program is linked to need it) turns what
  the microphone hears into text with Apple's `SpeechAnalyzer`, on-device.
  That API is Swift only, so `speech_swift.swift` gives Ada a C interface
  (`sp_begin`, `sp_end`); Alire has no Swift configuration, so gprbuild is
  told it is C, and `swiftc.sh` passes it on to `swiftc`. The Swift runtime
  is linked from the SDK (`SPEECH_SDK` says where, if not the Command Line
  Tools'), and an `Info.plist` with the microphone's usage description is
  embedded in the program. `Speech.Begin_Listening`/`End_Listening` wait,
  so `Speech.Jobs` does them in a task to each slot (as `Vision.Jobs`):
  `Start`, then `Stop`, polled (`State`: starting, listening, finishing,
  done) and taken (`Take`) when `Done`.
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
  0), and draws lines between places on it (`Set_Lines`, in canvas units,
  under what is on it) and a faint one being dragged out (`Set_Ghost`, over
  it); `Pins` is a small round handle to press and drag from, and to let go
  on (`Set_Accepting` says it may be, and it is then drawn with a border
  while the pointer is over it); `Grips` is a place to drag by (a title bar, a corner to size by),
  which says how far the pointer has gone; `Scrollers` scrolls its one
  child with the wheel; `Pictures` shows a PNG as wide as its box
  (or a zoom of that, scrolled across too), scrolled with the wheel (read when
  first drawn, let go of by `Unload`), and, if told the words in it
  (`Set_Words`, a `Vision.Result` it does not own), which are selected as
  text over it: a drag, a double click for a word, a triple for a line,
  Command with A and C; the words' boxes are fractions of the picture, so
  they follow its zoom and scroll. With the highlighter as its tool
  (`Set_Tool`) a drag marks it instead: a translucent band along the line
  pressed on, kept like the words' boxes as fractions of the picture (up to
  `Max_Marks`), and counted by `Marks_Version`; `Scrollbars` is the thin bar that `Scrollers`, `Pictures` (across too,
  when zoomed) and `Text_Areas` show along their edge when there is more than
  the box shows and the pointer is over them: thicker near the pointer, and
  dragged (or pressed beside) to scroll, given the mouse events first; a widget draws what goes over
  its children in `Draw_Over`; `Sliders` is a knob to drag along a
  track, from 0.0 to 1.0; `Progress_Bars` is a bar filled from the left, from 0.0 to 1.0, told how far on a job is. Widgets can be put last of their parent's
  (`Raise_To_Front`, for those placed by their edges), hidden (`Set_Visible`) or taken out
  (`Remove`, with their children; build them again top-down). No
  callbacks: widgets are polled (`Take_Click`) and models are pulled in
  `Update`.
- bonxie (`src/`): the app. `Scripts` owns the document, its file and
  saved state. `Projects` keeps projects (id, title, description, created
  and updated times, and how its canvas is seen: the zoom and the point in the
  middle, written when the project is left or the program quits, and
  restored on opening; one without goes to its items) in SQLite (`Ada_Sqlite3`), at
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
  kept in the item's `zoom`), and, in the middle of the status line, buttons for the cursor, the
  highlighter and the eraser of its marks (a source's window is wider, for room); a click outside the
  window puts the highlighter away. The marks are kept in the database
  (`item_marks`, a row to a mark, with the item; `Items.Save_Marks`,
  `Load_Marks`) and forgotten with a new picture. Return in the link has `Viewer`
  start `Webshot` for it, and, while it is taken, a bar along the foot of the status line shows how far on it is (`Webshot.Progress`: the page's load, then the settling and the snapshot). A source still called "Untitled source" takes the title of the page (`Webshot.Page_Title`) when its picture is taken. When the picture is taken (or is found
  without words kept, as in a project from before they were) `Viewer`
  starts `Vision.Jobs` on it, and the words found are kept in the
  database, in `item_words` (a row to a word, with the item, so that they
  go with it; `Items.Save_Words`, `Load_Words`) and stamped on the item
  (`recognized_at`, and `words_version`, of how they were put in order:
  those kept by an earlier version are looked for again), so opening the project again loads them and does not
  look again; a new picture forgets them (`Set_Captured`). A project
  has at most `Items.Capacity` items, a window to each, in the session:
  a text area is about 124 KB, and a window has two, and a source's has
  its words, up to about 160 KB. Together they are
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
  A note's status line has a button to dictate: it starts `Speech.Jobs` in
  the slot of its window (`Viewer.Canvas_Items`) and becomes a stop button;
  stopped, what was heard is put in the note by `Items.Windows.Add_Dictation`:
  at the caret if the text is focused, else as a new paragraph after the
  text (or as the text, if there is none).
  Items are linked, visually, by `Viewer.Links`: a pin in the middle of each
  side of every open window, shown while the pointer is over the window.
  Dragging from one shows the pins of the other windows and a ghost line to
  the pointer; letting go on one of them joins the two items. A link is a
  line from a side of one to a side of the other, kept in the database
  (`item_links`, which goes with its items; `Items.Add_Link`, `Load_Links`),
  at most one between two items, and drawn by the canvas under the windows.
  A press on a link's line (`Canvases` finds it, within a few points) selects
  it: it gets a halo, a pin over its target end to drag to another pin (of
  any window but the one it starts from; `Items.Move_Link`), and a toolbar
  below it to choose its stroke (solid, dots, dashes), its end (plain,
  arrow) and its colour (one of five), kept with the link
  (`Items.Set_Link_Style`), and to delete it, as Backspace does.
  Icons are SVG files in `share/bonxie/icons`
  (`UI.Icons`, rasterized by SDL3_image, drawn in one colour as a mask);
  a button with an icon falls back to its label if there is none.

`bench/` measures layout (`bin/bench`), text areas
(`bin/text_area_bench`, on documents of several sizes) and dragging and
sizing items on a canvas (`bin/item_bench [items [frames [paragraphs
[gpu]]]]`, offscreen in software, or with `gpu` in a hidden window, timing
the drawing but not presenting).