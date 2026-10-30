with Harper;
with Naming_VM;
with Writing_VM.Trees;
with Texts.Documents;
with Slot_Tables;
with Pomarine.Widgets;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets.Panels;

--  The tree of documents, the lists of rows beside the pages, and the menu, renaming and drag of them.

package View_Parts.Rows is

   subtype Tree_Row is Positive;
   --  A row of the tree of documents: the Overview, every directory, and
   --  every document.

   subtype Tree_Kinds is Writing_VM.Trees.Tree_Kinds;
   Overview_Node  : constant Tree_Kinds := Writing_VM.Trees.Overview_Node;
   Directory_Node : constant Tree_Kinds := Writing_VM.Trees.Directory_Node;
   Document_Leaf  : constant Tree_Kinds := Writing_VM.Trees.Document_Leaf;
   subtype Tree_Entry is Writing_VM.Trees.Tree_Entry;
   subtype Tree_Entry_Array is Writing_VM.Trees.Tree_Entry_Array;

   type Drop_Kinds is (No_Drop, Into_Node, Between);
   --  Where a row dragged would go: nowhere, into the Overview or a
   --  directory (the row of the tree under the pointer), or between two
   --  rows of the tree.

   type Drop_Target is record
      Kind  : Drop_Kinds := No_Drop;
      Row   : Natural := 0;
      --  Of Into_Node: the row dropped on.
      Index : Natural := 0;
      --  Of Between: the row it would be put before (one past the last
      --  if it goes last).
      Dir   : Natural := 0;
      --  Of Between: the directory it would be in, 0 if none.
   end record;

   type Context_Kinds is (No_Context, Tree_Context, Text_Context, Picture_Context);
   --  What the menu shown at a right click is of: a row (of the tree, or a
   --  source), the text of a page, or a source's picture.

   type Context_Acts is
     (No_Act,
      Add_Document_Act,
      Add_Folder_Act,
      Rename_Act,
      Delete_Act,
      Copy_Act,
      Cut_Act,
      Paste_Act,
      Select_All_Act,
      Thesaurus_Act,
      Synonym_Act);
   --  What a row of it does. Thesaurus_Act shows the synonyms of the word selected in the same menu, as
   --  rows of Synonym_Act, each of which rewords the word.

   Synonym_Rows : constant := 10;
   --  How many synonyms the menu offers (the most used); a heading goes before them.

   type Act_Array is array (1 .. Synonym_Rows + 1) of Context_Acts;

   type Index_Row is limited record
      Row         : Pomarine.Widgets.Grips.Grip;
      --  Clicked to go to the document, or to open the source; dragged to
      --  put a document elsewhere in the order.
      Tag         : Pomarine.Widgets.Panels.Panel;
      --  Of a source: a square of its colour.
      Folder_Mark : Pomarine.Widgets.Labels.Label;
      Caption     : Pomarine.Widgets.Labels.Label;
      Count       : Pomarine.Widgets.Labels.Label;
      --  Of a document: how many words it has; of a directory, how many
      --  documents.
      Indent      : Float := 0.0;
      --  How far in, in points, it has been put.
   end record;
   --  A row of a list in the writing view's sidebar.

   package Index_Row_Tables is new Slot_Tables (Index_Row);
   subtype Index_Row_Array is Index_Row_Tables.Table;

   subtype Tree_Row_Array is Index_Row_Tables.Table;

   type Context_State is limited record
      Context_Menu   : Pomarine.Widgets.Menus.Menu;
      Context_Kind   : Context_Kinds := No_Context;
      Context_Node   : Tree_Entry;
      --  A document or directory, or a source (a leaf, of the slot of its
      --  window).
      Context_Page   : Natural := 0;
      --  Of Text_Context: the page.
      Context_Canvas : Natural := 0;
      --  Of Text_Context and Picture_Context: the window on the canvas the
      --  menu is of, if it is of one, not of a page or a reader.
      Context_Reader : Natural := 0;
      --  Of Picture_Context: the window of the source whose reader, or 0
      --  if the pinned one.
      Context_X      : Float := 0.0;
      Context_Y      : Float := 0.0;
      --  Where it was asked for, in points of the window.
      Context_Words  : Harper.Synonym_List;
      --  Of Thesaurus_Act: the synonyms shown, row 2 on being the first.
      Context_Acts   : Act_Array := [others => No_Act];
      --  Over the writing view, hidden until the right button is pressed
      --  on a row of the sidebar, a page's text or a source's picture;
      --  what it is of, and what each of its rows does.
   end record;
   --  The menu at a right click.

   type Renaming_State is limited record
      Dir_Field    : Pomarine.Widgets.Text_Fields.Text_Field;
      Dir_Doc      : aliased Texts.Documents.Document;
      Source_Field : Pomarine.Widgets.Text_Fields.Text_Field;
      Names        : Naming_VM.Model;
      --  The directory, the document or the source being renamed, if any, in the field over its row (of
      --  Source_Field, for a source).
   end record;
   --  The fields over a row being renamed.

   type Drag_State is limited record
      Drag_Row      : Natural := 0;
      Drag_Total    : Float := 0.0;
      Drag_Moved    : Boolean := False;
      Drag_From_X   : Float := 0.0;
      --  Where across the row was pressed, in points of the window.
      --  The row of the list of documents being dragged, how far, and the
      --  order when it was pressed.
      Dropped_Moved : Boolean := False;
      --  Whether the row last let go had been dragged, so that it is not
      --  clicked as well.
   end record;
   --  The row of the list of documents being dragged.

end View_Parts.Rows;
