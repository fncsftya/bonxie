with Items.Directories;
with Growing;
with Slot_Tables;
with Items.Readers.Tables;
with Texts.Documents;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Switches;
with Viewer_Parts.Common;
with Viewer_Parts.Rows;

--  The writing view: its pages, its sections, the sources read in it and the publish view.
package Viewer_Parts.Pages is

   type Doc_Page is limited record
      Box     : Pomarine.Widgets.Panels.Panel;
      --  A column: the bar above, and the page.
      Bar     : Pomarine.Widgets.Panels.Panel;
      Heading_Area : Pomarine.Widgets.Grips.Grip;
      Heading : Pomarine.Widgets.Labels.Label;
      --  The title, in a grip that takes a double press to rename it.
      Title_Field : Pomarine.Widgets.Text_Fields.Text_Field;
      --  In its place while it is renamed, on the title of the window.
      Renaming : Boolean := False;
      Sources_Button : Pomarine.Widgets.Buttons.Button;
      --  A dropdown: opens the menu of the sources the document is
      --  linked to, and shows how many.
      Mic_Button : Pomarine.Widgets.Buttons.Button;
      --  Starts and stops dictating into the document.
      Level : Pomarine.Widgets.Progress_Bars.Progress_Bar;
      --  Along the foot of the bar while dictating: how loud the sound
      --  heard is.
      Outline_Button : Pomarine.Widgets.Buttons.Button;
      --  A dropdown: opens the menu of the outline's sections, to make
      --  the document the one a section is read from.
      Swatch  : Pomarine.Widgets.Panels.Panel;
      --  Before the title: the colour of the section the document is the
      --  own of, if it is.
      Swatch_Shown : Natural := 0;
      --  How it was last shown: 0 for none, else 1 and the colour.
      Sheet   : Pomarine.Widgets.Panels.Panel;
      --  The white page.
      Text    : Pomarine.Widgets.Editors.Editor;
      --  The text of a document, which its window on the canvas has too.
      Words   : Pomarine.Widgets.Labels.Label;
      --  Below the page, at the right: how many words it has.
      Bound   : Natural := 0;
      --  The window it shows, 0 if none.
      Wide, High : Float := 0.0;
      --  The width of the sheet and the height of the text, in points, as
      --  last set.
      Caret_For  : Texts.Position := (1, 1);
      Caret_Seen : Texts.Documents.Version := 0;
      --  Where the caret was, in what version of the document, when last
      --  brought into view.
   end record;

   package Page_Tables is new Slot_Tables (Doc_Page);
   subtype Page_Array is Page_Tables.Table;

   type Publish_Parts is limited record
      Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      High    : Float := 0.0;
      Content : Pomarine.Widgets.Panels.Panel;
      Wide    : Float := 760.0;
      Left    : Float := 0.0;
      View    : Pomarine.Widgets.Panels.Panel;
      Sidebar : Pomarine.Widgets.Panels.Panel;
      Rule    : Pomarine.Widgets.Panels.Panel;
      Section_Headings : Pomarine.Widgets.Switches.Switch;
      Document_Headings : Pomarine.Widgets.Switches.Switch;
      Export  : Pomarine.Widgets.Buttons.Button;
      Doc     : aliased Texts.Documents.Document;
      Text    : Pomarine.Widgets.Editors.Editor;
   end record;

   type Fold_Head is limited record
      Bar  : Pomarine.Widgets.Grips.Grip;
      Mark : Pomarine.Widgets.Labels.Label;
      Name : Pomarine.Widgets.Labels.Label;
   end record;
   --  The head of a section of the sidebar, which folds it: its chevron and name, in a bar
   --  that is clicked.

   type Page_Parts is limited record
      Write_View    : Pomarine.Widgets.Panels.Panel;
      --  A row, in the content area in the canvas's place when Mode is
      --  Write: the sidebar, the pages, and the pane of the pinned source;
      --  and the windows of the sources, over them.
      Sidebar       : Pomarine.Widgets.Panels.Panel;
      Edit_Heading  : Fold_Head;
      --  The head of the Edit section, above the grammar suggestions.
      Edit_Open     : Boolean := True;
      Docs_Open     : Boolean := True;
      Sources_Open  : Boolean := True;
      --  Whether each section of the sidebar is open; the heads fold them.
      Grammar_Row   : Pomarine.Widgets.Panels.Panel;
      Grammar_Switch : Pomarine.Widgets.Switches.Switch;
      Grammar_Count : Pomarine.Widgets.Buttons.Button;
      Sidebar_Edge  : Pomarine.Widgets.Grips.Grip;
      --  At the sidebar's right, to size it by.
      Sidebar_Wide  : Float := 206.0;
      --  How wide it is, in points: kept with the settings.
      Sidebar_Rule  : Pomarine.Widgets.Panels.Panel;
      --  The line at its right.
      Docs_Head     : Pomarine.Widgets.Panels.Panel;
      Docs_Heading  : Fold_Head;
      Docs_Add      : Pomarine.Widgets.Buttons.Button;
      Docs_Folder   : Pomarine.Widgets.Buttons.Button;
      --  Beside the name of the list: add a document, and a directory.
      Docs_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Docs_Content  : Pomarine.Widgets.Panels.Panel;
      Docs_None     : Pomarine.Widgets.Labels.Label;
      Sources_Edge  : Pomarine.Widgets.Grips.Grip;
      --  Between the lists, to size the sources list by.
      Sources_Grab  : Pomarine.Widgets.Panels.Panel;
      Sources_Heading : Fold_Head;
      Sources_Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      Sources_Content : Pomarine.Widgets.Panels.Panel;
      Sources_None  : Pomarine.Widgets.Labels.Label;
      --  The two lists of the sidebar: of the documents, in the order they
      --  are written in, and of the sources.
      Pages_Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      Pages_Content : Pomarine.Widgets.Panels.Panel;
      --  The pages, one above the next, scrolled together.
      Pane          : Pomarine.Widgets.Panels.Panel;
      Pane_Edge     : Pomarine.Widgets.Grips.Grip;
      Pane_Body     : Pomarine.Widgets.Panels.Panel;
      --  At the right, the full height of the view, shown while a source
      --  is pinned; the edge is dragged to size it.
      Menu          : Pomarine.Widgets.Menus.Menu;
      --  Over the pages, hidden until a document's Sources button is
      --  clicked: a heading, a box for each source the document is linked
      --  to, ticked if it is the one pinned (or a note that there are
      --  none), a line, and Add Source.
      Menu_Page     : Natural := 0;
      --  The page the menu is of, 0 if it is not shown.
      Menu_Slots    : Common.Slot_Array;
      Menu_Count    : Natural := 0;
      --  The windows of the sources the boxes are of, from the second
      --  row.
      Menu_Left, Menu_Top : Float := -1.0E9;
      --  Where it was last put, in points of the writing view.
      Pane_Wide     : Float := 0.0;
      --  How wide, in points.
   end record;
   --  The writing view: the sidebar, the pages, the pane of the pinned source
   --  and the menu of a page.

   type Document_State is limited record
      Pages        : Page_Array;
      --  The pages of the writing view: after Windows, whose documents
      --  they show.
      Doc_Rows     : Rows.Tree_Row_Array;
      Tree         : Rows.Tree_Entry_Array;
      Tree_Count   : Natural := 0;
      --  The rows of the documents' tree, from the top: the Overview,
      --  then each directory directly followed by its documents, and
      --  the documents in none among them. What each is of.
      Dirs         : Items.Directories.Directory_List;
      Doc_Dir      : Common.Dir_Array;
      --  The directories, and which of them each document's window is in,
      --  0 if none. Tree is the order of it all.
      Shown_Dir    : Natural := 0;
      --  The directory whose documents are the pages, 0 for the Overview:
      --  all of them.
      Drop         : Rows.Drop_Target;
      --  Where the document being dragged would go.
      Drop_Line    : Pomarine.Widgets.Panels.Panel;
      --  The line between two rows where it would go between documents,
      --  over the rows and out of the way of their layout.
      Ghost        : Pomarine.Widgets.Panels.Panel;
      Ghost_Title  : Pomarine.Widgets.Labels.Label;
      --  Over the rows, under the pointer while one is dragged: a box of
      --  its name.
   end record;

   type Section_Head is limited record
      Row   : Pomarine.Widgets.Panels.Panel;
      Bar   : Pomarine.Widgets.Panels.Panel;
      --  The section's colour, a bar before its title.
      Title : Pomarine.Widgets.Labels.Label;
      Count : Pomarine.Widgets.Labels.Label;
      --  At the right: how many documents it has.
      Notes : Pomarine.Widgets.Buttons.Button;
      --  Before the Add button: shows the section's notes under the
      --  heading, or puts them away.
      Add   : Pomarine.Widgets.Buttons.Button;
      --  Beside it, while it has some: writes another, last in the section.
   end record;
   --  The heading of a section among the pages of the writing view.

   type Note_Box is limited record
      Box  : Pomarine.Widgets.Panels.Panel;
      --  A tinted box with the section's colour round it, not a white
      --  page, after the heading and before the documents.
      Text : Pomarine.Widgets.Editors.Editor;
      --  The section's notes, which its block of the outline shows too.
      High : Float := 0.0;
      --  How tall the text is, in points, as last put.
   end record;

   type Section_Empty is limited record
      Box  : Pomarine.Widgets.Panels.Panel;
      Note : Pomarine.Widgets.Labels.Label;
      Add  : Pomarine.Widgets.Buttons.Button;
   end record;
   --  Where a section has no documents, in the place of them: the button
   --  to write one for it.

   type Gap_Mark is limited record
      Row     : Pomarine.Widgets.Panels.Panel;
      Caption : Pomarine.Widgets.Labels.Label;
      Rule    : Pomarine.Widgets.Panels.Panel;
   end record;
   --  Before the documents that are of no section, between those of two
   --  (or before the first, or after the last): a faint line that says so.

   package Head_Tables is new Slot_Tables (Section_Head);
   subtype Section_Heads is Head_Tables.Table;

   package Note_Tables is new Slot_Tables (Note_Box);
   subtype Note_Boxes is Note_Tables.Table;

   package Empty_Tables is new Slot_Tables (Section_Empty);
   subtype Section_Empties is Empty_Tables.Table;

   package Gap_Tables is new Slot_Tables (Gap_Mark);
   subtype Gap_Marks is Gap_Tables.Table;
   --  One more than there are sections: the first is before the first section.

   type Plan_Kinds is (Head_Entry, Notes_Entry, Empty_Entry, Page_Entry, Gap_Entry);

   type Plan_Entry is record
      Kind  : Plan_Kinds := Head_Entry;
      Index : Natural := 0;
      --  A section (Head_Entry, Notes_Entry, Empty_Entry), a page's rank (Page_Entry),
      --  or the section the loose documents come after (Gap_Entry, 0 for
      --  before the first).
      Top   : Float := 0.0;
      --  Where it is, in pixels, from the first.
   end record;

   package Plan_Lists is new Growing (Plan_Entry);
   subtype Plan_Array is Plan_Lists.List;

   type Section_View_Parts is limited record
      Heads   : Section_Heads;
      Empties : Section_Empties;
      Notes   : Note_Boxes;
      Gaps    : Gap_Marks;
      Tail    : Pomarine.Widgets.Panels.Panel;
      --  Last among the pages, flowing, as tall as they all are together
      --  while they are put by their edges (Grouped): it gives the view
      --  its height, and its corner is where their places are from.
      Grouped : Boolean := False;
      --  Whether the pages are in the sections, each by its edges, and not
      --  one below the next.
      Plan    : Plan_Array;
      Plan_Count : Natural := 0;
      Plan_Wide  : Float := 0.0;
      Plan_Left  : Float := 0.0;
      --  The width the planned parts were given.
      --  What is shown, in order, and where, as last put.
      Pending : Natural := 0;
      --  The section that the document being made is to be of, 0 if none.
   end record;
   --  The sections among the pages of the writing view, each a heading
   --  and the documents that are of it (or the button to make one), with
   --  those of none between them.

   type Reading_State is limited record
      Source_Rows  : Rows.Index_Row_Array;
      Readers      : Items.Readers.Tables.Table;
      --  The windows of the sources in the writing view, of the same
      --  slots as Windows.
      Pane_Reader  : Items.Readers.Reader;
      --  The pinned source, in the pane.
      Reader_Sync  : Common.Sync_Array;
      Pane_Sync    : Common.Sync_State;
      Reader_Placed : Common.Placed_Array;
      --  Whether a reader has been given a place yet.
      Write_Order  : Common.Slot_Array;
      Write_Count  : Natural := 0;
      --  The windows of the documents, in the order they are written in.
      Source_Order : Common.Slot_Array;
      Source_Total : Natural := 0;
      --  The windows of the sources, the earliest made first.
      Pinned_Slot  : Natural := 0;
      --  The window of the source in the pane, 0 if none.
   end record;
   --  The sources in the writing view, and the orders of the windows of
   --  documents and of sources.

end Viewer_Parts.Pages;
