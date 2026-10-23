with Pomarine.Widgets;
with Vision;

--  The writing view: the items that are not sources, as documents, each
--  on a white page, one after another; beside them a list of the
--  documents, to put in another order, and of the sources, to open and
--  close; and the sources' windows over them, one of which may be pinned
--  in a pane at the right.
--
--  A page shows the text of an item's window on the canvas, which writes
--  it: what is typed in either is in both. A source's window here is not
--  its window on the canvas (see Items.Readers), but its highlights are
--  the same.
private package Viewer.Writing is

   procedure Enter (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Make the lists, pages and windows of the items there are: once the
   --  canvas's windows are made.

   procedure Fit_Sidebar (Item : in out Session);
   --  Show the sections of the sidebar open or folded, as they are kept.

   procedure Dismiss_Context (Item : in out Session);
   --  Dismiss the right click menu without changing the editor focus.

   procedure Leave (Item : in out Session);
   --  Let go of the windows, and the pinned source.

   procedure Show (Item : in out Session; To : Modes)
     with Pre => Screen (Item) = Project;
   --  Show the view, in place of the one shown, and keep it as the
   --  project's.

   procedure Restore (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Show the view the project was last left at, Outline if none: once
   --  the project is entered.

   procedure Added (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The item has been made: list it, and give it a page or a window.

   procedure Removed (Item : in out Session; Which : Items.Slot);
   --  The item is to be taken out of the lists, and its page or windows
   --  let go. Call it before its window is released.

   procedure Picture_Taken (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The source's picture is a new one: show it in its windows here too.

   procedure Page_Turned (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The page being read of the source's document, shown as pages one
   --  under another, has changed: say which in its windows here too.

   procedure Words_Found
     (Item : in out Session; Which : Items.Slot; Found : Vision.Result);
   --  The words in the source's picture have been found.

   procedure Move (Item : in out Session; From, To : Positive)
     with Pre => From <= Item.Reading.Write_Count
      and then To <= Item.Reading.Write_Count;
   --  Put the From-th page at the To-th, and keep the order.

   procedure Move_To_Directory
     (Item : in out Session; Rank : Positive; Directory : Natural)
     with Pre => Rank <= Item.Reading.Write_Count
                 and then Directory <= Item.Docs.Dirs.Count;
   --  Put the Rankth page last in the directory (none, if 0), and keep it.

   procedure Open_Context
     (Item : in out Session; X, Y : Float; Opened : out Boolean)
     with Pre => Screen (Item) = Project;
   --  The right button was pressed at X, Y, in points of the window: show
   --  the menu of what is there, if it has one: in the writing view, a row
   --  of the sidebar, a page's text or a source's window; on the canvas,
   --  the text or the picture of a window.

   --  What the writing view's widgets say (see Viewer.Responses, which
   --  gives them to the widgets):

   procedure Add_Page_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  Add a document.

   procedure Add_Folder_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  Add a directory.

   procedure Source_Chosen
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A row of the menu of a page's sources: pin or let go of the source,
   --  or add one.

   procedure Context_Chosen
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A row of the context menu.

   procedure Add_For_Section (Item : in out Session; Section : Positive);
   --  Write a document that is of the section, last among the documents.

   procedure Section_Notes_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  The Notes button of a section's heading (Event.Index its place in
   --  the outline): show its notes under it, or put them away.

   procedure Section_Add_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  The button of a section that has no documents: write one, of it.

   procedure Sources_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A page's Sources button: its Index is the page's rank.

   procedure Dictate_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A page's microphone button: its Index is the page's rank.

   procedure Find_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A page's Find Sources button: its Index is the page's rank.

   procedure Tool_Used
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A tool of a page's toolbar (Word_Tools): its Row is the tool's number.

   procedure Link_Followed
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A link of a page's text Command-clicked: it is opened (Word_Tools.Follow).

   procedure Link_Asked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A page's text has begun to ask for a link's address: it is offered the web pages among the
   --  project's sources.

   procedure Source_Row_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A row of the sources' list: its Index is the row.

   procedure Delete_Node
     (Item : in out Session; Node : Tree_Entry; Delete_Documents : Boolean := False)
     with Pre => Screen (Item) = Project
                 and then Node.Kind /= Overview_Node;
   --  Delete a document or a folder subtree. Keep its documents at the top
   --  level unless Delete_Documents is selected.

   procedure Make_Directory (Item : in out Session; Name : String);
   --  Make a directory, put its row last of the directories, and begin to
   --  rename it.

   procedure Select_Directory (Item : in out Session; Directory : Natural)
     with Pre => Directory <= Item.Docs.Dirs.Count;
   --  Show only the pages of the directory (all, if 0).

   procedure Listen (Item : in out Session);
   --  Give the writing view's widgets, and the windows of the sources in
   --  it, the procedures they call when they are clicked, dragged or have
   --  their say: once they are built.

   procedure Listen_Row (Item : in out Session; Row : Positive);
   --  Give a row of the tree of documents the procedures it calls.

   procedure Listen_Slot (Item : in out Session; Rank : Items.Slot);
   --  Give the page and the reader of the slot the procedures they call.

   procedure Pressed (Item : in out Session; X, Y : Float)
     with Pre => Screen (Item) = Project;
   --  The pointer was pressed at X, Y, in points of the window: the
   --  highlighter of a source's window here is put away if that is
   --  outside it.

   procedure Update (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Keep the titles, the highlights and the text being typed in step
   --  with the canvas's windows.

   procedure Fit (Item : in out Session)
     with Pre => Screen (Item) = Project and then Item.Toolbar.Mode in Write | Publish;
   --  Size the pages to their text and the window, once it is laid out,
   --  and bring the caret into view.

end Viewer.Writing;
