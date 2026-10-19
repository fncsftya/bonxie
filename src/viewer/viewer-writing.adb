with Items.Links;
with Items.Marks;
with Items.Readers.Callbacks;
with Items.Sources;
with Items.Words;
with Pomarine.Boxes;
with Pomarine.Themes;
with Ada.Strings.Fixed;
with Texts.Documents;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pictures;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Text_Fields;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Gestures;
with Viewer.Outlines;
with Viewer.Section_Links;
with Viewer.Style;
with Viewer.Grammar;
with Pomarine.Widgets.Layouts;

package body Viewer.Writing is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Editors renames Pomarine.Widgets.Editors;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Menus renames Pomarine.Widgets.Menus;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Readers renames Items.Readers;
   package Windows renames Items.Windows;
   package Docs renames Texts.Documents;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);
   package Reader_Events is new Items.Readers.Callbacks (Session);

   use type Items.Id;
   use type Projects.Id;
   use type Widgets.Clipboard_Access;
   use type Items.Kinds;
   use type Items.States;
   use type Docs.Version;
   use type Texts.Position;
   use type Pictures.Tools;
   use type Windows.Dictations;

   Untitled_Directory : constant String := "Untitled folder";

   Drag_Threshold : constant Float := 4.0;
   --  How far, in points, a press on a row has to go to be a drag.

   Reveal_Margin : constant Float := 48.0;
   --  How close to the edge of the view, in points, the caret may be
   --  before the pages are scrolled.

   --  The items

   function Is_Note (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Note);

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Source);

   function Is_Section (Item : Session; Dir : Natural) return Boolean is
     (Dir /= 0 and then Item.Docs.Dirs.Directories (Dir).Section /= 0);
   --  Whether the directory is a section's: made for it, with its name,
   --  not renamed or deleted here, nor moved.

   function Title_Of (Item : Session; Which : Items.Slot) return String is
     (Projects.Titles.To_String
        (Windows.Details (Item.Windows (Which)).Title));

   function Rank_Of (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Rank in 1 .. Item.Reading.Write_Count loop
         if Item.Reading.Write_Order (Rank) = Which then
            return Rank;
         end if;
      end loop;
      return 0;
   end Rank_Of;
   --  Where the document is among the pages, 0 if it is not one.

   function Row_Of (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Row in 1 .. Item.Reading.Source_Total loop
         if Item.Reading.Source_Order (Row) = Which then
            return Row;
         end if;
      end loop;
      return 0;
   end Row_Of;
   --  Where the source is in the list of them, 0 if it is not.

   function In_View (Item : Session; Which : Items.Slot) return Boolean is
     (Item.Docs.Shown_Dir = 0
      or else Item.Docs.Doc_Dir (Which) = Item.Docs.Shown_Dir);
   --  Whether the document's page is one shown.

   function Leaf_Row (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Row in 1 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Kind = Document_Leaf
           and then Item.Docs.Tree (Row).Doc = Which
         then
            return Row;
         end if;
      end loop;
      return 0;
   end Leaf_Row;
   --  Where the document is in the tree, 0 if it is not.

   function Dir_Row (Item : Session; Dir : Positive) return Natural is
   begin
      for Row in 1 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Kind = Directory_Node
           and then Item.Docs.Tree (Row).Dir = Dir
         then
            return Row;
         end if;
      end loop;
      return 0;
   end Dir_Row;
   --  Where the directory is in the tree, 0 if it is not.

   function Documents_In (Item : Session; Dir : Positive) return Natural is
      Total : Natural := 0;
   begin
      for Rank in 1 .. Item.Reading.Write_Count loop
         if Item.Docs.Doc_Dir (Item.Reading.Write_Order (Rank)) = Dir then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Documents_In;

   procedure Sync_Order (Item : in out Session);
   --  Take the documents' order from the tree, which is the pages'.

   procedure Sync_Order (Item : in out Session) is
   begin
      Item.Reading.Write_Count := 0;
      for Row in 2 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Kind = Document_Leaf then
            Item.Reading.Write_Count := Item.Reading.Write_Count + 1;
            Item.Reading.Write_Order (Item.Reading.Write_Count)
               := Item.Docs.Tree (Row).Doc;
         end if;
      end loop;
   end Sync_Order;

   function Block_End (Item : Session; Row : Positive) return Positive;
   --  The last row of what is moved with the row: of a directory, the
   --  last of its documents, which follow it; else the row.

   function Block_End (Item : Session; Row : Positive) return Positive is
      Last : Positive := Row;
   begin
      if Item.Docs.Tree (Row).Kind = Directory_Node then
         while Last < Item.Docs.Tree_Count
           and then Item.Docs.Tree (Last + 1).Kind = Document_Leaf
           and then Item.Docs.Tree (Last + 1).Dir = Item.Docs.Tree (Row).Dir
         loop
            Last := Last + 1;
         end loop;
      end if;
      return Last;
   end Block_End;

   procedure Insert_Row
     (Item : in out Session; Index : Positive; Node : Tree_Entry)
     with Pre => Index in 2 .. Item.Docs.Tree_Count + 1
                 and then Item.Docs.Tree_Count < Tree_Capacity;
   --  Put the row before the Indexth.

   procedure Insert_Row
     (Item : in out Session; Index : Positive; Node : Tree_Entry) is
   begin
      for Row in reverse Index .. Item.Docs.Tree_Count loop
         Item.Docs.Tree (Row + 1) := Item.Docs.Tree (Row);
      end loop;
      Item.Docs.Tree (Index) := Node;
      Item.Docs.Tree_Count := Item.Docs.Tree_Count + 1;
   end Insert_Row;

   procedure Delete_Row (Item : in out Session; Index : Positive)
     with Pre => Index in 2 .. Item.Docs.Tree_Count;

   procedure Delete_Row (Item : in out Session; Index : Positive) is
   begin
      for Row in Index .. Item.Docs.Tree_Count - 1 loop
         Item.Docs.Tree (Row) := Item.Docs.Tree (Row + 1);
      end loop;
      Item.Docs.Tree_Count := Item.Docs.Tree_Count - 1;
   end Delete_Row;

   procedure Move_Block (Item : in out Session; From, Index : Positive)
     with Pre => From in 2 .. Item.Docs.Tree_Count
                 and then Index in 2 .. Item.Docs.Tree_Count + 1;
   --  Put the row, and those moved with it, before the Indexth (as it
   --  was before it was moved).

   procedure Move_Block (Item : in out Session; From, Index : Positive) is
      Last   : constant Positive := Block_End (Item, From);
      Length : constant Positive := Last - From + 1;
      Moved  : constant Tree_Entry_Array := Item.Docs.Tree;
      Place  : Positive := Index;
   begin
      if Index in From .. Last + 1 then
         return;
      end if;
      if Index > Last then
         Place := Index - Length;
      end if;
      for Each in reverse From .. Last loop
         Delete_Row (Item, From);
      end loop;
      for Each in 0 .. Length - 1 loop
         Insert_Row (Item, Place + Each, Moved (From + Each));
      end loop;
   end Move_Block;

   function Key_Of (Position : Natural) return Natural is
     (if Position = 0 then Natural'Last else Position);
   --  Never put comes after what was.

   procedure Arrange (Item : in out Session);
   --  Make the tree of the documents (as Write_Order and Doc_Dir have
   --  them, in the order kept) and the directories: each directory, and
   --  the documents in none, in the order kept, each directory's
   --  documents after it.

   procedure Arrange (Item : in out Session) is
      Count    : Natural := 1;
      Next_Doc : Positive := 1;
      Next_Dir : Positive := 1;
   begin
      Item.Docs.Tree (1) := (Kind => Overview_Node, others => 0);
      loop
         while Next_Doc <= Item.Reading.Write_Count
           and then Item.Docs.Doc_Dir (Item.Reading.Write_Order (Next_Doc))
              /= 0
         loop
            Next_Doc := Next_Doc + 1;
         end loop;
         exit when Next_Doc > Item.Reading.Write_Count
                   and then Next_Dir > Item.Docs.Dirs.Count;
         if Next_Dir <= Item.Docs.Dirs.Count
           and then
             (Next_Doc > Item.Reading.Write_Count
              or else Key_Of (Item.Docs.Dirs.Directories (Next_Dir).Position)
                      <= Key_Of
                           (Items.Directories.Position_Of
                              (Item.Nav.Store,
                               Windows.Details
                                 (Item.Windows
                                    (Item.Reading.Write_Order
                                       (Next_Doc))).Key)))
         then
            Count := Count + 1;
            Item.Docs.Tree (Count) :=
              (Kind => Directory_Node, Dir => Next_Dir, Doc => 0);
            for Rank in 1 .. Item.Reading.Write_Count loop
               if Item.Docs.Doc_Dir (Item.Reading.Write_Order (Rank))
                  = Next_Dir
               then
                  Count := Count + 1;
                  Item.Docs.Tree (Count) :=
                    (Kind => Document_Leaf, Dir => Next_Dir,
                     Doc  => Item.Reading.Write_Order (Rank));
               end if;
            end loop;
            Next_Dir := Next_Dir + 1;
         else
            Count := Count + 1;
            Item.Docs.Tree (Count) :=
              (Kind => Document_Leaf, Dir => 0,
               Doc  => Item.Reading.Write_Order (Next_Doc));
            Next_Doc := Next_Doc + 1;
         end if;
      end loop;
      Item.Docs.Tree_Count := Count;
      Sync_Order (Item);
   end Arrange;

   procedure Build_Order (Item : in out Session);
   --  Find the documents, in the order kept, and the sources.

   procedure Build_Order (Item : in out Session) is
      Ordered : Items.Id_List;
   begin
      Item.Reading.Write_Count := 0;
      Item.Reading.Source_Total := 0;
      Item.Docs.Shown_Dir := 0;
      Item.Docs.Doc_Dir := [others => 0];
      Items.Directories.Load_Directories
        (Item.Nav.Store, Item.Opened.Current, Item.Docs.Dirs);
      Items.Directories.Load_Order
        (Item.Nav.Store, Item.Opened.Current, Ordered);
      for Place in 1 .. Ordered.Count loop
         for Which in Items.Slot loop
            if Windows.Is_Assigned (Item.Windows (Which))
              and then Windows.Details (Item.Windows (Which)).Key
                       = Ordered.Keys (Place)
            then
               if Is_Note (Item, Which) then
                  declare
                     Inside : constant Items.Id :=
                       Items.Directories.Directory_Of (Item.Nav.Store,
                                           Ordered.Keys (Place));
                  begin
                     for Dir in 1 .. Item.Docs.Dirs.Count loop
                        if Item.Docs.Dirs.Directories (Dir).Key = Inside then
                           Item.Docs.Doc_Dir (Which) := Dir;
                        end if;
                     end loop;
                  end;
                  Item.Reading.Write_Count := Item.Reading.Write_Count + 1;
                  Item.Reading.Write_Order (Item.Reading.Write_Count) := Which;
               else
                  Item.Reading.Source_Total := Item.Reading.Source_Total + 1;
                  Item.Reading.Source_Order (Item.Reading.Source_Total)
                     := Which;
               end if;
            end if;
         end loop;
      end loop;
      Arrange (Item);
   end Build_Order;

   procedure Keep_Directory (Item : in out Session; Which : Items.Slot);
   --  Write the directory the document is in to the database.

   procedure Keep_Directory (Item : in out Session; Which : Items.Slot) is
      Dir : constant Natural := Item.Docs.Doc_Dir (Which);
   begin
      Items.Directories.Set_Directory
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key,
         (if Dir = 0 then 0 else Item.Docs.Dirs.Directories (Dir).Key));
   end Keep_Directory;

   procedure Keep_Order (Item : in out Session);
   --  Write the order of the documents to the database.

   procedure Keep_Order (Item : in out Session) is
   begin
      --  A row's place is its number in the tree, directories and
      --  documents together.
      for Row in 2 .. Item.Docs.Tree_Count loop
         case Item.Docs.Tree (Row).Kind is
            when Directory_Node =>
               Items.Directories.Set_Directory_Position
                 (Item.Nav.Store,
                  Item.Docs.Dirs.Directories (Item.Docs.Tree (Row).Dir).Key,
                     Row);
            when Document_Leaf =>
               Items.Directories.Set_Position
                 (Item.Nav.Store,
                  Windows.Details
                    (Item.Windows (Item.Docs.Tree (Row).Doc)).Key,
                  Row);
            when Overview_Node =>
               null;
         end case;
      end loop;
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Keep_Order;

   --  What is shown

   procedure Choose_Row (Row : in out Index_Row; Chosen : Boolean);
   --  Show the row as the one chosen, white and casting a shadow, or not.

   procedure Choose_Row (Row : in out Index_Row; Chosen : Boolean) is
   begin
      Labels.Set_Style
        (Row.Caption,
         (if Chosen then Pomarine.Line_Texts.Strong else Pomarine.Line_Texts.Regular));
      if Chosen then
         Grips.Set_Fill (Row.Row, Style.Row_Open);
         Grips.Set_Hover_Fill (Row.Row, Style.Row_Open);
         Grips.Set_Shadow (Row.Row, Pomarine.Themes.Shadow);
      else
         --  Its shadow is the ground: unseen, but the face is the same
         --  size.
         Grips.Set_Fill (Row.Row, Style.Row_Fill);
         Grips.Set_Hover_Fill (Row.Row, Style.Row_Hover);
         Grips.Set_Shadow (Row.Row, Style.Side_Fill);
      end if;
   end Choose_Row;

   function Count_Image (Number : Natural) return String is
     (Ada.Strings.Fixed.Trim (Number'Image, Ada.Strings.Both));

   function Linked_Sources
     (Item : Session; Which : Items.Slot) return Natural;
   --  How many sources the document is linked to on the canvas.

   function Linked_Sources
     (Item : Session; Which : Items.Slot) return Natural
   is
      Key   : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
      Total : Natural := 0;
   begin
      for Row in 1 .. Item.Reading.Source_Total loop
         declare
            Other : constant Items.Id :=
              Windows.Details
                (Item.Windows (Item.Reading.Source_Order (Row))).Key;
         begin
            for Each of Item.Linking.Link_Set.Links
                          (1 .. Item.Linking.Link_Set.Count)
            loop
               if (Each.From = Key and then Each.To = Other)
                 or else (Each.From = Other and then Each.To = Key)
               then
                  Total := Total + 1;
                  exit;
               end if;
            end loop;
         end;
      end loop;
      return Total;
   end Linked_Sources;

   procedure Show_Tree_Row (Item : in out Session; Row : Tree_Row);
   --  Show the row of the tree as what it is of: its name, its count, how
   --  far in it is, and whether it is the one chosen or dropped on.

   procedure Show_Tree_Row (Item : in out Session; Row : Tree_Row) is
      Each    : Index_Row renames Item.Docs.Doc_Rows (Row);
      Node    : Tree_Entry renames Item.Docs.Tree (Row);
      Dropped : constant Boolean :=
        Item.Docs.Drop.Kind = Into_Node and then Item.Docs.Drop.Row = Row;
      --  While a document is dragged, the nodes it can be dropped on show.
      Hinted  : constant Boolean :=
        Item.Dragging.Drag_Row /= 0 and then Item.Dragging.Drag_Moved
        and then Item.Docs.Tree (Item.Dragging.Drag_Row).Kind = Document_Leaf;
      Chosen  : Boolean;
      Level   : Float := 0.0;
   begin
      case Node.Kind is
         when Overview_Node =>
            Labels.Set_Text (Each.Caption, "Overview");
            Labels.Set_Text (Each.Count,
                             Count_Image (Item.Reading.Write_Count));
            Chosen := Item.Docs.Shown_Dir = 0;
         when Directory_Node =>
            Labels.Set_Text
              (Each.Caption,
               Labels.Fitted (Projects.Titles.To_String
                         (Item.Docs.Dirs.Directories (Node.Dir).Title)));
            Labels.Set_Text
              (Each.Count, Count_Image (Documents_In (Item, Node.Dir)));
            Chosen := Item.Docs.Shown_Dir = Node.Dir;
         when Document_Leaf =>
            Labels.Set_Text (Each.Caption, Labels.Fitted (Title_Of (Item, Node.Doc)));
            Labels.Set_Text
              (Each.Count,
               Count_Image (Windows.Words (Item.Windows (Node.Doc))));
            if Node.Dir /= 0 then
               Level := Style.Tree_Indent;
            end if;
            Chosen :=
              (if Item.Dragging.Drag_Row /= 0 and then Item.Dragging.Drag_Moved
               then Row = Item.Dragging.Drag_Row
               else Widgets.Has_Focus
                      (Item.Docs.Pages (Rank_Of (Item, Node.Doc)).Text));
      end case;
      if Node.Kind = Overview_Node then
         --  Neither a section, a directory nor a document: a band of its
         --  own, with a rule in the accent colour, lit when it is shown.
         Widgets.Set_Visible (Each.Tag, False);
         Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Strong);
         Grips.Set_Fill (Each.Row, (if Chosen then Pomarine.Themes.Selection else Pomarine.Themes.Tint));
         Grips.Set_Hover_Fill (Each.Row, Pomarine.Themes.Selection);
         Grips.Clear_Shadow (Each.Row);
         Grips.Set_Border
           (Each.Row, (if Chosen then Pomarine.Themes.Accent else Pomarine.Themes.Border));
      elsif Node.Kind = Document_Leaf then
         --  A box, standing up.
         Choose_Row (Each, Chosen);
         Grips.Set_Border (Each.Row, Pomarine.Themes.Border);
         --  Its colour is the section's, on the section's row.
         Widgets.Set_Visible (Each.Tag, False);
      else
         --  Not a box: bare, with a marker, in bold; the marker is lit
         --  when it is the one shown, and the row is outlined while a
         --  document is over it.
         Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Strong);
         Grips.Clear_Fill (Each.Row);
         Grips.Set_Hover_Fill (Each.Row, Style.Row_Hover);
         Grips.Clear_Shadow (Each.Row);
         if Dropped then
            Grips.Set_Border (Each.Row, Pomarine.Themes.Focus);
         elsif Hinted then
            Grips.Set_Border (Each.Row, Pomarine.Themes.Border, Dashed => True);
         else
            Grips.Clear_Border (Each.Row);
         end if;
         Pomarine.Widgets.Panels.Set_Fill
           (Each.Tag,
            (if Is_Section (Item, Node.Dir)
             then Style.Section_Ink
                    (Projects.Sections.Colour_Index
                       (Item.Docs.Dirs.Directories (Node.Dir).Colour mod Projects.Sections.Palette_Size))
             elsif Chosen then Pomarine.Themes.Accent else Style.Quiet_Ink));
         Widgets.Set_Visible (Each.Tag, True);
      end if;
      if Level /= Each.Indent then
         --  Shrinks the box, not only its text.
         Each.Indent := Level;
         Layouts.Set_Layout (Each.Row, Margin => (Left => Level, others => <>));
      end if;
   end Show_Tree_Row;

   procedure Refresh (Item : in out Session);
   --  Show the pages and the rows of the lists as the items and their
   --  order are now.

   procedure Refresh (Item : in out Session) is
   begin
      for Rank in Items.Slot loop
         declare
            Each : Doc_Page renames Item.Docs.Pages (Rank);
         begin
            if Rank <= Item.Reading.Write_Count then
               declare
                  Which : constant Items.Slot
                     := Item.Reading.Write_Order (Rank);
               begin
                  if Each.Bound /= Which then
                     Each.Renaming := False;
                     Widgets.Set_Visible (Each.Title_Field, False);
                     Widgets.Set_Visible (Each.Heading_Area, True);
                     Editors.Attach
                       (Each.Text,
                        Windows.Content_Document (Item.Windows (Which)));
                     Each.Bound := Which;
                     Each.Caret_Seen := 0;
                  end if;
                  Labels.Set_Text
                    (Each.Heading, Labels.Fitted (Title_Of (Item, Which)));
                  declare
                     Section : constant Natural := Section_Links.Section_Of (Item, Which);
                  begin
                     Widgets.Set_Visible (Each.Swatch, Section /= 0);
                     if Section /= 0 then
                        Pomarine.Widgets.Panels.Set_Fill (Each.Swatch, Section_Links.Ink_Of (Item, Section));
                     end if;
                  end;
                  if not In_View (Item, Which) then
                     --  Out of sight, it keeps neither the focus nor a
                     --  title being renamed.
                     Each.Renaming := False;
                     Widgets.Set_Visible (Each.Title_Field, False);
                     Widgets.Set_Visible (Each.Heading_Area, True);
                     if Widgets.Has_Focus (Each.Text) then
                        Widgets.Release_Focus (Each.Text);
                     end if;
                  end if;
               end;
            elsif Each.Bound /= 0 then
               Each.Bound := 0;
               Each.Renaming := False;
               Widgets.Set_Visible (Each.Title_Field, False);
               Widgets.Set_Visible (Each.Heading_Area, True);
               if Widgets.Has_Focus (Each.Text) then
                  Widgets.Release_Focus (Each.Text);
               end if;
            end if;
            Widgets.Set_Visible
              (Each.Box,
               Rank <= Item.Reading.Write_Count
               and then In_View (Item, Item.Reading.Write_Order (Rank)));
         end;
      end loop;
      Widgets.Set_Visible (Item.Page_View.Docs_None,
                           Item.Reading.Write_Count = 0);
      Buttons.Set_Enabled
        (Item.Page_View.Docs_Folder,
         Item.Docs.Dirs.Count < Items.Directories.Max_Directories);

      for Row in Tree_Row loop
         if Row <= Item.Docs.Tree_Count then
            Show_Tree_Row (Item, Row);
         end if;
         Widgets.Set_Visible (Item.Docs.Doc_Rows (Row).Row,
                              Row <= Item.Docs.Tree_Count);
      end loop;

      for Row in Items.Slot loop
         declare
            Each : Index_Row renames Item.Reading.Source_Rows (Row);
         begin
            if Row <= Item.Reading.Source_Total then
               declare
                  Which : constant Items.Slot
                     := Item.Reading.Source_Order (Row);
               begin
                  Labels.Set_Text
                    (Each.Caption, Labels.Fitted (Title_Of (Item, Which)));
                  Pomarine.Widgets.Panels.Set_Fill
                    (Each.Tag, Canvas_Items.Source_Ink (Item, Which));
                  Choose_Row
                    (Each,
                     Item.Reading.Pinned_Slot = Which
                     or else Readers.Details
                               (Item.Reading.Readers (Which)).State
                             = Items.Open);
               end;
            end if;
            Widgets.Set_Visible (Each.Row, Row <= Item.Reading.Source_Total);
         end;
      end loop;
      Widgets.Set_Visible (Item.Page_View.Sources_None,
                           Item.Reading.Source_Total = 0);
   end Refresh;

   procedure Go_To (Item : in out Session; Rank : Positive);
   --  Scroll the pages to the Rankth.

   procedure Go_To (Item : in out Session; Rank : Positive) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Scrollers.Scroll_To
        (Item.Page_View.Pages_Scroll,
         (Widgets.Top_Of (Item.Docs.Pages (Rank).Box)
          - Widgets.Top_Of (Item.Page_View.Pages_Content)) / Pixels
         - Style.Page_Margin / 2.0);
   end Go_To;

   --  The windows of the sources

   function Picture_Of (Item : Session; Which : Items.Slot) return String is
     (Items.Sources.Shown_File
        (Item.Nav.Store, Item.Opened.Current, Windows.Details (Item.Windows (Which))));
   --  The picture of a source, or the text file of one that is a text.

   procedure Show_Kept
     (Item : in out Session; Which : Items.Slot;
      Shown : in out Readers.Reader; Sync : out Sync_State);
   --  Give the reader the words and highlights the source has kept, and
   --  make its highlights those of the source's window on the canvas.

   procedure Show_Kept
     (Item : in out Session; Which : Items.Slot;
      Shown : in out Readers.Reader; Sync : out Sync_State)
   is
      Key   : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
      Kept  : Items.Marks.Mark_List;
   begin
      if Items.Words.Has_Words (Item.Nav.Store, Key) then
         declare
            Found : Vision.Result;
         begin
            Items.Words.Load_Words (Item.Nav.Store, Key, Found);
            Readers.Set_Recognized (Shown, Found);
         end;
      end if;
      Windows.Get_Marks (Item.Windows (Which), Kept);
      Readers.Set_Marks (Shown, Kept);
      Sync := (Own  => Readers.Marks_Version (Shown),
               Peer => Windows.Marks_Version (Item.Windows (Which)));
   end Show_Kept;

   procedure Make_Reader (Item : in out Session; Which : Items.Slot);
   --  Make the source's window here, closed.

   procedure Make_Reader (Item : in out Session; Which : Items.Slot) is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
   begin
      Readers.Assign
        (Item.Reading.Readers (Which), Details,
         (Left  => 0.0, Top => 0.0,
          Width => Readers.Window_Width, Height => Readers.Window_Height),
         (if Details.Captured_At > 0 then Picture_Of (Item, Which) else ""));
      Item.Reading.Reader_Placed (Which) := False;
      Show_Kept (Item, Which, Item.Reading.Readers (Which),
                 Item.Reading.Reader_Sync (Which));
   end Make_Reader;

   procedure Open_Reader (Item : in out Session; Which : Items.Slot);
   --  Show the source's window, over the others, where it was left or, if
   --  it has not been shown, near the right.

   procedure Open_Reader (Item : in out Session; Which : Items.Slot) is
      Each   : Readers.Reader renames Item.Reading.Readers (Which);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if not Item.Reading.Reader_Placed (Which) then
         declare
            Placed : Natural := 0;
            Step   : Float;
            Wide   : constant Float :=
              Widgets.Width_Of (Item.Page_View.Write_View) / Pixels;
            High   : constant Float :=
              Widgets.Height_Of (Item.Page_View.Write_View) / Pixels;
         begin
            for Placed_Already of Item.Reading.Reader_Placed loop
               if Placed_Already then
                  Placed := Placed + 1;
               end if;
            end loop;
            Step := Float (Placed mod Style.Reader_Count)
                    * Style.Reader_Cascade;
            Readers.Set_Frame
              (Each,
               (Left   => Float'Max
                            (Style.Sidebar_Width + Style.Reader_Margin,
                             Wide - Readers.Window_Width
                             - Style.Reader_Margin - Step),
                Top    => Style.Reader_Margin + Step,
                Width  => Readers.Window_Width,
                Height => Float'Min
                            (Readers.Window_Height,
                             Float'Max
                               (Readers.Least_Height,
                                High - 2.0 * Style.Reader_Margin - Step))));
            Item.Reading.Reader_Placed (Which) := True;
         end;
      end if;
      Readers.Set_State (Each, Items.Open);
      Readers.Place (Each);
      Readers.Bring_To_Front (Each);
   end Open_Reader;

   procedure Unpin (Item : in out Session; Reopen : Boolean);
   --  Let go of the pinned source: close it, or show it in a window.

   procedure Unpin (Item : in out Session; Reopen : Boolean) is
      Which : constant Natural := Item.Reading.Pinned_Slot;
   begin
      if Which = 0 then
         return;
      end if;
      Readers.Release (Item.Reading.Pane_Reader);
      Item.Reading.Pinned_Slot := 0;
      Widgets.Set_Visible (Item.Page_View.Pane, False);
      if Reopen then
         Open_Reader (Item, Which);
      end if;
   end Unpin;

   procedure Pin (Item : in out Session; Which : Items.Slot);
   --  Show the source in the pane, in place of any other.

   procedure Pin (Item : in out Session; Which : Items.Slot) is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
   begin
      Unpin (Item, Reopen => False);
      Readers.Set_State (Item.Reading.Readers (Which), Items.Closed);
      Readers.Assign
        (Item.Reading.Pane_Reader, Details,
         (Left  => 0.0, Top => 0.0,
          Width => Readers.Window_Width, Height => Readers.Window_Height),
         (if Details.Captured_At > 0 then Picture_Of (Item, Which) else ""));
      Show_Kept (Item, Which, Item.Reading.Pane_Reader,
                 Item.Reading.Pane_Sync);
      Readers.Set_Zoom (Item.Reading.Pane_Reader,
                        Readers.Zoom (Item.Reading.Readers (Which)));
      Readers.Set_State (Item.Reading.Pane_Reader, Items.Open);
      Item.Reading.Pinned_Slot := Which;
      Widgets.Set_Visible (Item.Page_View.Pane, True);
      --  As wide as it was left, unless that does not fit the view.
      Item.Page_View.Pane_Wide :=
        Float'Max
          (Style.Pane_Least,
           Float'Min
             (Item.Page_View.Pane_Wide,
              Style.Pane_Share * Widgets.Width_Of (Item.Page_View.Write_View)
              / Widgets.Density (Item.Root.Widgets)));
      Layouts.Set_Layout (Item.Page_View.Pane, Width => Item.Page_View.Pane_Wide);
   end Pin;

   procedure Close_Menu (Item : in out Session);
   --  Put the menu of sources away.

   procedure Close_Menu (Item : in out Session) is
   begin
      if Item.Page_View.Menu_Page /= 0 then
         Buttons.Set_Selected
           (Item.Docs.Pages (Item.Page_View.Menu_Page).Sources_Button, False);
      end if;
      Item.Page_View.Menu_Page := 0;
      Widgets.Set_Visible (Item.Page_View.Menu, False);
   end Close_Menu;

   procedure Close_Context (Item : in out Session);
   --  Put the menu of a row away.

   procedure Close_Context (Item : in out Session) is
   begin
      Item.Context.Context_Kind := No_Context;
      Item.Context.Context_Node := (others => <>);
      Widgets.Set_Visible (Item.Context.Context_Menu, False);
   end Close_Context;

   Heading_Words : constant String := "LINKED TO ";

   function Heading_For (Name : String) return String;
   --  The menu's heading: of the document's title, in capitals (of the
   --  letters of ASCII: the bytes of others are left as they are), as
   --  much of it as fits, cut where a character begins.

   function Heading_For (Name : String) return String is
      Room : constant Natural :=
        Natural'Min (Name'Length, Menus.Text_Capacity - Heading_Words'Length);
      Last : Natural := Name'First - 1 + Room;
      Shown : String := Name;
   begin
      while Last >= Name'First and then Last < Name'Last
        and then Character'Pos (Name (Last + 1)) in 16#80# .. 16#BF#
      loop
         Last := Last - 1;
      end loop;
      for C of Shown loop
         if C in 'a' .. 'z' then
            C := Character'Val (Character'Pos (C) - 32);
         end if;
      end loop;
      return Heading_Words & Shown (Shown'First .. Last);
   end Heading_For;

   Rows_Before : constant := 1;
   --  The heading, before the boxes of the sources.

   function Add_Row (Item : Session) return Positive is
     (Rows_Before + Natural'Max (1, Item.Page_View.Menu_Count) + 2);
   --  After the boxes (or the note that there are none), and a line.

   procedure Open_Menu (Item : in out Session; Rank : Positive);
   --  Show the menu of the sources the Rankth page's document is linked
   --  to, under its button, which looks pressed in while it is shown; or
   --  put it away, if it is shown already.

   procedure Open_Menu (Item : in out Session; Rank : Positive) is
      Which_Doc : constant Items.Slot := Item.Reading.Write_Order (Rank);
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Which_Doc)).Key;
   begin
      if Item.Page_View.Menu_Page = Rank then
         Close_Menu (Item);
         return;
      end if;
      Close_Menu (Item);
      Menus.Clear (Item.Page_View.Menu);
      Menus.Add
        (Item.Page_View.Menu, Menus.Heading, Heading_For (Title_Of (Item,
           Which_Doc)));
      Item.Page_View.Menu_Count := 0;
      for Row in 1 .. Item.Reading.Source_Total loop
         declare
            Which : constant Items.Slot := Item.Reading.Source_Order (Row);
         begin
            if Items.Links.Is_Linked
                 (Item.Nav.Store, Key,
                  Windows.Details (Item.Windows (Which)).Key)
            then
               Item.Page_View.Menu_Count := Item.Page_View.Menu_Count + 1;
               Item.Page_View.Menu_Slots (Item.Page_View.Menu_Count) := Which;
               Menus.Add
                 (Item.Page_View.Menu, Menus.Check, Labels.Fitted (Title_Of (Item,
                    Which)),
                  Checked => Item.Reading.Pinned_Slot = Which);
               Menus.Set_Swatch
                 (Item.Page_View.Menu, Menus.Row_Count (Item.Page_View.Menu),
                  Canvas_Items.Source_Ink (Item, Which));
            end if;
         end;
      end loop;
      if Item.Page_View.Menu_Count = 0 then
         Menus.Add (Item.Page_View.Menu, Menus.Note, "No linked sources");
      end if;
      Menus.Add (Item.Page_View.Menu, Menus.Separator);
      Menus.Add (Item.Page_View.Menu, Menus.Action, "Add source",
                 Menus.Primary);
      Menus.Set_Icon (Item.Page_View.Menu,
                      Menus.Row_Count (Item.Page_View.Menu), Icon_Set.Plus);
      pragma Assert (Menus.Row_Count (Item.Page_View.Menu) = Add_Row (Item));
      Item.Page_View.Menu_Page := Rank;
      Item.Page_View.Menu_Left := -1.0E9;
      Buttons.Set_Selected (Item.Docs.Pages (Rank).Sources_Button, True);
      Widgets.Set_Visible (Item.Page_View.Menu, True);
      Widgets.Raise_To_Front (Item.Page_View.Menu);
   end Open_Menu;

   procedure Toggle_Source (Item : in out Session; Which : Items.Slot);
   --  A source's row was clicked: open its window, or close it.

   procedure Toggle_Source (Item : in out Session; Which : Items.Slot) is
   begin
      if Item.Reading.Pinned_Slot = Which then
         Unpin (Item, Reopen => False);
      elsif Readers.Details (Item.Reading.Readers (Which)).State
         = Items.Open
      then
         Readers.Set_State (Item.Reading.Readers (Which), Items.Closed);
      else
         Open_Reader (Item, Which);
      end if;
   end Toggle_Source;

   procedure Keep_Marks
     (Item  : in out Session;
      Which : Items.Slot;
      Shown : in out Readers.Reader;
      Sync  : in out Sync_State);
   --  Make the highlights of the source's window here and on the canvas
   --  the same, whichever was marked.

   procedure Keep_Marks
     (Item  : in out Session;
      Which : Items.Slot;
      Shown : in out Readers.Reader;
      Sync  : in out Sync_State)
   is
      Own  : constant Natural := Readers.Marks_Version (Shown);
      Peer : constant Natural :=
        Windows.Marks_Version (Item.Windows (Which));
      Kept : Items.Marks.Mark_List;
   begin
      if Own /= Sync.Own then
         if not Readers.Is_Marking (Shown) then
            Readers.Get_Marks (Shown, Kept);
            Items.Marks.Save_Marks
              (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key,
               Kept);
            Windows.Set_Marks (Item.Windows (Which), Kept);
            Sync := (Own  => Own,
                     Peer => Windows.Marks_Version (Item.Windows (Which)));
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      elsif Peer /= Sync.Peer then
         Windows.Get_Marks (Item.Windows (Which), Kept);
         Readers.Set_Marks (Shown, Kept);
         Sync := (Own  => Readers.Marks_Version (Shown), Peer => Peer);
      end if;
   end Keep_Marks;

   procedure Keep_Title
     (Item : Session; Which : Items.Slot; Shown : in out Readers.Reader);
   --  Make the window's title that of the source.

   procedure Keep_Title
     (Item : Session; Which : Items.Slot; Shown : in out Readers.Reader) is
   begin
      if Projects.Titles.To_String (Readers.Details (Shown).Title)
         /= Title_Of (Item, Which)
      then
         Readers.Set_Title (Shown, Title_Of (Item, Which));
      end if;
   end Keep_Title;

   --  Entering and leaving

   procedure Enter (Item : in out Session) is
   begin
      Build_Order (Item);
      for Which in Items.Slot loop
         if Is_Source (Item, Which) then
            Make_Reader (Item, Which);
         end if;
      end loop;
      Item.Dragging.Drag_Row := 0;
      Item.Docs.Drop := (others => <>);
      Item.Naming.Renaming_Dir := 0;
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Widgets.Set_Visible (Item.Docs.Drop_Line, False);
      Refresh (Item);
   end Enter;

   procedure Rebuild (Item : in out Session);
   --  Take the folders, and the documents in them and their order, as they
   --  are kept, which the sections (made, put in another order, or given
   --  documents elsewhere) may have changed; the folder shown stays.

   procedure Rebuild (Item : in out Session) is
      Shown : constant Items.Id :=
        (if Item.Docs.Shown_Dir = 0 then 0
         else Item.Docs.Dirs.Directories (Item.Docs.Shown_Dir).Key);
   begin
      Build_Order (Item);
      for Dir in 1 .. Item.Docs.Dirs.Count loop
         if Shown /= 0 and then Item.Docs.Dirs.Directories (Dir).Key = Shown then
            Item.Docs.Shown_Dir := Dir;
         end if;
      end loop;
      Item.Section_Menu.Seen := Item.Section_Menu.Changes;
      Refresh (Item);
   end Rebuild;

   procedure Apply (Item : in out Session; To : Modes);
   --  Show the view, without keeping that it is the project's.

   procedure Apply (Item : in out Session; To : Modes) is
   begin
      Item.Toolbar.Mode := To;
      Section_Links.Close (Item);
      Section_Links.Update (Item);
      Close_Menu (Item);
      Close_Context (Item);
      Widgets.Set_Visible (Item.Outline_View.View, To = Outline);
      Widgets.Set_Visible (Item.Canvas_View, To = Canvas);
      Widgets.Set_Visible (Item.Page_View.Write_View, To = Write);
      Buttons.Set_Selected (Item.Toolbar.Outline_Tab, To = Outline);
      Buttons.Set_Selected (Item.Toolbar.Canvas_Tab, To = Canvas);
      Buttons.Set_Selected (Item.Toolbar.Write_Tab, To = Write);
      Widgets.Set_Visible (Item.Dock.Tools, To = Canvas);
      Widgets.Set_Visible (Item.Dock.Tool_List, To = Canvas);
      Canvas_Items.Show_Dock (Item);
      if To = Write then
         Rebuild (Item);
      elsif To = Outline and then Item.Opened.Current /= 0 then
         Outlines.Shown (Item);
      end if;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if To = Canvas then
         Canvas_Items.Sync (Item);
      end if;
   end Apply;

   procedure Show (Item : in out Session; To : Modes) is
   begin
      Apply (Item, To);
      Projects.Set_Tab (Item.Nav.Store, Item.Opened.Current, Modes'Pos (To));
   end Show;

   procedure Restore (Item : in out Session) is
   begin
      Apply
        (Item,
         Modes'Val
           (Natural'Min (Projects.Tab (Item.Nav.Store, Item.Opened.Current),
                         Modes'Pos (Modes'Last))));
   end Restore;

   procedure Leave (Item : in out Session) is
   begin
      Grammar.Reset (Item);
      Unpin (Item, Reopen => False);
      for Which in Items.Slot loop
         if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
            Readers.Release (Item.Reading.Readers (Which));
         end if;
      end loop;
      Item.Reading.Write_Count := 0;
      Item.Reading.Source_Total := 0;
      Item.Docs.Dirs.Count := 0;
      Item.Docs.Tree_Count := 0;
      Item.Docs.Shown_Dir := 0;
      Item.Dragging.Drag_Row := 0;
      Item.Docs.Drop := (others => <>);
      Item.Naming.Renaming_Dir := 0;
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Widgets.Set_Visible (Item.Docs.Drop_Line, False);
      Refresh (Item);
      Apply (Item, Canvas);
   end Leave;

   function Dir_Of_Section (Item : Session; Section : Positive) return Natural is
   begin
      for Dir in 1 .. Item.Docs.Dirs.Count loop
         if Item.Docs.Dirs.Directories (Dir).Section
            = Long_Integer (Outlines.Section_At (Item, Section).Key)
         then
            return Dir;
         end if;
      end loop;
      return 0;
   end Dir_Of_Section;
   --  The directory that is the section's, 0 if there is none (yet).

   procedure Added (Item : in out Session; Which : Items.Slot) is
   begin
      if Is_Note (Item, Which) then
         --  One written while a directory is shown is last in it; else
         --  last of all.
         Item.Docs.Doc_Dir (Which) :=
           (if Item.Section_View.Pending in 1 .. Outlines.Section_Count (Item)
            then Dir_Of_Section (Item, Item.Section_View.Pending)
            elsif Item.Toolbar.Mode = Write then Item.Docs.Shown_Dir else 0);
         Insert_Row
           (Item,
            (if Item.Docs.Doc_Dir (Which) = 0 then Item.Docs.Tree_Count + 1
             else Block_End (Item, Dir_Row (Item, Item.Docs.Doc_Dir (Which)))
                + 1),
            (Kind => Document_Leaf, Dir => Item.Docs.Doc_Dir (Which),
             Doc  => Which));
         Sync_Order (Item);
         if Item.Docs.Doc_Dir (Which) /= 0 then
            Keep_Directory (Item, Which);
         end if;
         Keep_Order (Item);
         if Is_Section (Item, Item.Docs.Doc_Dir (Which)) then
            --  Made in a section's folder, it is the section's, and called
            --  as it if it has no name of its own.
            Section_Links.Joined (Item, Which);
            Item.Section_Menu.Seen := Item.Section_Menu.Changes;
         end if;
         Refresh (Item);
         if Item.Toolbar.Mode = Write then
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            Fit (Item);
            Go_To (Item, Rank_Of (Item, Which));
            Widgets.Focus (Item.Docs.Pages (Rank_Of (Item, Which)).Text);
         end if;
      else
         Item.Reading.Source_Total := Item.Reading.Source_Total + 1;
         Item.Reading.Source_Order (Item.Reading.Source_Total) := Which;
         Make_Reader (Item, Which);
         Refresh (Item);
      end if;
   end Added;

   procedure Removed (Item : in out Session; Which : Items.Slot) is
   begin
      if Is_Note (Item, Which) then
         declare
            Row : constant Natural := Leaf_Row (Item, Which);
         begin
            if Row > 0 then
               Delete_Row (Item, Row);
               Sync_Order (Item);
            end if;
            Item.Docs.Doc_Dir (Which) := 0;
         end;
      else
         declare
            Row : constant Natural := Row_Of (Item, Which);
         begin
            if Item.Reading.Pinned_Slot = Which then
               Unpin (Item, Reopen => False);
            end if;
            if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
               Readers.Release (Item.Reading.Readers (Which));
            end if;
            if Row > 0 then
               for Place in Row .. Item.Reading.Source_Total - 1 loop
                  Item.Reading.Source_Order (Place)
                     := Item.Reading.Source_Order (Place + 1);
               end loop;
               Item.Reading.Source_Total := Item.Reading.Source_Total - 1;
            end if;
         end;
      end if;
      Refresh (Item);
   end Removed;

   procedure Picture_Taken (Item : in out Session; Which : Items.Slot) is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));

      procedure Show (Shown : in out Readers.Reader; Sync : out Sync_State) is
      begin
         Readers.Set_Document
           (Shown, Items.Extensions.To_String (Details.Document), Details.Page, Details.Page_Count);
         Readers.Set_Picture
           (Shown, Picture_Of (Item, Which), Details.Captured_At);
         Sync := (Own  => Readers.Marks_Version (Shown),
                  Peer => Windows.Marks_Version (Item.Windows (Which)));
      end Show;
   begin
      if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
         Show (Item.Reading.Readers (Which), Item.Reading.Reader_Sync (Which));
      end if;
      if Item.Reading.Pinned_Slot = Which then
         Show (Item.Reading.Pane_Reader, Item.Reading.Pane_Sync);
      end if;
   end Picture_Taken;

   procedure Page_Turned (Item : in out Session; Which : Items.Slot) is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
   begin
      if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
         Readers.Set_Document
           (Item.Reading.Readers (Which), Items.Extensions.To_String (Details.Document),
            Details.Page, Details.Page_Count);
         Readers.Go_To_Page (Item.Reading.Readers (Which), Details.Page);
      end if;
      if Item.Reading.Pinned_Slot = Which then
         Readers.Set_Document
           (Item.Reading.Pane_Reader, Items.Extensions.To_String (Details.Document),
            Details.Page, Details.Page_Count);
         Readers.Go_To_Page (Item.Reading.Pane_Reader, Details.Page);
      end if;
   end Page_Turned;

   procedure Words_Found
     (Item : in out Session; Which : Items.Slot; Found : Vision.Result) is
   begin
      if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
         Readers.Set_Recognized (Item.Reading.Readers (Which), Found);
      end if;
      if Item.Reading.Pinned_Slot = Which then
         Readers.Set_Recognized (Item.Reading.Pane_Reader, Found);
      end if;
   end Words_Found;

   procedure Relocate
     (Item : in out Session; Row, Index, Dir : Natural);
   --  Put the row, a document or a directory, before the Indexth row, and
   --  a document in the directory (none, if 0), and keep that.

   procedure Relocate
     (Item : in out Session; Row, Index, Dir : Natural) is
   begin
      if Item.Docs.Tree (Row).Kind = Document_Leaf then
         declare
            Was : constant Natural := Item.Docs.Doc_Dir (Item.Docs.Tree (Row).Doc);
         begin
            Item.Docs.Doc_Dir (Item.Docs.Tree (Row).Doc) := Dir;
            Item.Docs.Tree (Row).Dir := Dir;
            Keep_Directory (Item, Item.Docs.Tree (Row).Doc);
            if Is_Section (Item, Was) or else Is_Section (Item, Dir) then
               --  Of another section, or of none: the outline's counts, and
               --  the colours, follow.
               Outlines.Reload (Item);
               Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
               Item.Section_Menu.Seen := Item.Section_Menu.Changes;
            end if;
         end;
      end if;
      Move_Block (Item, Row, Index);
      Sync_Order (Item);
      Keep_Order (Item);
      Refresh (Item);
   end Relocate;

   function Last_Of (Item : Session; Dir : Natural) return Positive is
     (if Dir = 0 then Item.Docs.Tree_Count + 1
      else Block_End (Item, Dir_Row (Item, Dir)) + 1);
   --  Where a document last in the directory is put (before the row that
   --  comes after it); Dir_Row cannot be 0 for a directory.

   procedure Move (Item : in out Session; From, To : Positive) is
      Beside : constant Items.Slot := Item.Reading.Write_Order (To);
   begin
      if From /= To then
         Relocate
           (Item, Leaf_Row (Item, Item.Reading.Write_Order (From)),
            Leaf_Row (Item, Beside) + (if From < To then 1 else 0),
            Item.Docs.Doc_Dir (Beside));
      end if;
   end Move;

   procedure Move_To_Directory
     (Item : in out Session; Rank : Positive; Directory : Natural) is
   begin
      Relocate
        (Item, Leaf_Row (Item, Item.Reading.Write_Order (Rank)),
         Last_Of (Item, Directory), Directory);
   end Move_To_Directory;

   procedure Drop_Row
     (Item : in out Session; Row : Positive; Target : Drop_Target);
   --  Put the row where it was dropped.

   procedure Drop_Row
     (Item : in out Session; Row : Positive; Target : Drop_Target) is
   begin
      case Target.Kind is
         when No_Drop =>
            null;
         when Into_Node =>
            Relocate
              (Item, Row,
               Last_Of (Item,
                        (if Item.Docs.Tree (Target.Row).Kind = Directory_Node
                         then Item.Docs.Tree (Target.Row).Dir else 0)),
               (if Item.Docs.Tree (Target.Row).Kind = Directory_Node
                then Item.Docs.Tree (Target.Row).Dir else 0));
         when Between =>
            Relocate (Item, Row, Target.Index, Target.Dir);
      end case;
   end Drop_Row;

   --  What is clicked and dragged

   procedure Select_Directory (Item : in out Session; Directory : Natural) is
   begin
      Close_Menu (Item);
      Item.Docs.Shown_Dir := Directory;
      Refresh (Item);
      Scrollers.Scroll_To (Item.Page_View.Pages_Scroll, 0.0);
      if Item.Toolbar.Mode = Write then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Fit (Item);
      end if;
   end Select_Directory;

   procedure Show_Page (Item : in out Session; Which : Items.Slot);
   --  Scroll the pages to the document's, showing its directory's first
   --  if it is not one of those shown.

   procedure Show_Page (Item : in out Session; Which : Items.Slot) is
   begin
      if not In_View (Item, Which) then
         Select_Directory (Item, Item.Docs.Doc_Dir (Which));
      end if;
      Go_To (Item, Rank_Of (Item, Which));
   end Show_Page;

   --  Directories

   procedure Put_Field
     (Item    : in out Session;
      Field   : in out Text_Fields.Text_Field;
      Content : in out Widgets.Widget'Class;
      Box     : Grips.Grip);
   --  Put the field to rename over the row, which is in Content, with its
   --  text selected and the focus: what it is of is attached already.

   procedure Put_Field
     (Item    : in out Session;
      Field   : in out Text_Fields.Text_Field;
      Content : in out Widgets.Widget'Class;
      Box     : Grips.Grip)
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Layouts.Set_Layout
        (Field,
         Position => (Left => Widgets.Left_Of (Box) - Widgets.Left_Of (Content),
                      Top  => Widgets.Top_Of (Box) - Widgets.Top_Of (Content),
                      others => <>),
         Width => Widgets.Width_Of (Box) - Pomarine.Boxes.Offset (Pixels),
         Unit => Layouts.Device_Pixels);
      Widgets.Set_Visible (Field, True);
      Widgets.Request_Layout (Field);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Pomarine.Text_Areas.Select_All (Text_Fields.Area (Field).all);
      Widgets.Focus (Field);
   end Put_Field;

   procedure Begin_Rename_Dir (Item : in out Session; Dir : Positive);
   --  Put the field to rename the directory over its row, with the focus.

   procedure Begin_Rename_Dir (Item : in out Session; Dir : Positive) is
      Row : constant Natural := Dir_Row (Item, Dir);
   begin
      if Row = 0 then
         return;
      end if;
      Docs.Load
        (Item.Naming.Dir_Doc,
         Projects.Titles.To_String (Item.Docs.Dirs.Directories (Dir).Title));
      Text_Fields.Attach (Item.Naming.Dir_Field,
                          Item.Naming.Dir_Doc'Unchecked_Access);
      Item.Naming.Renaming_Dir := Dir;
      Put_Field
        (Item, Item.Naming.Dir_Field, Item.Page_View.Docs_Content,
         Item.Docs.Doc_Rows (Row).Row);
   end Begin_Rename_Dir;

   procedure End_Rename_Doc (Item : in out Session);

   procedure Begin_Rename_Doc (Item : in out Session; Which : Items.Slot);
   --  The same for a document, whose title the field edits as the
   --  window's own title bar does.

   procedure Begin_Rename_Doc (Item : in out Session; Which : Items.Slot) is
      Row : constant Natural := Leaf_Row (Item, Which);
   begin
      if Row = 0 then
         return;
      end if;
      Text_Fields.Attach
        (Item.Naming.Dir_Field, Windows.Title_Document (Item.Windows (Which)));
      Item.Naming.Renaming_Doc := Which;
      Put_Field
        (Item, Item.Naming.Dir_Field, Item.Page_View.Docs_Content,
         Item.Docs.Doc_Rows (Row).Row);
   end Begin_Rename_Doc;

   procedure Begin_Rename_Source (Item : in out Session; Which : Items.Slot);
   --  The same for a source, in the list of them: it is the window's title,
   --  which is the one on the canvas.

   procedure Begin_Rename_Source (Item : in out Session; Which : Items.Slot)
   is
      Row : constant Natural := Row_Of (Item, Which);
   begin
      if Row = 0 then
         return;
      end if;
      Text_Fields.Attach
        (Item.Naming.Source_Field,
         Windows.Title_Document (Item.Windows (Which)));
      Item.Naming.Renaming_Source := Which;
      Put_Field
        (Item, Item.Naming.Source_Field, Item.Page_View.Sources_Content,
         Item.Reading.Source_Rows (Row).Row);
   end Begin_Rename_Source;

   procedure End_Rename_Dir (Item : in out Session);
   --  Keep the new name of the directory, unless it is only spaces.

   procedure End_Rename_Dir (Item : in out Session) is
      Content : constant String := Docs.Whole (Item.Naming.Dir_Doc);
      Dir     : constant Natural := Item.Naming.Renaming_Dir;
      First   : Positive := Content'First;
      Last    : Natural := Content'Last;
   begin
      Item.Naming.Renaming_Dir := 0;
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if Dir /= 0 and then Last >= First then
         declare
            Name : constant String :=
              Content (First ..
                       Natural'Min
                         (Last, First + Projects.Title_Capacity - 1));
         begin
            if Is_Section (Item, Dir) then
               --  A section's folder has the section's name, which is kept
               --  with the section, and shown wherever it is.
               declare
                  Key : constant Projects.Sections.Section_Id :=
                    Projects.Sections.Section_Id (Item.Docs.Dirs.Directories (Dir).Section);
                  Whole : Natural := Natural'Min (Name'Length, Projects.Sections.Max_Title);
               begin
                  while Whole > 0 and then Whole < Name'Length
                    and then Character'Pos (Name (Name'First + Whole)) in 16#80# .. 16#BF#
                  loop
                     Whole := Whole - 1;
                  end loop;
                  Projects.Sections.Rename
                    (Item.Nav.Store, Key, Name (Name'First .. Name'First + Whole - 1));
                  Outlines.Reload (Item);
                  Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
                  Item.Docs.Dirs.Directories (Dir).Title :=
                    Projects.Titles.To_Bounded_String (Name (Name'First .. Name'First + Whole - 1));
               end;
            else
               Items.Directories.Rename_Directory
                 (Item.Nav.Store, Item.Docs.Dirs.Directories (Dir).Key, Name);
               Item.Docs.Dirs.Directories (Dir).Title :=
                 Projects.Titles.To_Bounded_String (Name);
            end if;
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end;
      end if;
      Refresh (Item);
   end End_Rename_Dir;

   procedure End_Rename_Source (Item : in out Session) is
   begin
      Item.Naming.Renaming_Source := 0;
      Widgets.Set_Visible (Item.Naming.Source_Field, False);
      Refresh (Item);
   end End_Rename_Source;

   procedure End_Rename_Doc (Item : in out Session) is
   begin
      Item.Naming.Renaming_Doc := 0;
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Refresh (Item);
   end End_Rename_Doc;

   procedure Make_Directory (Item : in out Session; Name : String) is
      Key : constant Items.Id :=
        Items.Directories.Create_Directory
          (Item.Nav.Store, Item.Opened.Current, Name);
   begin
      Item.Docs.Dirs.Count := Item.Docs.Dirs.Count + 1;
      Item.Docs.Dirs.Directories (Item.Docs.Dirs.Count) :=
        (Key => Key, Title => Projects.Titles.To_Bounded_String (Name),
         others => <>);
      --  Last of all.
      Insert_Row
        (Item, Item.Docs.Tree_Count + 1,
         (Kind => Directory_Node, Dir => Item.Docs.Dirs.Count, Doc => 0));
      Keep_Order (Item);
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Begin_Rename_Dir (Item, Item.Docs.Dirs.Count);
   end Make_Directory;

   --  The menu of a row

   procedure Show_Context
     (Item : in out Session; Kind : Context_Kinds; X, Y : Float);
   --  Show the menu, its rows added, at X, Y, in points of the window, as
   --  far in as keeps it in the view.

   procedure Show_Context
     (Item : in out Session; Kind : Context_Kinds; X, Y : Float)
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Item.Context.Context_Kind := Kind;
      Layouts.Set_Layout
        (Item.Context.Context_Menu,
         Position =>
           (Left =>
              Float'Rounding
                (Float'Max
                   (0.0,
                    Float'Min
                      (X - Widgets.Left_Of (Item.Toolbar.Content_Panel) / Pixels,
                       Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels
                       - Style.Context_Width)) * Pixels),
            Top =>
              Float'Rounding
                (Float'Max
                   (0.0,
                    Float'Min
                      (Y - Widgets.Top_Of (Item.Toolbar.Content_Panel) / Pixels,
                       Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels
                       - Menus.Height_For (Item.Context.Context_Menu))) * Pixels),
            others => <>),
         Unit => Layouts.Device_Pixels);
      Widgets.Set_Visible (Item.Context.Context_Menu, True);
      Widgets.Raise_To_Front (Item.Context.Context_Menu);
      Widgets.Request_Layout (Item.Context.Context_Menu);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Context;

   procedure Add_Act
     (Item    : in out Session;
      Act     : Context_Acts;
      Name    : String;
      Icon    : Pomarine.Icons.Icon;
      Enabled : Boolean := True;
      Shade   : Menus.Tone := Menus.Plain);
   --  Add a row to the menu that does Act; if it cannot be now, it is a
   --  faint note, which is not clicked.

   procedure Add_Act
     (Item    : in out Session;
      Act     : Context_Acts;
      Name    : String;
      Icon    : Pomarine.Icons.Icon;
      Enabled : Boolean := True;
      Shade   : Menus.Tone := Menus.Plain) is
   begin
      Menus.Add
        (Item.Context.Context_Menu, (if Enabled
                                     then Menus.Action else Menus.Note),
         Name, Shade);
      --  (Select all has none: the others' make room for it.)
      if Act /= Select_All_Act then
         Menus.Set_Icon
           (Item.Context.Context_Menu,
            Menus.Row_Count (Item.Context.Context_Menu), Icon);
      end if;
      Item.Context.Context_Acts
        (Menus.Row_Count (Item.Context.Context_Menu)) :=
        (if Enabled then Act else No_Act);
   end Add_Act;

   function Board_Has_Text (Item : Session) return Boolean is
     (Widgets.Clipboard (Item.Toolbar.Content_Panel) /= null
      and then Widgets.Clipboard (Item.Toolbar.Content_Panel).Text /= "");
   --  Whether there is something to paste.

   procedure Open_Context
     (Item : in out Session; X, Y : Float; Opened : out Boolean)
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      PX     : constant Float := X * Pixels;
      PY     : constant Float := Y * Pixels;

      procedure Begin_Menu is
      begin
         Menus.Clear (Item.Context.Context_Menu);
         Item.Context.Context_Acts := [others => No_Act];
         Item.Context.Context_Canvas := 0;
      end Begin_Menu;

      procedure Of_Row (Node : Tree_Entry) is
      begin
         Begin_Menu;
         Item.Context.Context_Node := Node;
         Add_Act (Item, Rename_Act, "Rename", Icon_Set.Edit);
         --  A section is made and removed in the outline, not here.
         if not (Node.Kind = Directory_Node and then Is_Section (Item, Node.Dir)) then
            Add_Act (Item, Delete_Act, "Delete", Icon_Set.Delete,
                     Shade => Menus.Danger);
         end if;
         Show_Context (Item, Tree_Context, X, Y);
         Opened := True;
      end Of_Row;

      procedure Picture_Menu (Over, Words : Boolean) is
      begin
         if Over then
            Add_Act (Item, Copy_Act, "Copy", Icon_Set.Document);
         end if;
         Add_Act (Item, Select_All_Act, "Select all", Pomarine.Icons.Check,
                  Enabled => Words);
         Show_Context (Item, Picture_Context, X, Y);
         Opened := True;
      end Picture_Menu;

      procedure Text_Menu (Over : Boolean) is
         Paste : constant Boolean := Board_Has_Text (Item);
      begin
         if Over then
            Add_Act (Item, Copy_Act, "Copy", Icon_Set.Document);
            Add_Act (Item, Cut_Act, "Cut", Icon_Set.Eraser);
            Add_Act (Item, Paste_Act, "Paste", Icon_Set.Plus, Paste);
            Add_Act (Item, Select_All_Act, "Select all", Pomarine.Icons.Check);
         else
            Add_Act (Item, Paste_Act, "Paste", Icon_Set.Plus, Paste);
            Add_Act (Item, Select_All_Act, "Select all", Pomarine.Icons.Check);
         end if;
         Show_Context (Item, Text_Context, X, Y);
         Opened := True;
      end Text_Menu;

      procedure Of_Picture (Shown : Readers.Reader; Slot : Natural) is
      begin
         Begin_Menu;
         Item.Context.Context_Reader := Slot;
         Picture_Menu
           (Readers.Is_Over_Selection (Shown, PX, PY),
            Readers.Has_Words (Shown));
      end Of_Picture;

      procedure Of_Text (Rank : Positive) is
         Page  : Doc_Page renames Item.Docs.Pages (Rank);
         Area  : Pomarine.Text_Areas.Text_Area renames Editors.Area (Page.Text).all;
         Over  : constant Boolean :=
           Pomarine.Text_Areas.Is_Over_Selection (Area, PX, PY);
      begin
         --  The caret goes where it was pressed, unless that is in the
         --  selection.
         Widgets.Focus (Page.Text);
         if not Over then
            Pomarine.Text_Areas.Click (Area, PX, PY);
            Pomarine.Text_Areas.Release (Area);
         end if;
         Begin_Menu;
         Item.Context.Context_Page := Rank;
         Text_Menu (Over);
      end Of_Text;

      procedure Of_Window (Which : Items.Slot) is
         Shown : Windows.Window renames Item.Windows (Which);
      begin
         if Windows.Text_Contains (Shown, PX, PY) then
            declare
               Over : constant Boolean :=
                 Windows.Over_Text_Selection (Shown, PX, PY);
            begin
               if not Over then
                  Windows.Put_Caret (Shown, PX, PY);
               end if;
               Begin_Menu;
               Item.Context.Context_Canvas := Which;
               Text_Menu (Over);
            end;
         elsif Is_Source (Item, Which)
           and then Windows.Picture_Contains (Shown, PX, PY)
         then
            Begin_Menu;
            Item.Context.Context_Canvas := Which;
            Picture_Menu
              (Windows.Over_Picture_Selection (Shown, PX, PY),
               Windows.Has_Words (Shown));
         end if;
      end Of_Window;
   begin
      Opened := False;
      if Item.Toolbar.Mode = Canvas then
         --  The window under the pointer, if it is of one.
         declare
            Under : constant Widgets.Widget_Access :=
              Widgets.Hit (Item.Root.Widgets, PX, PY);
         begin
            for Which in Items.Slot loop
               if Windows.Is_Assigned (Item.Windows (Which))
                 and then Windows.Owns (Item.Windows (Which), Under)
               then
                  Of_Window (Which);
                  return;
               end if;
            end loop;
         end;
         return;
      end if;
      if Widgets.Contains (Item.Page_View.Docs_Scroll, PX, PY) then
         for Row in 2 .. Item.Docs.Tree_Count loop
            if Widgets.Contains (Item.Docs.Doc_Rows (Row).Row, PX, PY) then
               Of_Row (Item.Docs.Tree (Row));
               return;
            end if;
         end loop;
      elsif Widgets.Contains (Item.Page_View.Sources_Scroll, PX, PY) then
         for Row in 1 .. Item.Reading.Source_Total loop
            if Widgets.Contains (Item.Reading.Source_Rows (Row).Row, PX,
                                 PY)
            then
               Of_Row
                 ((Kind => Document_Leaf, Dir => 0,
                   Doc  => Item.Reading.Source_Order (Row)));
               return;
            end if;
         end loop;
      end if;
      --  A source's window is over the pages.
      for Which in Items.Slot loop
         if Readers.Is_Assigned (Item.Reading.Readers (Which))
           and then Readers.Details (Item.Reading.Readers (Which)).State
              = Items.Open
           and then Item.Reading.Pinned_Slot /= Which
         then
            declare
               Box : constant Items.Frame :=
                 Readers.Box (Item.Reading.Readers (Which));
            begin
               if PX in Box.Left .. Box.Left + Box.Width
                 and then PY in Box.Top .. Box.Top + Box.Height
               then
                  if Readers.Picture_Contains (Item.Reading.Readers (Which),
                                               PX, PY)
                  then
                     Of_Picture (Item.Reading.Readers (Which), Which);
                  end if;
                  return;
               end if;
            end;
         end if;
      end loop;
      if Item.Reading.Pinned_Slot /= 0
       and then Widgets.Contains (Item.Page_View.Pane, PX, PY)
      then
         if Readers.Picture_Contains (Item.Reading.Pane_Reader, PX, PY) then
            Of_Picture (Item.Reading.Pane_Reader, 0);
         end if;
         return;
      end if;
      for Rank in 1 .. Item.Reading.Write_Count loop
         if In_View (Item, Item.Reading.Write_Order (Rank))
           and then Widgets.Contains (Item.Docs.Pages (Rank).Text, PX, PY)
         then
            Of_Text (Rank);
            return;
         end if;
      end loop;
   end Open_Context;

   procedure Do_Context (Item : in out Session; Chosen : Positive);
   --  Do what the row clicked of the menu does, and put it away.

   procedure Do_Context (Item : in out Session; Chosen : Positive) is
      Act  : constant Context_Acts := Item.Context.Context_Acts (Chosen);
      Kind : constant Context_Kinds := Item.Context.Context_Kind;
      Node : constant Tree_Entry := Item.Context.Context_Node;
      Page : constant Natural := Item.Context.Context_Page;
      Slot : constant Natural := Item.Context.Context_Reader;
      On_Canvas : constant Natural := Item.Context.Context_Canvas;
      Board : constant Widgets.Clipboard_Access :=
        Widgets.Clipboard (Item.Toolbar.Content_Panel);
   begin
      Close_Context (Item);
      case Kind is
         when No_Context =>
            null;
         when Tree_Context =>
            if Act = Rename_Act then
               if Node.Kind = Directory_Node then
                  Begin_Rename_Dir (Item, Node.Dir);
               elsif Is_Source (Item, Node.Doc) then
                  Begin_Rename_Source (Item, Node.Doc);
               else
                  Begin_Rename_Doc (Item, Node.Doc);
               end if;
            elsif Act = Delete_Act
              and then not (Node.Kind = Directory_Node and then Is_Section (Item, Node.Dir))
            then
               Deletion.Confirm_Node (Item, Node);
            end if;
         when Text_Context =>
            if On_Canvas /= 0 then
               Windows.Edit_Text
                 (Item.Windows (On_Canvas),
                  (case Act is
                     when Copy_Act   => Windows.Copy,
                     when Cut_Act    => Windows.Cut,
                     when Paste_Act  => Windows.Paste,
                     when others     => Windows.Select_All));
            elsif Page in 1 .. Item.Reading.Write_Count
             and then Board /= null
            then
               declare
                  Area : Pomarine.Text_Areas.Text_Area renames
                    Editors.Area (Item.Docs.Pages (Page).Text).all;
               begin
                  case Act is
                     when Copy_Act =>
                        Pomarine.Text_Areas.Copy (Area, Board.all);
                     when Cut_Act =>
                        Pomarine.Text_Areas.Cut (Area, Board.all);
                     when Paste_Act =>
                        Pomarine.Text_Areas.Paste (Area, Board.all);
                     when Select_All_Act =>
                        Pomarine.Text_Areas.Select_All (Area);
                     when others =>
                        null;
                  end case;
               end;
            end if;
         when Picture_Context =>
            declare
               procedure Act_On (Shown : in out Readers.Reader) is
               begin
                  if Readers.Is_Assigned (Shown) then
                     if Act = Copy_Act then
                        Readers.Copy (Shown);
                     elsif Act = Select_All_Act then
                        Readers.Select_All (Shown);
                     end if;
                  end if;
               end Act_On;
            begin
               if On_Canvas /= 0 then
                  if Act = Copy_Act then
                     Windows.Copy_Words (Item.Windows (On_Canvas));
                  elsif Act = Select_All_Act then
                     Windows.Select_All_Words (Item.Windows (On_Canvas));
                  end if;
               elsif Slot = 0 then
                  Act_On (Item.Reading.Pane_Reader);
               else
                  Act_On (Item.Reading.Readers (Slot));
               end if;
            end;
      end case;
   end Do_Context;

   procedure Remove_Directory (Item : in out Session; Dir : Positive);
   --  Take the directory out, its documents being in none, where they are.

   procedure Remove_Directory (Item : in out Session; Dir : Positive) is
   begin
      if Is_Section (Item, Dir) then
         return;
      end if;
      Items.Directories.Delete_Directory (Item.Nav.Store,
                              Item.Docs.Dirs.Directories (Dir).Key);
      --  Those in it are in none; the directories after it are one
      --  sooner.
      for Which in Items.Slot loop
         if Item.Docs.Doc_Dir (Which) = Dir then
            Item.Docs.Doc_Dir (Which) := 0;
         elsif Item.Docs.Doc_Dir (Which) > Dir then
            Item.Docs.Doc_Dir (Which) := Item.Docs.Doc_Dir (Which) - 1;
         end if;
      end loop;
      Delete_Row (Item, Dir_Row (Item, Dir));
      for Row in 2 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Dir = Dir
           and then Item.Docs.Tree (Row).Kind = Document_Leaf
         then
            Item.Docs.Tree (Row).Dir := 0;
         elsif Item.Docs.Tree (Row).Dir > Dir then
            Item.Docs.Tree (Row).Dir := Item.Docs.Tree (Row).Dir - 1;
         end if;
      end loop;
      for Each in Dir .. Item.Docs.Dirs.Count - 1 loop
         Item.Docs.Dirs.Directories (Each) := Item.Docs.Dirs.Directories (Each
            + 1);
      end loop;
      Item.Docs.Dirs.Count := Item.Docs.Dirs.Count - 1;
      if Item.Docs.Shown_Dir = Dir then
         Item.Docs.Shown_Dir := 0;
      elsif Item.Docs.Shown_Dir > Dir then
         Item.Docs.Shown_Dir := Item.Docs.Shown_Dir - 1;
      end if;
      Keep_Order (Item);
      Select_Directory (Item, Item.Docs.Shown_Dir);
   end Remove_Directory;

   procedure Delete_Node (Item : in out Session; Node : Tree_Entry) is
   begin
      case Node.Kind is
         when Document_Leaf =>
            Canvas_Items.Remove (Item, Node.Doc);
         when Directory_Node =>
            Remove_Directory (Item, Node.Dir);
         when Overview_Node =>
            null;
      end case;
   end Delete_Node;

   --  Dragging a row

   function Target_At
     (Item : Session; X, Y : Float) return Drop_Target;
   --  Where the row being dragged, dropped at X, Y, in points of the
   --  window, would go. A document goes into a directory or the Overview
   --  (the middle of their rows), or between rows: before or after a
   --  directory (the top and foot of its row, the foot only if it has
   --  no documents), or above or below another document (by which half
   --  of its row, or, of the last in a directory, the lowest quarter puts
   --  it after the directory). A directory goes only between the
   --  directories and the documents in none, before or after the one
   --  under the pointer, or the directory it is in.

   function Target_At
     (Item : Session; X, Y : Float) return Drop_Target
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Point  : constant Float := Y * Pixels;
      Moving : constant Tree_Entry := Item.Docs.Tree (Item.Dragging.Drag_Row);
      Row    : Natural := Item.Docs.Tree_Count;

      function Top (Of_Row : Positive) return Float is
        (Widgets.Top_Of (Item.Docs.Doc_Rows (Of_Row).Row));

      function Bottom (Of_Row : Positive) return Float is
        (Top (Of_Row) + Widgets.Height_Of (Item.Docs.Doc_Rows (Of_Row).Row));

      function Between (Index : Positive; Dir : Natural) return Drop_Target
      is
         Held : constant Positive := Item.Dragging.Drag_Row;
      begin
         --  Where it already is: nowhere.
         if Moving.Kind = Document_Leaf then
            if Index in Held .. Held + 1 and then Dir = Moving.Dir then
               return (others => <>);
            end if;
         elsif Index in Held .. Block_End (Item, Held) + 1 then
            return (others => <>);
         end if;
         return (Kind => Viewer.Between, Row => 0, Index => Index,
                 Dir => (if Moving.Kind = Document_Leaf then Dir else 0));
      end Between;
   begin
      if not Widgets.Contains (Item.Page_View.Docs_Scroll, X * Pixels,
                               Point)
      then
         return (others => <>);
      end if;
      for Each in 1 .. Item.Docs.Tree_Count loop
         if Point < Bottom (Each) then
            Row := Each;
            exit;
         end if;
      end loop;
      if Row = 0 or else Row = Item.Dragging.Drag_Row then
         return (others => <>);
      end if;
      declare
         Node  : constant Tree_Entry := Item.Docs.Tree (Row);
         Fract : constant Float :=
           (Point - Top (Row)) / (Bottom (Row) - Top (Row));
      begin
         if Moving.Kind = Directory_Node then
            --  Whole units of the top level: the directory with its
            --  documents, or a document in none.
            declare
               First : constant Natural :=
                 (case Node.Kind is
                  when Overview_Node => 0,
                  when Directory_Node => Row,
                  when Document_Leaf =>
                    (if Node.Dir = 0 then Row else Dir_Row (Item, Node.Dir)));
            begin
               if First = 0 then
                  return (others => <>);
               end if;
               declare
                  Last : constant Positive := Block_End (Item, First);
               begin
                  return (if Point < (Top (First) + Bottom (Last)) / 2.0
                          then Between (First, 0)
                          else Between (Last + 1, 0));
               end;
            end;
         end if;
         case Node.Kind is
            when Overview_Node =>
               return (Kind => Into_Node, Row => Row, others => <>);
            when Directory_Node =>
               if Fract < 0.25 then
                  return Between (Row, 0);
               elsif Fract >= 0.75 and then Block_End (Item, Row) = Row then
                  return Between (Row + 1, 0);
               else
                  return (Kind => Into_Node, Row => Row, others => <>);
               end if;
            when Document_Leaf =>
               declare
                  Last : constant Boolean :=
                    Node.Dir /= 0
                    and then Block_End (Item, Dir_Row (Item, Node.Dir))
                             = Row;
               begin
                  if Fract < 0.5 then
                     return Between (Row, Node.Dir);
                  elsif Last and then Fract >= 0.75 then
                     return Between (Row + 1, 0);
                  else
                     return Between (Row + 1, Node.Dir);
                  end if;
               end;
         end case;
      end;
   end Target_At;

   procedure Show_Drop_Line (Item : in out Session);
   --  Put the line where a row would go between two, or hide it.

   procedure Show_Drop_Line (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      if Item.Docs.Drop.Kind /= Between then
         Widgets.Set_Visible (Item.Docs.Drop_Line, False);
         return;
      end if;
      declare
         --  Below the row before it, in the middle of the gap, and in as
         --  far as what is in a directory is.
         Above : Grips.Grip
            renames Item.Docs.Doc_Rows (Item.Docs.Drop.Index - 1).Row;
         Gap   : constant Float := Style.Index_Gap * Pixels - Offset;
         Mid   : constant Float :=
           Widgets.Top_Of (Above) + Widgets.Height_Of (Above) + Gap / 2.0;
         Thick : constant Float := Style.Drop_Line_Height * Pixels;
         Inset : constant Float :=
           (if Item.Docs.Drop.Dir /= 0
            then Style.Tree_Indent * Pixels else 0.0);
         Edge  : Grips.Grip renames Item.Docs.Doc_Rows (1).Row;
      begin
         Layouts.Set_Layout
           (Item.Docs.Drop_Line,
            Position =>
              (Left => Widgets.Left_Of (Edge)
                       - Widgets.Left_Of (Item.Page_View.Docs_Content) + Inset,
               Top  => Float'Rounding
                         (Mid - Thick / 2.0 - Widgets.Top_Of (Item.Page_View.Docs_Content)),
               others => <>),
            Width => Widgets.Width_Of (Edge) - Offset - Inset,
            Unit => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (Item.Docs.Drop_Line, True);
      Widgets.Request_Layout (Item.Docs.Drop_Line);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Drop_Line;

   function In_Writing (Item : Session) return Boolean is
     (Gestures.Active (Item) and then Item.Toolbar.Mode = Write);
   --  Whether the writing view is the one in use, and not under a dialog.

   subtype Source_Widget is Widgets.Widget'Class;

   --  The tree of documents: a row dragged is dropped on a directory or
   --  the Overview (a document's) or between two rows; a row clicked
   --  shows the directory or goes to the page; a directory's row pressed
   --  twice is renamed.

   procedure Show_Ghost (Item : in out Session);
   --  Put the ghost of the row dragged under the pointer, or hide it.

   procedure Show_Ghost (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
      Row    : constant Natural := Item.Dragging.Drag_Row;
   begin
      if Row = 0 or else not Item.Dragging.Drag_Moved or else Row > Item.Docs.Tree_Count then
         Widgets.Set_Visible (Item.Docs.Ghost, False);
         return;
      end if;
      declare
         Held  : Grips.Grip renames Item.Docs.Doc_Rows (Row).Row;
         X, Y  : Float;
         High  : constant Float := Widgets.Height_Of (Held) - Offset;
         Most  : constant Float :=
           Float'Max (0.0, Widgets.Height_Of (Item.Page_View.Docs_Content) - High);
         --  A little to the side, as far as the pointer is, so that what
         --  it is over is clear.
         Leeway : Float;
      begin
         Grips.Pointer (Held, X, Y);
         Leeway := Float'Max (-Style.Ghost_Leeway, Float'Min (Style.Ghost_Leeway, X - Item.Dragging.Drag_From_X));
         Labels.Set_Text (Item.Docs.Ghost_Title, Labels.Text (Item.Docs.Doc_Rows (Row).Caption));
         Layouts.Set_Layout
           (Item.Docs.Ghost,
            Position =>
              (Left => Widgets.Left_Of (Held) - Widgets.Left_Of (Item.Page_View.Docs_Content)
                       + Float'Rounding (Leeway * Pixels),
               Top  => Float'Min
                         (Most, Float'Max
                                  (0.0, Float'Rounding
                                          (Y * Pixels - High / 2.0
                                           - Widgets.Top_Of (Item.Page_View.Docs_Content)))),
               others => <>),
            Width  => Widgets.Width_Of (Held) - Offset,
            Height => High,
            Unit   => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (Item.Docs.Ghost, True);
      Widgets.Request_Layout (Item.Docs.Ghost);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Ghost;

   procedure Start_Drag (Item : in out Session; Row : Positive);
   --  Begin the drag of Row if none is on: not of the Overview, which is
   --  not put elsewhere, nor of a section, whose place is the outline's.

   procedure Start_Drag (Item : in out Session; Row : Positive) is
   begin
      if Item.Dragging.Drag_Row = 0
        and then Row <= Item.Docs.Tree_Count
        and then Item.Docs.Tree (Row).Kind /= Overview_Node
        and then not (Item.Docs.Tree (Row).Kind = Directory_Node
                      and then Is_Section (Item, Item.Docs.Tree (Row).Dir))
      then
         Item.Dragging.Drag_Row := Row;
         Item.Dragging.Drag_Total := 0.0;
         Item.Dragging.Drag_Moved := False;
         Item.Docs.Drop := (others => <>);
         declare
            X, Y : Float;
         begin
            Grips.Pointer (Item.Docs.Doc_Rows (Row).Row, X, Y);
            Item.Dragging.Drag_From_X := X;
            pragma Unreferenced (Y);
         end;
      end if;
   end Start_Drag;

   procedure Row_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  A row of the tree was dragged a little (Across, Down): the drag has
   --  begun if it was far enough, and the row is over what it would be
   --  dropped on.

   procedure Row_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Positive := Event.Index;
   begin
      if not In_Writing (Item) or else Row > Item.Docs.Tree_Count then
         return;
      end if;
      Start_Drag (Item, Row);
      if Item.Dragging.Drag_Row /= Row then
         return;
      end if;
      Item.Dragging.Drag_Total := Item.Dragging.Drag_Total + abs Event.Across + abs Event.Down;
      if Item.Dragging.Drag_Total >= Drag_Threshold and then not Item.Dragging.Drag_Moved then
         Item.Dragging.Drag_Moved := True;
         Refresh (Item);
      end if;
      if Item.Dragging.Drag_Moved then
         declare
            X, Y   : Float;
            Target : Drop_Target;
         begin
            Grips.Pointer (Item.Docs.Doc_Rows (Row).Row, X, Y);
            Show_Ghost (Item);
            Target := Target_At (Item, X, Y);
            if Target /= Item.Docs.Drop then
               Item.Docs.Drop := Target;
               Refresh (Item);
               Show_Drop_Line (Item);
            end if;
         end;
      end if;
   end Row_Dragged;

   procedure Row_Released
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  A row of the tree was let go: it is dropped, if it was dragged.

   procedure Row_Released
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Positive := Event.Index;
   begin
      Item.Dragging.Dropped_Moved := False;
      if not In_Writing (Item) or else Row > Item.Docs.Tree_Count then
         return;
      end if;
      Start_Drag (Item, Row);
      if Item.Dragging.Drag_Row /= Row then
         return;
      end if;
      declare
         Was_Moved : constant Boolean := Item.Dragging.Drag_Moved;
         Target    : constant Drop_Target := Item.Docs.Drop;
      begin
         Item.Dragging.Drag_Row := 0;
         Item.Dragging.Drag_Moved := False;
         Item.Docs.Drop := (others => <>);
         Item.Dragging.Dropped_Moved := Was_Moved;
         if Was_Moved then
            Drop_Row (Item, Row, Target);
         end if;
      end;
      Show_Drop_Line (Item);
      Show_Ghost (Item);
      Refresh (Item);
   end Row_Released;

   procedure Row_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  A row of the tree was clicked, and was not dragged.

   procedure Row_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row   : constant Positive := Event.Index;
      Moved : constant Boolean := Item.Dragging.Dropped_Moved;
   begin
      Item.Dragging.Dropped_Moved := False;
      if not In_Writing (Item) or else Row > Item.Docs.Tree_Count
        or else Moved or else Item.Dragging.Drag_Row /= 0
      then
         return;
      end if;
      declare
         Node : constant Tree_Entry := Item.Docs.Tree (Row);
      begin
         case Node.Kind is
            when Overview_Node =>
               Select_Directory (Item, 0);
            when Directory_Node =>
               if Item.Naming.Renaming_Dir /= Node.Dir then
                  Select_Directory (Item, Node.Dir);
               end if;
            when Document_Leaf =>
               Show_Page (Item, Node.Doc);
         end case;
      end;
   end Row_Clicked;

   procedure Row_Double_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  A directory's row was pressed twice: rename it.

   procedure Row_Double_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Positive := Event.Index;
   begin
      if not In_Writing (Item) or else Row > Item.Docs.Tree_Count then
         return;
      end if;
      declare
         Node : constant Tree_Entry := Item.Docs.Tree (Row);
      begin
         if Node.Kind = Directory_Node and then Item.Naming.Renaming_Dir /= Node.Dir then
            --  The press that began it is not let go on its row.
            Grips.Cancel_Drag (Item.Docs.Doc_Rows (Row).Row);
            Begin_Rename_Dir (Item, Node.Dir);
         end if;
      end;
   end Row_Double_Clicked;

   procedure Directory_Field_Ended
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  Return in the field of a directory's or a document's name, or it
   --  lost the focus: the renaming is over.

   procedure Directory_Field_Ended
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if not In_Writing (Item) then
         return;
      end if;
      if Item.Naming.Renaming_Dir /= 0 then
         End_Rename_Dir (Item);
      elsif Item.Naming.Renaming_Doc /= 0 then
         End_Rename_Doc (Item);
      end if;
   end Directory_Field_Ended;

   procedure Source_Field_Ended
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Source_Field_Ended
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if In_Writing (Item) and then Item.Naming.Renaming_Source /= 0 then
         End_Rename_Source (Item);
      end if;
   end Source_Field_Ended;

   procedure Sidebar_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The edge of the list of documents was dragged: size it.

   procedure Sidebar_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if In_Writing (Item) and then Event.Across /= 0.0 then
         declare
            Most : constant Float :=
              Float'Max
                (Style.Sidebar_Least,
                 Float'Min
                   (Style.Sidebar_Most,
                    Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                    - (if Item.Reading.Pinned_Slot /= 0 then Item.Page_View.Pane_Wide else 0.0)
                    - Style.Page_Min_Width - 2.0 * Style.Page_Margin));
         begin
            Item.Page_View.Sidebar_Wide :=
              Float'Min (Most, Float'Max (Style.Sidebar_Least, Item.Page_View.Sidebar_Wide + Event.Across));
            Layouts.Set_Layout (Item.Page_View.Sidebar, Width => Item.Page_View.Sidebar_Wide);
         end;
      end if;
   end Sidebar_Dragged;

   procedure Sidebar_Released
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The edge was let go: keep how wide the list is.

   procedure Sidebar_Released
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Prefs.Persist then
         begin
            Preferences.Save_Sidebar_Width
              (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir),
               Natural (Float'Rounding (Item.Page_View.Sidebar_Wide)));
         exception
            when others =>
               null;  --  the width is only not kept
         end;
      end if;
   end Sidebar_Released;

   procedure Sources_Edge_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The edge above the sources list was dragged: size the list.

   procedure Sources_Edge_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      View   : Page_Parts renames Item.Page_View;
   begin
      if In_Writing (Item) and then Event.Down /= 0.0 then
         declare
            Current : constant Float := Widgets.Height_Of (View.Docs_Scroll) / Pixels;
            Available : constant Float := Current + Widgets.Height_Of (View.Sources_Scroll) / Pixels;
            Minimum : constant Float := Float'Min (2.0 * Style.Index_Pitch, Available / 2.0);
            Maximum : constant Float := Available - Minimum;
            Wanted : constant Float := Float'Max (Minimum, Float'Min (Maximum, Current + Event.Down));
         begin
            pragma Assert (Available >= 0.0 and then Minimum <= Maximum);
            --  Fix the space above the divider; Sources takes the remainder.
            --  Both lists must not shrink together, or the divider lags the pointer.
            Layouts.Set_Layout (View.Docs_Scroll, Height => Wanted, Grow => 0.0, Shrink => 0.0);
            Layouts.Set_Layout (View.Sources_Scroll, Height => 0.0, Grow => 1.0, Shrink => 1.0);
         end;
      end if;
   end Sources_Edge_Dragged;

   procedure Pane_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The edge of the pane was dragged: size it.

   procedure Pane_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if In_Writing (Item) and then Event.Across /= 0.0 then
         declare
            Most : constant Float :=
              Float'Max
                (Style.Pane_Least,
                 Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                 - Item.Page_View.Sidebar_Wide - 2.0 * Style.Sidebar_Margin
                 - Style.Page_Min_Width);
         begin
            Item.Page_View.Pane_Wide :=
              Float'Min (Most, Float'Max (Style.Pane_Least,
                                          Item.Page_View.Pane_Wide - Event.Across));
            Layouts.Set_Layout (Item.Page_View.Pane, Width => Item.Page_View.Pane_Wide);
         end;
      end if;
   end Pane_Dragged;

   procedure Page_Title_Double_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  A page's title was pressed twice: rename it.

   procedure Page_Title_Double_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Each : Doc_Page renames Item.Docs.Pages (Event.Index);
   begin
      if In_Writing (Item) and then not Each.Renaming and then Each.Bound /= 0 then
         Text_Fields.Attach
           (Each.Title_Field,
            Windows.Title_Document (Item.Windows (Each.Bound)));
         Each.Renaming := True;
         Widgets.Set_Visible (Each.Heading_Area, False);
         --  The press that began it is not let go on what is hidden.
         Grips.Cancel_Drag (Each.Heading_Area);
         Widgets.Set_Visible (Each.Title_Field, True);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (Each.Title_Field).all);
         Widgets.Focus (Each.Title_Field);
      end if;
   end Page_Title_Double_Clicked;

   procedure Page_Title_Ended
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  Return in a page's title field, or it lost the focus.

   procedure Page_Title_Ended
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Each : Doc_Page renames Item.Docs.Pages (Event.Index);
   begin
      if Each.Renaming then
         Each.Renaming := False;
         Widgets.Set_Visible (Each.Title_Field, False);
         Widgets.Set_Visible (Each.Heading_Area, True);
      end if;
   end Page_Title_Ended;

   procedure Reader_Asked
     (Item   : in out Session;
      Which  : Natural;
      Action : Readers.Actions);
   --  What a button of a source's window here, or of the pane, asked for:
   --  Which is 0 for the pane's.

   procedure Reader_Asked
     (Item   : in out Session;
      Which  : Natural;
      Action : Readers.Actions) is
   begin
      if not In_Writing (Item) then
         return;
      end if;
      if Which /= 0 then
         case Action is
            when Readers.None =>
               null;
            when Readers.Close =>
               Readers.Set_State (Item.Reading.Readers (Which), Items.Closed);
               Refresh (Item);
            when Readers.Toggle_Pin =>
               Pin (Item, Which);
               Refresh (Item);
         end case;
      else
         case Action is
            when Readers.None =>
               null;
            when Readers.Close =>
               Unpin (Item, Reopen => False);
               Refresh (Item);
            when Readers.Toggle_Pin =>
               Unpin (Item, Reopen => True);
               Refresh (Item);
         end case;
      end if;
   end Reader_Asked;

   procedure Listen (Item : in out Session) is
      use all type Widgets.Event_Kind;

      procedure Hear
        (Part    : in out Widgets.Widget'Class;
         Kind    : Widgets.Event_Kind;
         Do_This : Hooks.Handler;
         Index   : Natural := 0) is
      begin
         if Index /= 0 then
            Widgets.Set_Tag (Part, Widgets.No_Tag, Index);
         end if;
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      Hear (Item.Naming.Dir_Field, Submit, Directory_Field_Ended'Access);
      Hear (Item.Naming.Dir_Field, Blur, Directory_Field_Ended'Access);
      Hear (Item.Naming.Source_Field, Submit, Source_Field_Ended'Access);
      Hear (Item.Naming.Source_Field, Blur, Source_Field_Ended'Access);
      for Row in Item.Docs.Doc_Rows'Range loop
         declare
            Box : Grips.Grip renames Item.Docs.Doc_Rows (Row).Row;
         begin
            Hear (Box, Drag, Row_Dragged'Access, Row);
            Hear (Box, Release, Row_Released'Access);
            Hear (Box, Click, Row_Clicked'Access);
            Hear (Box, Double_Click, Row_Double_Clicked'Access);
         end;
      end loop;
      Hear (Item.Page_View.Pane_Edge, Drag, Pane_Dragged'Access);
      Hear (Item.Page_View.Sidebar_Edge, Drag, Sidebar_Dragged'Access);
      Hear (Item.Page_View.Sidebar_Edge, Release, Sidebar_Released'Access);
      Hear (Item.Page_View.Sources_Edge, Drag, Sources_Edge_Dragged'Access);
      for Rank in Items.Slot loop
         Hear (Item.Docs.Pages (Rank).Heading_Area, Double_Click, Page_Title_Double_Clicked'Access, Rank);
         Hear (Item.Docs.Pages (Rank).Title_Field, Submit, Page_Title_Ended'Access, Rank);
         Hear (Item.Docs.Pages (Rank).Title_Field, Blur, Page_Title_Ended'Access, Rank);
         Reader_Events.On (Item.Reading.Readers (Rank), Rank, Item'Unchecked_Access, Reader_Asked'Access);
      end loop;
      Reader_Events.On (Item.Reading.Pane_Reader, 0, Item'Unchecked_Access, Reader_Asked'Access);
   end Listen;

   procedure Add_Page_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
   end Add_Page_Clicked;

   procedure Add_For_Section (Item : in out Session; Section : Positive) is
   begin
      if Section <= Outlines.Section_Count (Item) then
         --  Made last among the documents, whatever the section; Added
         --  makes it the section's.
         Item.Section_View.Pending := Section;
         Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
         Item.Section_View.Pending := 0;
      end if;
   end Add_For_Section;

   procedure Section_Notes_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Place : constant Natural := Event.Index;
   begin
      if Place in 1 .. Outlines.Section_Count (Item) then
         Outlines.Toggle_Notes (Item, Place, Focus => False);
         Fit (Item);
         if Outlines.Notes_Shown (Item, Place) then
            Widgets.Focus (Item.Section_View.Notes (Place).Text);
         end if;
      end if;
   end Section_Notes_Clicked;

   procedure Section_Add_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Add_For_Section (Item, Event.Index);
   end Section_Add_Clicked;

   procedure Add_Folder_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Docs.Dirs.Count < Items.Directories.Max_Directories then
         Make_Directory (Item, Untitled_Directory);
      end if;
   end Add_Folder_Clicked;

   procedure Source_Chosen
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Natural := Event.Row;
   begin
      if Item.Page_View.Menu_Page /= 0 and then Row /= 0 then
         if Row = Add_Row (Item) then
            --  On the canvas, where its address can be typed.
            declare
               Document : constant Items.Slot :=
                 Item.Reading.Write_Order (Item.Page_View.Menu_Page);
            begin
               Close_Menu (Item);
               Show (Item, Canvas);
               Canvas_Items.Add_Linked_Source (Item, Document);
            end;
         elsif Row - Rows_Before in 1 .. Item.Page_View.Menu_Count then
            --  Ticked, it is pinned; ticked again, it is let go.
            declare
               Which : constant Items.Slot :=
                 Item.Page_View.Menu_Slots (Row - Rows_Before);
            begin
               if Item.Reading.Pinned_Slot = Which then
                  Unpin (Item, Reopen => False);
               else
                  Pin (Item, Which);
               end if;
            end;
            Close_Menu (Item);
            Refresh (Item);
         end if;
      end if;
   end Source_Chosen;

   procedure Context_Chosen
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Event.Row /= 0 and then Item.Context.Context_Kind /= No_Context then
         Do_Context (Item, Event.Row);
      end if;
   end Context_Chosen;

   procedure Sources_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Open_Menu (Item, Event.Index);
   end Sources_Clicked;

   procedure Dictate_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Canvas_Items.Toggle_Dictation (Item, Item.Reading.Write_Order (Event.Index));
   end Dictate_Clicked;

   procedure Source_Row_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Toggle_Source (Item, Item.Reading.Source_Order (Event.Index));
      Refresh (Item);
   end Source_Row_Clicked;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);

      procedure Away (Shown : in out Readers.Reader) is
      begin
         if Readers.Is_Assigned (Shown)
           and then Readers.Tool (Shown) /= Pictures.Pointer
         then
            declare
               Box : constant Items.Frame := Readers.Box (Shown);
            begin
               if X * Pixels not in Box.Left .. Box.Left + Box.Width
                 or else Y * Pixels not in Box.Top .. Box.Top + Box.Height
               then
                  Readers.Select_Tool (Shown, Pictures.Pointer);
               end if;
            end;
         end if;
      end Away;
   begin
      if Item.Page_View.Menu_Page /= 0 then
         declare
            Menu : constant Items.Frame :=
              (Left   => Widgets.Left_Of (Item.Page_View.Menu),
               Top    => Widgets.Top_Of (Item.Page_View.Menu),
               Width  => Widgets.Width_Of (Item.Page_View.Menu),
               Height => Widgets.Height_Of (Item.Page_View.Menu));
         begin
            --  Its own button, pressed, is to put it away when clicked.
            if (X * Pixels not in Menu.Left .. Menu.Left + Menu.Width
                or else Y * Pixels not in Menu.Top .. Menu.Top + Menu.Height)
              and then not Widgets.Contains
                             (Item.Docs.Pages
                                (Item.Page_View.Menu_Page).Sources_Button,
                              X * Pixels, Y * Pixels)
            then
               Close_Menu (Item);
            end if;
         end;
      end if;
      if Item.Context.Context_Kind /= No_Context
        and then not Widgets.Contains
                       (Item.Context.Context_Menu, X * Pixels, Y * Pixels)
      then
         Close_Context (Item);
      end if;
      for Each of Item.Reading.Readers loop
         Away (Each);
      end loop;
      Away (Item.Reading.Pane_Reader);
   end Pressed;

   procedure Update (Item : in out Session) is
   begin
      if In_Writing (Item) and then Section_Links.Changes (Item) /= Item.Section_Menu.Seen
        and then Item.Dragging.Drag_Row = 0
      then
         --  A document was made one of a section's, or let go, or a
         --  section renamed: where the documents are in the tree changes.
         Rebuild (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
      if In_Writing (Item) then
         for Each of Item.Reading.Readers loop
            if Readers.Is_Assigned (Each) then
               Readers.Update (Each);
            end if;
         end loop;
         if Readers.Is_Assigned (Item.Reading.Pane_Reader) then
            Readers.Update (Item.Reading.Pane_Reader);
         end if;
      end if;
      for Which in Items.Slot loop
         if Is_Note (Item, Which) then
            declare
               Rank : constant Natural := Rank_Of (Item, Which);
            begin
               Windows.Hold_Typing
                 (Item.Windows (Which),
                  Rank > 0
                  and then Widgets.Has_Focus (Item.Docs.Pages (Rank).Text));
               if Rank > 0 then
                  declare
                     Busy : constant Boolean :=
                       Windows.Dictation (Item.Windows (Which))
                       in Windows.Preparing | Windows.Listening;
                     Mic  : Buttons.Button renames
                       Item.Docs.Pages (Rank).Mic_Button;
                  begin
                     if Busy /= (Buttons.Label (Mic) = "Stop") then
                        Buttons.Set_Label
                          (Mic, (if Busy then "Stop" else "Mic"));
                        Buttons.Set_Icon
                          (Mic,
                           (if Busy then Icon_Set.Stop
                            else Icon_Set.Microphone));
                     end if;
                  end;
                  declare
                     Words : constant Natural :=
                       Windows.Words (Item.Windows (Which));
                  begin
                     Labels.Set_Text
                       (Item.Docs.Pages (Rank).Words,
                        Count_Image (Words)
                        & (if Words = 1 then " word" else " words"));
                  end;
                  Buttons.Set_Badge
                    (Item.Docs.Pages (Rank).Sources_Button,
                     Linked_Sources (Item, Which));
                  Labels.Set_Text
                    (Item.Docs.Pages (Rank).Heading,
                     Labels.Fitted (Title_Of (Item, Which)));
                  declare
                     Row : constant Natural := Leaf_Row (Item, Which);
                  begin
                     if Row > 0 then
                        Labels.Set_Text
                          (Item.Docs.Doc_Rows (Row).Count,
                           Count_Image (Windows.Words (Item.Windows (Which))));
                        Labels.Set_Text
                          (Item.Docs.Doc_Rows (Row).Caption,
                           Labels.Fitted (Title_Of (Item, Which)));
                        if Item.Dragging.Drag_Row = 0 then
                           Choose_Row
                             (Item.Docs.Doc_Rows (Row),
                              Widgets.Has_Focus (Item.Docs.Pages (Rank).Text));
                        end if;
                     end if;
                  end;
               end if;
            end;
         elsif Is_Source (Item, Which)
           and then Readers.Is_Assigned (Item.Reading.Readers (Which))
         then
            Keep_Title (Item, Which, Item.Reading.Readers (Which));
            Readers.Set_Tag
              (Item.Reading.Readers (Which), Canvas_Items.Source_Ink (Item,
                 Which));
            Readers.Follow_Page (Item.Reading.Readers (Which));
            Keep_Marks
              (Item, Which, Item.Reading.Readers (Which),
               Item.Reading.Reader_Sync (Which));
            declare
               Row : constant Natural := Row_Of (Item, Which);
            begin
               if Row > 0 then
                  Labels.Set_Text
                    (Item.Reading.Source_Rows (Row).Caption,
                     Labels.Fitted (Title_Of (Item, Which)));
               end if;
            end;
         end if;
      end loop;
      if Item.Reading.Pinned_Slot /= 0 then
         Keep_Title (Item, Item.Reading.Pinned_Slot, Item.Reading.Pane_Reader);
         Readers.Set_Tag
           (Item.Reading.Pane_Reader,
            Canvas_Items.Source_Ink (Item, Item.Reading.Pinned_Slot));
         Readers.Follow_Page (Item.Reading.Pane_Reader);
         Keep_Marks
           (Item, Item.Reading.Pinned_Slot, Item.Reading.Pane_Reader,
            Item.Reading.Pane_Sync);
      end if;
   end Update;

   procedure Place_Sections (Item : in out Session);
   --  Put the sections among the pages, in the order of the tree: each a
   --  heading, and the pages of its documents or the button to write
   --  one; and a faint line before each run of documents that are of no
   --  section (those between two sections, before the first or after
   --  the last). The pages keep their places in the order of the
   --  documents; only where they are put changes. With a section shown,
   --  it is that one alone. Without sections, or with a folder shown,
   --  the pages are one below the next, as they were.

   procedure Place_Sections (Item : in out Session) is
      Parts  : Section_View_Parts renames Item.Section_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Total  : constant Natural := Outlines.Section_Count (Item);
      Group  : constant Boolean :=
        Total > 0 and then (Item.Docs.Shown_Dir = 0 or else Is_Section (Item, Item.Docs.Shown_Dir));

      function Notes_Box_Height (Place : Positive) return Float is
        (Parts.Notes (Place).High + 2.0 * Style.Notes_Pad + 2.0);
      --  In points: the text, and the padding and outline round it.

      procedure Set_Grouped (To : Boolean) is
      begin
         if To /= Parts.Grouped then
            Parts.Grouped := To;
            Parts.Plan_Count := 0;
            for Each of Item.Docs.Pages loop
               Layouts.Set_Layout
                 (Each.Box, Place => (if To then Layouts.Absolute else Layouts.Flowing));
            end loop;
            Widgets.Set_Visible (Parts.Tail, To);
            Layouts.Set_Layout (Parts.Tail, Height => 0.0);
            if not To then
               for Each of Parts.Heads loop
                  Widgets.Set_Visible (Each.Row, False);
               end loop;
               for Each of Parts.Empties loop
                  Widgets.Set_Visible (Each.Box, False);
               end loop;
               for Each of Parts.Notes loop
                  Widgets.Set_Visible (Each.Box, False);
               end loop;
               for Each of Parts.Gaps loop
                  Widgets.Set_Visible (Each.Row, False);
               end loop;
            end if;
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         end if;
      end Set_Grouped;
   begin
      Set_Grouped (Group);
      if not Group then
         return;
      end if;
      --  The notes are as tall as they need to be, but not less than a few lines.
      for Place in 1 .. Outlines.Section_Count (Item) loop
         if Outlines.Notes_Shown (Item, Place) then
            Parts.Notes (Place).High :=
              Float'Max
                (Style.Notes_Min_Height,
                 Float'Ceiling (Pomarine.Text_Areas.Content_Height (Editors.Area (Parts.Notes (Place).Text).all)));
         end if;
      end loop;
      declare
         Plan   : Plan_Array;
         Count  : Natural := 0;
         Runs   : Natural := 0;
         Open_Run : Boolean := False;
         --  The pages of documents that are of no section, in the order
         --  of the tree, which come one after another, are a run.

         procedure Add (Kind : Plan_Kinds; Index : Natural) is
         begin
            Count := Count + 1;
            Plan (Count) := (Kind => Kind, Index => Index, Top => 0.0);
         end Add;

         procedure Add_Section (Dir : Positive) is
            Place : constant Natural :=
              Outlines.Index_Of_Key
                (Item, Projects.Sections.Section_Id (Item.Docs.Dirs.Directories (Dir).Section));
         begin
            if Place = 0 then
               return;
            end if;
            Add (Head_Entry, Place);
            if Outlines.Notes_Shown (Item, Place) then
               Add (Notes_Entry, Place);
            end if;
            if Documents_In (Item, Dir) = 0 then
               Add (Empty_Entry, Place);
            end if;
            Open_Run := False;
         end Add_Section;
      begin
         if Item.Docs.Shown_Dir /= 0 then
            --  A section's own: its documents, or the button to write one.
            Add_Section (Item.Docs.Shown_Dir);
            for Row in 2 .. Item.Docs.Tree_Count loop
               if Item.Docs.Tree (Row).Kind = Document_Leaf
                 and then Item.Docs.Tree (Row).Dir = Item.Docs.Shown_Dir
               then
                  Add (Page_Entry, Rank_Of (Item, Item.Docs.Tree (Row).Doc));
               end if;
            end loop;
         else
            for Row in 2 .. Item.Docs.Tree_Count loop
               declare
                  Node : Tree_Entry renames Item.Docs.Tree (Row);
               begin
                  case Node.Kind is
                     when Directory_Node =>
                        if Is_Section (Item, Node.Dir) then
                           Add_Section (Node.Dir);
                        end if;
                     when Document_Leaf =>
                        if not Is_Section (Item, Node.Dir) then
                           if not Open_Run then
                              Add (Gap_Entry, Runs);
                              Runs := Runs + 1;
                              Open_Run := True;
                           end if;
                        end if;
                        Add (Page_Entry, Rank_Of (Item, Node.Doc));
                     when Overview_Node =>
                        null;
                  end case;
               end;
            end loop;
         end if;

         --  A section may have been renamed: it is the one name.
         for Each in 1 .. Count loop
            if Plan (Each).Kind = Head_Entry then
               Labels.Set_Text
                 (Parts.Heads (Plan (Each).Index).Title,
                  Labels.Fitted
                    (Projects.Sections.Title_Texts.To_String
                       (Outlines.Section_At (Item, Plan (Each).Index).Title)));
            end if;
         end loop;

         --  Where each goes, down the view.
         declare
            Y : Float := 0.0;
         begin
            for Each in 1 .. Count loop
               declare
                  Now  : Plan_Entry renames Plan (Each);
                  Gap  : constant Float :=
                    (if Each = 1 then 0.0
                     elsif Now.Kind = Head_Entry then Style.Section_Before * Pixels
                     elsif Plan (Each - 1).Kind in Head_Entry | Gap_Entry
                       and then Now.Kind /= Notes_Entry
                     then Style.Section_After * Pixels
                     elsif Now.Kind = Notes_Entry then Style.Page_Gap * Pixels
                     else Style.Page_Gap * Pixels);
                  High : constant Float :=
                    (case Now.Kind is
                        when Head_Entry  => Style.Section_Head_Height * Pixels,
                        when Empty_Entry => Style.Section_Empty_Height * Pixels,
                        when Notes_Entry => Notes_Box_Height (Now.Index) * Pixels,
                        when Gap_Entry   => Style.Gap_Mark_Height * Pixels,
                        when Page_Entry  =>
                          Widgets.Height_Of (Item.Docs.Pages (Now.Index).Box));
               begin
                  Y := Y + Gap;
                  Now.Top := Float'Rounding (Y);
                  Y := Y + High;
               end;
            end loop;
            if Count /= Parts.Plan_Count
              or else (for some Each in 1 .. Count => Plan (Each) /= Parts.Plan (Each))
              or else Float'Rounding (Y) /= Widgets.Height_Of (Parts.Tail)
            then
               declare
                  Wide : constant Float :=
                    Float'Max (Style.Page_Min_Width,
                               Float'Min (Style.Page_Width,
                                          Widgets.Width_Of (Item.Page_View.Pages_Content) / Pixels
                                          - 2.0 * Style.Page_Margin));
                  --  Where a page is, across: in the middle of the view.
                  Home_Left : constant Float :=
                    Float'Rounding ((Widgets.Width_Of (Item.Page_View.Pages_Content) - Wide * Pixels) / 2.0);
                  Home_Top  : constant Float :=
                    Widgets.Top_Of (Parts.Tail) - Widgets.Top_Of (Item.Page_View.Pages_Content);
                  Shown_Heads  : array (1 .. Section_Capacity) of Boolean := [others => False];
                  Shown_Empty  : array (1 .. Section_Capacity) of Boolean := [others => False];
                  Shown_Notes  : array (1 .. Section_Capacity) of Boolean := [others => False];
                  Shown_Gaps   : array (0 .. Section_Capacity) of Boolean := [others => False];

                  procedure Put (Part : in out Widgets.Widget'Class; Top : Float) is
                  begin
                     Layouts.Set_Layout (Part, Width => Wide);
                     Layouts.Set_Layout
                       (Part,
                        Position => (Left => Home_Left, Top => Home_Top + Top, others => <>),
                        Unit => Layouts.Device_Pixels);
                  end Put;
               begin
                  Layouts.Set_Layout (Parts.Tail, Width => Wide, Height => Float'Rounding (Y), Unit => Layouts.Points);
                  Layouts.Set_Layout (Parts.Tail, Height => Float'Rounding (Y), Unit => Layouts.Device_Pixels);
                  for Each in 1 .. Count loop
                     declare
                        Now : Plan_Entry renames Plan (Each);
                     begin
                        case Now.Kind is
                           when Head_Entry =>
                              declare
                                 Head    : Section_Head renames Parts.Heads (Now.Index);
                                 Section : constant Projects.Sections.Section :=
                                   Outlines.Section_At (Item, Now.Index);
                                 Owned   : constant Natural := Outlines.Documents_In (Item, Now.Index);
                              begin
                                 Shown_Heads (Now.Index) := True;
                                 Widgets.Set_Visible (Head.Add, Owned > 0);
                                 Pomarine.Widgets.Buttons.Set_Selected (Head.Notes, Section.Open);
                                 Labels.Set_Text
                                   (Head.Title,
                                    Labels.Fitted (Projects.Sections.Title_Texts.To_String (Section.Title)));
                                 Labels.Set_Text
                                   (Head.Count,
                                    (if Owned = 0 then ""
                                     else Count_Image (Owned) & (if Owned = 1 then " document" else " documents")));
                                 Pomarine.Widgets.Panels.Set_Fill (Head.Bar, Style.Section_Ink (Section.Colour));
                                 Put (Head.Row, Now.Top);
                              end;
                           when Notes_Entry =>
                              declare
                                 Note : Note_Box renames Parts.Notes (Now.Index);
                              begin
                                 Shown_Notes (Now.Index) := True;
                                 Pomarine.Widgets.Panels.Set_Border
                                   (Note.Box, Style.Section_Ink (Outlines.Section_At (Item, Now.Index).Colour));
                                 Layouts.Set_Layout (Note.Text, Height => Note.High);
                                 Layouts.Set_Layout (Note.Box, Height => Notes_Box_Height (Now.Index));
                                 Put (Note.Box, Now.Top);
                              end;
                           when Empty_Entry =>
                              Shown_Empty (Now.Index) := True;
                              Pomarine.Widgets.Panels.Set_Border
                                (Parts.Empties (Now.Index).Box,
                                 Style.Section_Ink (Outlines.Section_At (Item, Now.Index).Colour));
                              Put (Parts.Empties (Now.Index).Box, Now.Top);
                           when Gap_Entry =>
                              Shown_Gaps (Now.Index) := True;
                              Put (Parts.Gaps (Now.Index).Row, Now.Top);
                           when Page_Entry =>
                              Put (Item.Docs.Pages (Now.Index).Box, Now.Top);
                        end case;
                     end;
                  end loop;
                  for Each in Shown_Heads'Range loop
                     Widgets.Set_Visible (Parts.Heads (Each).Row, Shown_Heads (Each));
                     Widgets.Set_Visible (Parts.Empties (Each).Box, Shown_Empty (Each));
                     Widgets.Set_Visible (Parts.Notes (Each).Box, Shown_Notes (Each));
                  end loop;
                  for Each in Shown_Gaps'Range loop
                     Widgets.Set_Visible (Parts.Gaps (Each).Row, Shown_Gaps (Each));
                  end loop;
                  Parts.Plan := Plan;
                  Parts.Plan_Count := Count;
                  Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
               end;
            end if;
         end;
      end;
   end Place_Sections;

   procedure Fit (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Changed : Boolean;
      Moved   : Boolean := False;
   begin
      --  The text is as tall as it needs to be, at the width the sheet
      --  has: laying out again after a change of either settles it.
      for Pass in 1 .. 3 loop
         Changed := False;
         declare
            Room : constant Float :=
              Widgets.Width_Of (Item.Page_View.Pages_Content) / Pixels
              - 2.0 * Style.Page_Margin;
            Wide : constant Float :=
              Float'Max (Style.Page_Min_Width,
                         Float'Min (Style.Page_Width, Room));
         begin
            for Rank in 1 .. Item.Reading.Write_Count loop
               if In_View (Item, Item.Reading.Write_Order (Rank)) then
                  declare
                     Each : Doc_Page renames Item.Docs.Pages (Rank);
                     High : constant Float :=
                       Float'Max
                         (Style.Page_Min_Height,
                          Float'Ceiling
                            (Pomarine.Text_Areas.Content_Height
                               (Editors.Area (Each.Text).all)));
                  begin
                     if Wide /= Each.Wide then
                        Layouts.Set_Layout (Each.Box, Width => Wide);
                        Each.Wide := Wide;
                        Changed := True;
                     end if;
                     if High /= Each.High then
                        Layouts.Set_Layout (Each.Text, Height => High);
                        Each.High := High;
                        Changed := True;
                     end if;
                  end;
               end if;
            end loop;
         end;
         exit when not Changed;
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end loop;

      Place_Sections (Item);

      --  The menu stays under its button, its left edge in line with the
      --  button's (or as far left as keeps it in the view), as the pages
      --  are scrolled.
      if Item.Page_View.Menu_Page /= 0 then
         declare
            Button : Buttons.Button renames
              Item.Docs.Pages (Item.Page_View.Menu_Page).Sources_Button;
            Place_Left   : constant Float :=
              Float'Max
                (0.0,
                 Float'Min
                   ((Widgets.Left_Of (Button)
                     - Widgets.Left_Of (Item.Page_View.Write_View)) / Pixels,
                    Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                    - Style.Menu_Width - Style.Reader_Margin));
            Place_Top    : constant Float :=
              (Widgets.Top_Of (Button) + Widgets.Height_Of (Button)
               - Widgets.Top_Of (Item.Page_View.Write_View)) / Pixels
              + Style.Menu_Gap;
         begin
            if Place_Left /= Item.Page_View.Menu_Left
               or else Place_Top /= Item.Page_View.Menu_Top
            then
               Item.Page_View.Menu_Left := Place_Left;
               Item.Page_View.Menu_Top := Place_Top;
               Layouts.Set_Layout
                 (Item.Page_View.Menu,
                  Position => (Left => Float'Rounding (Place_Left * Pixels),
                               Top  => Float'Rounding (Place_Top * Pixels),
                               others => <>),
                  Unit => Layouts.Device_Pixels);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         end;
      end if;

      --  The caret, where it has gone, is kept in view.
      for Rank in 1 .. Item.Reading.Write_Count loop
         declare
            Each : Doc_Page renames Item.Docs.Pages (Rank);
            Area : Pomarine.Text_Areas.Text_Area renames
              Editors.Area (Each.Text).all;
         begin
            if Widgets.Has_Focus (Each.Text) then
               declare
                  Caret   : constant Texts.Position :=
                    Pomarine.Text_Areas.Caret (Area);
                  Edited  : constant Docs.Version :=
                    Docs.Current (Pomarine.Text_Areas.Document (Area).all);
               begin
                  if Caret /= Each.Caret_For or else Edited /= Each.Caret_Seen
                  then
                     Each.Caret_For := Caret;
                     Each.Caret_Seen := Edited;
                     declare
                        X, Y, Wide, High : Float;
                        Reveal_Top    : constant Float :=
                          Widgets.Top_Of (Item.Page_View.Pages_Scroll)
                          + Reveal_Margin * Pixels;
                        Bottom : constant Float :=
                          Widgets.Top_Of (Item.Page_View.Pages_Scroll)
                          + Widgets.Height_Of (Item.Page_View.Pages_Scroll)
                          - Reveal_Margin * Pixels;
                        Offset : constant Float :=
                          Scrollers.Offset (Item.Page_View.Pages_Scroll);
                     begin
                        Editors.Caret_Box (Each.Text, X, Y, Wide, High);
                        if Y < Reveal_Top then
                           Scrollers.Scroll_To
                             (Item.Page_View.Pages_Scroll,
                              Offset - (Reveal_Top - Y) / Pixels);
                           Moved := True;
                        elsif Y + High > Bottom then
                           Scrollers.Scroll_To
                             (Item.Page_View.Pages_Scroll,
                              Offset + (Y + High - Bottom) / Pixels);
                           Moved := True;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      if Moved then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Fit;

end Viewer.Writing;
