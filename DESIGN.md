# Design

From the bottom up; each crate depends only on those before it.

- `texts`: documents, held apart from how they are shown
  (`Texts.Documents`): paragraphs with stable ids and app-defined kinds,
  edits as one splice, a log of changes for views to catch up with, and
  the undo history (with `Begin_Step`/`End_Step` for app commands). No
  graphics.
- `sdl3`, `coretext`, `yoga`: bindings. `SDL3.Pictures` reads a PNG into
  memory apart from any renderer (and its size from its header alone);
  `SDL3.Pictures.Jobs` does that on two tasks of its own, those asked for
  `Urgent` before the others, polled (`State`) and made into a texture on
  the drawing thread (`Finish`). `webshot` (macOS only) takes a
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
  `speech` can instead use a model (`Speech.Jobs.Start (Slot, Model, File)`):
  `Speech.Capture` (more of `speech_swift.swift`: `sp_cap_*`) hears the
  microphone and converts it to 16 kHz mono floats in the audio tap, as it
  arrives, into a bounded buffer (two minutes); the slot's task drains it
  into `Transcribe.Sessions` (streaming) every 50 ms, publishing the text so
  far for `Heard_So_Far` and, once stopped, the rest and `Finalize_Stream`
  for `Take`. The microphone is heard from the start, while the model loads
  (a second or so), so nothing said then is lost, only late. Stop and Reset
  are seen by the task polling, not by an entry. `Viewer.Canvas_Items.
  Toggle_Dictation` picks the engine: Parakeet if chosen in Settings (and
  its file is there, else the note's status line says it is not), else
  MacOS.
- `transcribe`: Ada bindings to `transcribe.cpp` (the git submodule
  `transcribe/transcribe.cpp`). `native/build.sh` (run by Alire after the
  crate is fetched, and again when the submodule moves) builds it and ggml as
  static libraries into `native/lib` with cmake, Metal on; the crate's
  project links them and the frameworks they need. `Transcribe.Sessions` is
  a model and its stream (`Open`, `Begin_Stream`, `Feed`, `Text`,
  `Finalize_Stream`): the C structs it reads are checked against the
  library's own sizes, the library's log is ignored, and text is copied out
  at once (the library's pointers last only until the next feed).
  `transcribe/tests/stream_wav` feeds a WAV through a model in chunks.
- `typeset`: a layout of a document for one view (`Typeset.Layouts`):
  lines, made lazily (a long paragraph only as far as shown), heights as
  running sums (`Typeset.Sums`); drawing it (`Typeset.Views`).
- `ui` (crate `bonxie_ui`): components. `UI.Text_Areas` is a view of a
  document the app owns; several may show one document. `UI.Widgets` is
  a retained tree of widgets (`Panels`, `Buttons`, `Labels`, `Editors`,
  which wraps a text area, and `Text_Fields`, an editor of one line) the
  app owns and adds top-down. Buttons stand up, bevelled, with no
  shadow (`UI.Boxes.Draw_Raised`), are pressed in while held, and
  stay so, in the accent, as a toggle that is on (`Set_Selected`); one can
  be turned off (`Set_Enabled`), take the focus and be clicked by Return or
  Space (`Set_Focusable`), or be a dropdown, with a caret in a part of its
  own (`Set_Dropdown`; selected, it is open). An editor can be invalid,
  turned off, show a hint while empty (`Set_Placeholder`) and an icon
  before a single line (`Set_Icon`, which leaves room for it, as
  `Text_Areas.Set_Trail` does at the right). Besides: `Checks` (a box to
  tick, or a radio), `Switches`, `Selects` (a field that opens a menu),
  `Menus` (rows of headings, actions, boxes, lines and notes, which says
  the row clicked: `Take_Choice`), `Chips`, `Badges` (a count, or a tag),
  `Tooltips` and `Toasts`; Yoga lays them out in pixels. Widgets keep their own state and say when it changes
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
  it); `Pins` is a small square handle to press and drag from, and to let go
  on (`Set_Accepting` says it may be, and it is then drawn with a border
  while the pointer is over it); `Grips` is a place to drag by (a title bar, a corner to size by),
  which says how far the pointer has gone; `Scrollers` scrolls its one
  child with the wheel; `Pictures` shows a PNG as wide as its box
  (or a zoom of that, scrolled across too), scrolled with the wheel (read in
  the background, by `SDL3.Pictures.Jobs`, when first drawn or asked for
  with `Load_Soon`, and let go of by `Unload`; its height is known from the
  file's header, so the box is the size it will be before the picture
  arrives), and, if told the words in it
  (`Set_Words`, a `Vision.Result` it does not own), which are selected as
  text over it: a drag, a double click for a word, a triple for a line,
  Command with A and C; the words' boxes are fractions of the picture, so
  they follow its zoom and scroll. With the highlighter as its tool
  (`Set_Tool`) a drag marks it instead: a translucent band along the line
  pressed on, kept like the words' boxes as fractions of the picture (up to
  `Max_Marks`), and counted by `Marks_Version`; `Scrollbars` is the bar that `Scrollers`, `Pictures` (across too,
  when zoomed) and `Text_Areas` show along their edge when there is more than
  the box shows and the pointer is over them: a trough with an arrow button
  at each end, which scrolls a step, and a bevelled thumb, dragged (or
  pressed beside) to scroll, given the mouse events first; a widget draws what goes over
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
  a single line, with an icon of a link, a hint of https:// while it is
  empty, and, until its picture is taken, an Add button, which does what
  Return does), then the picture, and in its status line a slider (on a log scale) and a button
  that opens a menu of zooms (the zoom is of the picture within its window,
  kept in the item's `zoom`), and, in the middle of the status line, buttons for the cursor, the
  highlighter and the eraser of its marks (a source's window is wider, for room); a click outside the
  window puts the highlighter away. Zoomed out under 0.75 a window is compact: no status line (so no corner to size by; zoom in to do that), and a source no link, only the title and the content; and its bar and title shrink with the zoom, down to 0.6, so the title is not large over the text. The marks are kept in the database
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
  `Preferences` keeps what the user has chosen at
  `<config>/bonxie/settings` (for now, the speech model: MacOS or Parakeet)
  and says where the file Parakeet needs is kept
  (`<config>/bonxie/speech/model.gguf`). `Downloads` fetches a file on a
  task of its own, one at a time (it runs `curl`, so redirects and TLS are
  its business), to a `.part` file beside the name it is given, moved into
  place only when whole; it is polled (`State`, `Fraction`, from the size of
  the `.part` file and the length the server gave) and cancelled when the
  program ends.
  `Viewer` has two screens, built once and swapped with `Set_Visible`:
  the home (a sidebar with New Project and Settings; the recent projects
  as cards, each with a picture of its canvas (`Previews`, a widget of the
  app's own), how many documents and sources it has, and buttons to rename
  or delete it, with a dialog over it to confirm a deletion; and after them
  the outline of a card, to make one) and a project (a toolbar across the
  top: the way back to the projects, the project's name, the tabs in the
  middle, and Items at the right, which shows a dialog of a scrolling list
  of the items, each to show or hide or remove, or to click the title of,
  to go to it; the canvas, with its items' windows as children, so that the
  wheel pans it from anywhere but the text; a tray over the foot of the
  canvas, in the middle, with Add Document and Add Source; and a dock below
  it of the minimised items). Offscreen sessions keep their
  projects in memory. `Viewer` holds the `Session`, the event loop and the
  window's lifecycle. What a test looks at and moves about is in its public
  children, by what they are of: `Home_Screen` (the recent projects),
  `Settings`, `Project_Screen` (the project and its view), `Canvas_Camera`
  (zoom and origin), `Canvas_Windows` (the items), `Canvas_Links` (links
  and pins), `Documents` (pages and directories) and `Sources`. The rest
  is in its private children. `Session` is a record of groups, each a
  run of what it held, in the order it is destroyed in: `Root`, `Home_View`,
  `Confirm`, `Prefs`, `Toolbar`, `Page_View`, `Dock`, `Nav`, `Item_List`,
  `Host` (script, window, renderer), `Docs`, `Context`, `Naming`, `Reading`,
  `Dragging`, `Linking`, `Title_Edit`, `Opened` and `Shell`, besides
  `Canvas_View` and `Windows`. The private
  children are `Style` (sizes, colours), `Build` (widgets, built once),
  `Painting`, `Recent` (the list and renaming), `Deletion` (the
  dialog), `Navigation` (between screens), `Clicks` (what a click does),
  `Canvas_Items` (the windows of a project's items: loading, adding,
  keeping them where the canvas has them, writing them) `Listing`
  (the list of items) and `Settings_View`. Settings take the home screen's
  place (its Settings button; Close at the right of a bar across the top
  that stays while the form scrolls, or Escape): a form as wide as a page in
  the writing view, centred, with a Speech section whose one option, Model,
  is a radio of MacOS and Parakeet. With Parakeet chosen there is a Download
  button, enabled only while the file is not there (else a label says the
  model is available) and a progress bar while it comes.
  A note's status line has a button to dictate: it starts `Speech.Jobs` in
  the slot of its window (`Viewer.Canvas_Items`) and becomes a stop button;
  stopped, what was heard is put in the note by `Items.Windows.Add_Dictation`:
  at the caret if the text is focused, else as a new paragraph after the
  text (or as the text, if there is none).
  While it listens, what has been heard so far (`Speech.Jobs.Heard_So_Far`:
  the settled words and the provisional ones, from SpeechAnalyzer's volatile
  results) is shown in the note as it comes, by
  `Items.Windows.Set_Live_Dictation`, in the same place, in both the canvas's
  window and Write's page (they share the document). These edits are not
  recorded, so undo never sees them; `Add_Dictation` (or a failure) takes
  them back first, so the final text is the one step. If anything else
  changes the text meanwhile, the live text is left as it is and not updated.
  `Viewer` has a second view of a project, Write (`Viewer.Writing`, with
  tabs in the middle of the toolbar to choose between it and the canvas). In
  it the items that are not sources are Documents, each on a white page
  (`UI.Text_Areas.Set_Grows`: a text area as tall as its text, which does
  not scroll or take the wheel, so the column of pages scrolls as one;
  `Content_Height` is what `Writing.Fit` sizes it by, after each layout, and
  it keeps the caret in view). Above each page, outside it, are the document's
  title, a Sources dropdown (how many sources the document is linked to on
  the canvas on the button; its menu has a box for each, ticked for the one
  pinned: ticking one pins it, unticking lets it go; and Add Source, which
  goes to the canvas and makes a source linked to the document, whose
  address can then be typed) and a button to dictate into
  it; below it, how many words it has; after the last, a button to add one. A page is a second view
  of the document the item's window on the canvas owns
  (`Items.Windows.Content_Document`), so what is typed in either is in
  both, and the canvas's window writes it (`Hold_Typing` says it is being
  typed in elsewhere, to write it once it has been left alone for a
  moment). The sidebar, at the left, has two scrolling lists: the
  documents (with buttons to add one, and a directory), as a tree:
  the Overview at the top, which cannot be moved; then directories (the
  `directories` table, and `directory_id` of `items`; `Items.Create_Directory`,
  `Load_Directories`, `Set_Directory`; at most `Items.Max_Directories`),
  each directly followed by its documents, inset (the box is narrower),
  and the documents in none, among them. The Overview and the directories
  are bare rows with a marker, not boxes; documents are boxes. The tree
  (`Item.Tree`) is the one order, and the pages' (`Sync_Order`): the
  `position` of a document or directory is its row (`Items.Set_Position`,
  `Set_Directory_Position`; those never put come last). A row's count is
  how many words a document has, or how many documents a directory. Any row
  but the Overview's is dragged, and where it would go is found from the
  pointer (`Target_At`): a document in the middle of a directory's or the
  Overview's row goes last in it (the Overview's: in none, last of all);
  or between rows, shown by a line over the gap (a panel out of the
  layout, so nothing moves): above or below another document (by the half
  of its row), before a directory (the top of its row), after one (the foot
  of its row if empty, else the lowest part of its last document's). A
  directory is dragged with its documents, to before or after another unit
  of the top level. A click on a document's row goes to
  its page; on a directory's, shows only its documents as the pages, and
  on the Overview's, all of them (a document added then is in the
  directory shown); a directory's row pressed twice is renamed, in a field
  over it. A press of the right button shows a menu (`Context_Menu`, a
  `Menus.Menu`, not the system's; `Open_Context`, `Do_Context`) on the
  canvas, over a window's text (a note's, a source's link) or a source's
  picture, with the same rows as below (`Items.Windows.Edit_Text`,
  `Select_All_Words`, `Copy_Words`; found by `Owns`, the window the widget
  under the pointer is in); and in the writing view on: a
  document's, directory's or source's row, a page's text (Paste, Select
  all; on the selection, Copy, Cut, Paste, Select all; Paste is faint if the clipboard
  is empty) or a source's picture (Select all; on the selected words, Copy
  too). For a row: Rename, which puts that field over the
  row (of a document or a source, editing its title, which the canvas's
  window has too), and Delete, which asks first in the dialog that
  confirms deleting a project (`Deleting_Node`; Escape or Cancel leaves
  it). A deleted directory's documents are kept, in none, where they
  were; and the sources, a row to click to open or close the source's
  window here. That window is an `Items.Readers.Reader`, not the item's window
  on the canvas: where it is, whether it is open, its zoom and scroll are
  of this view only and are not kept; the picture and the words found in it
  are the same files and rows, and the highlights are shared:
  `Writing.Update` makes those of the reader and of the window on the canvas
  the same, whichever was marked, and keeps them in the database. A source's
  window has a pin button, which puts it in the pane at the right (a
  `Reader` that fills it; one at a time, with an edge to size it by) in
  place of its window.
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