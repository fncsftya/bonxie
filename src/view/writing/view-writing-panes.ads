with Items.Readers;
--  What the sidebar, the edges, the page titles and the readers say.

private package View.Writing.Panes is

   package Widgets renames Pomarine.Widgets;
   package Readers renames Items.Readers;

   procedure Row_Clicked (Item : in out Session; Row : Positive);
   --  A row of the tree was clicked, and was not dragged.

   procedure Row_Double_Clicked (Item : in out Session; Row : Positive);
   --  A directory's row was pressed twice: rename it.

   procedure Directory_Field_Ended (Item : in out Session);
   --  Return in the field of a directory's or a document's name, or it
   --  lost the focus: the renaming is over.

   procedure Source_Field_Ended (Item : in out Session);

   procedure Sidebar_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The edge of the list of documents was dragged: size it.

   procedure Sidebar_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The edge was let go: keep how wide the list is.

   procedure Fit_Sections (Item : in out Session);
   --  Show each section of the sidebar open or folded, and its head to say so.

   procedure Sources_Edge_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The edge above the sources list was dragged: size the list.

   procedure Pane_Dragged (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The edge of the pane was dragged: size it.

   procedure Page_Title_Double_Clicked (Item : in out Session; Rank : Positive);
   --  The title of the page of this rank was pressed twice: rename it.

   procedure Page_Title_Ended (Item : in out Session; Rank : Positive);
   --  Return in the page's title field, or it lost the focus.

   procedure Reader_Asked (Item : in out Session; Which : Natural; Action : Readers.Actions);
   --  What a button of a source's window here, or of the pane, asked for:
   --  Which is 0 for the pane's.

end View.Writing.Panes;
