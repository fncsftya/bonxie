with UI.Boxes;
with UI.Themes;
with Ada.Strings.Fixed;
with Texts.Documents;
with UI.Icons;
with UI.Line_Texts;
with UI.Text_Areas;
with UI.Widgets;
with UI.Widgets.Buttons;
with UI.Widgets.Editors;
with UI.Widgets.Grips;
with UI.Widgets.Labels;
with UI.Widgets.Menus;
with UI.Widgets.Panels;
with UI.Widgets.Pictures;
with UI.Widgets.Scrollers;
with UI.Widgets.Text_Fields;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Writing is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Editors renames UI.Widgets.Editors;
   package Grips renames UI.Widgets.Grips;
   package Labels renames UI.Widgets.Labels;
   package Menus renames UI.Widgets.Menus;
   package Pictures renames UI.Widgets.Pictures;
   package Scrollers renames UI.Widgets.Scrollers;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Readers renames Items.Readers;
   package Windows renames Items.Windows;
   package Docs renames Texts.Documents;

   use type Items.Id;
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

   function Fitted (Words : String) return String is
     (Words (Words'First ..
             Words'First - 1
             + Natural'Min (Words'Length, Labels.Text_Capacity)));
   --  As much as a label takes.

   function Is_Note (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Note);

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Source);

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
                           (Items.Position_Of
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
      Items.Load_Directories (Item.Nav.Store, Item.Opened.Current,
                              Item.Docs.Dirs);
      Items.Load_Order (Item.Nav.Store, Item.Opened.Current, Ordered);
      for Place in 1 .. Ordered.Count loop
         for Which in Items.Slot loop
            if Windows.Is_Assigned (Item.Windows (Which))
              and then Windows.Details (Item.Windows (Which)).Key
                       = Ordered.Keys (Place)
            then
               if Is_Note (Item, Which) then
                  declare
                     Inside : constant Items.Id :=
                       Items.Directory_Of (Item.Nav.Store,
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
      Items.Set_Directory
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
               Items.Set_Directory_Position
                 (Item.Nav.Store,
                  Item.Docs.Dirs.Directories (Item.Docs.Tree (Row).Dir).Key,
                     Row);
            when Document_Leaf =>
               Items.Set_Position
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
         (if Chosen then UI.Line_Texts.Strong else UI.Line_Texts.Regular));
      if Chosen then
         Grips.Set_Fill (Row.Row, Style.Row_Open);
         Grips.Set_Hover_Fill (Row.Row, Style.Row_Open);
         Grips.Set_Shadow (Row.Row, UI.Themes.Shadow);
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
      use Yoga.Nodes;
      Each    : Index_Row renames Item.Docs.Doc_Rows (Row);
      Node    : Tree_Entry renames Item.Docs.Tree (Row);
      Pixels  : constant Float := Widgets.Density (Item.Root.Widgets);
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
               Fitted (Projects.Titles.To_String
                         (Item.Docs.Dirs.Directories (Node.Dir).Title)));
            Labels.Set_Text
              (Each.Count, Count_Image (Documents_In (Item, Node.Dir)));
            Chosen := Item.Docs.Shown_Dir = Node.Dir;
         when Document_Leaf =>
            Labels.Set_Text (Each.Caption, Fitted (Title_Of (Item, Node.Doc)));
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
      if Node.Kind = Document_Leaf then
         --  A box, standing up.
         Choose_Row (Each, Chosen);
         Grips.Set_Border (Each.Row, UI.Themes.Border);
         Widgets.Set_Visible (Each.Tag, False);
      else
         --  Not a box: bare, with a marker, in bold; the marker is lit
         --  when it is the one shown, and the row is outlined while a
         --  document is over it.
         Labels.Set_Style (Each.Caption, UI.Line_Texts.Strong);
         Grips.Clear_Fill (Each.Row);
         Grips.Clear_Shadow (Each.Row);
         if Dropped then
            Grips.Set_Border (Each.Row, UI.Themes.Focus);
         elsif Hinted then
            Grips.Set_Border (Each.Row, UI.Themes.Border, Dashed => True);
         else
            Grips.Clear_Border (Each.Row);
         end if;
         UI.Widgets.Panels.Set_Fill
           (Each.Tag, (if Chosen then UI.Themes.Accent else Style.Quiet_Ink));
         Widgets.Set_Visible (Each.Tag, True);
      end if;
      if Level /= Each.Indent then
         --  Shrinks the box, not only its text.
         Each.Indent := Level;
         Set_Margin (Widgets.Node (Each.Row), Yoga.Left, Level * Pixels);
         Widgets.Request_Layout (Each.Row);
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
                    (Each.Heading, Fitted (Title_Of (Item, Which)));
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
         Item.Docs.Dirs.Count < Items.Max_Directories);

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
                    (Each.Caption, Fitted (Title_Of (Item, Which)));
                  UI.Widgets.Panels.Set_Fill
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
     (Items.Image_File
        (Item.Nav.Store, Item.Opened.Current,
         Windows.Details (Item.Windows (Which)).Key));

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
      Kept  : Items.Mark_List;
   begin
      if Items.Has_Words (Item.Nav.Store, Key) then
         declare
            Found : Vision.Result;
         begin
            Items.Load_Words (Item.Nav.Store, Key, Found);
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
      Yoga.Nodes.Set_Width
        (Widgets.Node (Item.Page_View.Pane),
         Item.Page_View.Pane_Wide * Widgets.Density (Item.Root.Widgets));
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
            if Items.Is_Linked
                 (Item.Nav.Store, Key,
                  Windows.Details (Item.Windows (Which)).Key)
            then
               Item.Page_View.Menu_Count := Item.Page_View.Menu_Count + 1;
               Item.Page_View.Menu_Slots (Item.Page_View.Menu_Count) := Which;
               Menus.Add
                 (Item.Page_View.Menu, Menus.Check, Fitted (Title_Of (Item,
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
                      Menus.Row_Count (Item.Page_View.Menu), UI.Icons.Plus);
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
      Kept : Items.Mark_List;
   begin
      if Own /= Sync.Own then
         if not Readers.Is_Marking (Shown) then
            Readers.Get_Marks (Shown, Kept);
            Items.Save_Marks
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

   procedure Show (Item : in out Session; To : Modes) is
   begin
      Item.Toolbar.Mode := To;
      Close_Menu (Item);
      Close_Context (Item);
      Widgets.Set_Visible (Item.Canvas_View, To = Canvas);
      Widgets.Set_Visible (Item.Page_View.Write_View, To = Write);
      Buttons.Set_Selected (Item.Toolbar.Canvas_Tab, To = Canvas);
      Buttons.Set_Selected (Item.Toolbar.Write_Tab, To = Write);
      Widgets.Set_Visible (Item.Dock.Tools, To = Canvas);
      Widgets.Set_Visible (Item.Dock.Tool_List, To = Canvas);
      Canvas_Items.Show_Dock (Item);
      if To = Write then
         Refresh (Item);
      end if;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if To = Canvas then
         Canvas_Items.Sync (Item);
      end if;
   end Show;

   procedure Leave (Item : in out Session) is
   begin
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
      Show (Item, Canvas);
   end Leave;

   procedure Added (Item : in out Session; Which : Items.Slot) is
   begin
      if Is_Note (Item, Which) then
         --  One written while a directory is shown is last in it; else
         --  last of all.
         Item.Docs.Doc_Dir (Which) :=
           (if Item.Toolbar.Mode = Write then Item.Docs.Shown_Dir else 0);
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
         Item.Docs.Doc_Dir (Item.Docs.Tree (Row).Doc) := Dir;
         Item.Docs.Tree (Row).Dir := Dir;
         Keep_Directory (Item, Item.Docs.Tree (Row).Doc);
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
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Set_Position
        (Widgets.Node (Field), Yoga.Left,
         Widgets.Left_Of (Box) - Widgets.Left_Of (Content));
      Set_Position
        (Widgets.Node (Field), Yoga.Top,
         Widgets.Top_Of (Box) - Widgets.Top_Of (Content));
      Set_Width
        (Widgets.Node (Field),
         Widgets.Width_Of (Box) - UI.Boxes.Offset (Pixels));
      Widgets.Set_Visible (Field, True);
      Widgets.Request_Layout (Field);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      UI.Text_Areas.Select_All (Text_Fields.Area (Field).all);
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
            Items.Rename_Directory
              (Item.Nav.Store, Item.Docs.Dirs.Directories (Dir).Key, Name);
            Item.Docs.Dirs.Directories (Dir).Title :=
              Projects.Titles.To_Bounded_String (Name);
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
        Items.Create_Directory (Item.Nav.Store, Item.Opened.Current, Name);
   begin
      Item.Docs.Dirs.Count := Item.Docs.Dirs.Count + 1;
      Item.Docs.Dirs.Directories (Item.Docs.Dirs.Count) :=
        (Key => Key, Title => Projects.Titles.To_Bounded_String (Name),
         Position => 0);
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
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Item.Context.Context_Kind := Kind;
      Set_Position
        (Widgets.Node (Item.Context.Context_Menu), Yoga.Left,
         Float'Rounding
           (Float'Max
              (0.0,
               Float'Min
                 (X - Widgets.Left_Of (Item.Toolbar.Content_Panel) / Pixels,
                  Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels
                  - Style.Context_Width)) * Pixels));
      Set_Position
        (Widgets.Node (Item.Context.Context_Menu), Yoga.Top,
         Float'Rounding
           (Float'Max
              (0.0,
               Float'Min
                 (Y - Widgets.Top_Of (Item.Toolbar.Content_Panel) / Pixels,
                  Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels
                  - Menus.Height_For (Item.Context.Context_Menu))) * Pixels));
      Widgets.Set_Visible (Item.Context.Context_Menu, True);
      Widgets.Raise_To_Front (Item.Context.Context_Menu);
      Widgets.Request_Layout (Item.Context.Context_Menu);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Context;

   procedure Add_Act
     (Item    : in out Session;
      Act     : Context_Acts;
      Name    : String;
      Icon    : UI.Icons.Icon;
      Enabled : Boolean := True;
      Shade   : Menus.Tone := Menus.Plain);
   --  Add a row to the menu that does Act; if it cannot be now, it is a
   --  faint note, which is not clicked.

   procedure Add_Act
     (Item    : in out Session;
      Act     : Context_Acts;
      Name    : String;
      Icon    : UI.Icons.Icon;
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
         Add_Act (Item, Rename_Act, "Rename", UI.Icons.Edit);
         Add_Act (Item, Delete_Act, "Delete", UI.Icons.Delete,
                  Shade => Menus.Danger);
         Show_Context (Item, Tree_Context, X, Y);
         Opened := True;
      end Of_Row;

      procedure Picture_Menu (Over, Words : Boolean) is
      begin
         if Over then
            Add_Act (Item, Copy_Act, "Copy", UI.Icons.Document);
         end if;
         Add_Act (Item, Select_All_Act, "Select all", UI.Icons.Check,
                  Enabled => Words);
         Show_Context (Item, Picture_Context, X, Y);
         Opened := True;
      end Picture_Menu;

      procedure Text_Menu (Over : Boolean) is
         Paste : constant Boolean := Board_Has_Text (Item);
      begin
         if Over then
            Add_Act (Item, Copy_Act, "Copy", UI.Icons.Document);
            Add_Act (Item, Cut_Act, "Cut", UI.Icons.Eraser);
            Add_Act (Item, Paste_Act, "Paste", UI.Icons.Plus, Paste);
            Add_Act (Item, Select_All_Act, "Select all", UI.Icons.Check);
         else
            Add_Act (Item, Paste_Act, "Paste", UI.Icons.Plus, Paste);
            Add_Act (Item, Select_All_Act, "Select all", UI.Icons.Check);
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
         Area  : UI.Text_Areas.Text_Area renames Editors.Area (Page.Text).all;
         Over  : constant Boolean :=
           UI.Text_Areas.Is_Over_Selection (Area, PX, PY);
      begin
         --  The caret goes where it was pressed, unless that is in the
         --  selection.
         Widgets.Focus (Page.Text);
         if not Over then
            UI.Text_Areas.Click (Area, PX, PY);
            UI.Text_Areas.Release (Area);
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
            elsif Act = Delete_Act then
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
                  Area : UI.Text_Areas.Text_Area renames
                    Editors.Area (Item.Docs.Pages (Page).Text).all;
               begin
                  case Act is
                     when Copy_Act =>
                        UI.Text_Areas.Copy (Area, Board.all);
                     when Cut_Act =>
                        UI.Text_Areas.Cut (Area, Board.all);
                     when Paste_Act =>
                        UI.Text_Areas.Paste (Area, Board.all);
                     when Select_All_Act =>
                        UI.Text_Areas.Select_All (Area);
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

   procedure Take_Context (Item : in out Session; Done : out Boolean) is
      Chosen : Natural;
   begin
      Menus.Take_Choice (Item.Context.Context_Menu, Chosen);
      Done := Chosen /= 0 and then Item.Context.Context_Kind /= No_Context;
      if Done then
         Do_Context (Item, Chosen);
      end if;
   end Take_Context;

   procedure Remove_Directory (Item : in out Session; Dir : Positive);
   --  Take the directory out, its documents being in none, where they are.

   procedure Remove_Directory (Item : in out Session; Dir : Positive) is
   begin
      Items.Delete_Directory (Item.Nav.Store,
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
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := UI.Boxes.Offset (Pixels);
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
         Set_Position
           (Widgets.Node (Item.Docs.Drop_Line), Yoga.Left,
            Widgets.Left_Of (Edge)
            - Widgets.Left_Of (Item.Page_View.Docs_Content) + Inset);
         Set_Position
           (Widgets.Node (Item.Docs.Drop_Line), Yoga.Top,
            Float'Rounding
              (Mid - Thick / 2.0
               - Widgets.Top_Of (Item.Page_View.Docs_Content)));
         Set_Width (Widgets.Node (Item.Docs.Drop_Line),
                    Widgets.Width_Of (Edge) - Offset - Inset);
      end;
      Widgets.Set_Visible (Item.Docs.Drop_Line, True);
      Widgets.Request_Layout (Item.Docs.Drop_Line);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Drop_Line;

   procedure Take_Documents (Item : in out Session);
   --  The tree of documents: a row dragged is dropped on a directory or
   --  the Overview (a document's) or between two rows; a row clicked
   --  shows the directory or goes to the page; a directory's row pressed
   --  twice is renamed.

   procedure Take_Documents (Item : in out Session) is
      Clicked      : Boolean;
      Doubled      : Boolean;
      Entered      : Boolean;
      Across, Down : Float;
      Was_Moved    : Boolean := False;
   begin
      if Item.Naming.Renaming_Dir /= 0
         or else Item.Naming.Renaming_Doc /= 0
      then
         Text_Fields.Take_Return (Item.Naming.Dir_Field, Entered);
         if Entered or else not Widgets.Has_Focus (Item.Naming.Dir_Field) then
            if Item.Naming.Renaming_Dir /= 0 then
               End_Rename_Dir (Item);
            else
               End_Rename_Doc (Item);
            end if;
         end if;
      end if;
      if Item.Naming.Renaming_Source /= 0 then
         Text_Fields.Take_Return (Item.Naming.Source_Field, Entered);
         if Entered
            or else not Widgets.Has_Focus (Item.Naming.Source_Field)
         then
            End_Rename_Source (Item);
         end if;
      end if;
      if Item.Dragging.Drag_Row = 0 then
         for Row in 1 .. Item.Docs.Tree_Count loop
            if Grips.Is_Dragging (Item.Docs.Doc_Rows (Row).Row) then
               if Item.Docs.Tree (Row).Kind /= Overview_Node then
                  Item.Dragging.Drag_Row := Row;
                  Item.Dragging.Drag_Total := 0.0;
                  Item.Dragging.Drag_Moved := False;
                  Item.Docs.Drop := (others => <>);
               else
                  --  The Overview is not put elsewhere.
                  Grips.Take_Drag (Item.Docs.Doc_Rows (Row).Row, Across, Down);
               end if;
            end if;
         end loop;
      end if;
      if Item.Dragging.Drag_Row /= 0 then
         declare
            Row  : constant Tree_Row := Item.Dragging.Drag_Row;
            Grip : Grips.Grip renames Item.Docs.Doc_Rows (Row).Row;
         begin
            Grips.Take_Drag (Grip, Across, Down);
            Item.Dragging.Drag_Total := Item.Dragging.Drag_Total + abs Across
               + abs Down;
            if Item.Dragging.Drag_Total >= Drag_Threshold
              and then not Item.Dragging.Drag_Moved
            then
               Item.Dragging.Drag_Moved := True;
               Refresh (Item);
            end if;
            if Item.Dragging.Drag_Moved then
               declare
                  X, Y   : Float;
                  Target : Drop_Target;
               begin
                  Grips.Pointer (Grip, X, Y);
                  Target := Target_At (Item, X, Y);
                  if Target /= Item.Docs.Drop then
                     Item.Docs.Drop := Target;
                     Refresh (Item);
                     Show_Drop_Line (Item);
                  end if;
               end;
            end if;
            if not Grips.Is_Dragging (Grip) then
               Was_Moved := Item.Dragging.Drag_Moved;
               declare
                  Target : constant Drop_Target := Item.Docs.Drop;
               begin
                  Item.Dragging.Drag_Row := 0;
                  Item.Dragging.Drag_Moved := False;
                  Item.Docs.Drop := (others => <>);
                  if Was_Moved then
                     Drop_Row (Item, Row, Target);
                  end if;
               end;
               Show_Drop_Line (Item);
               Refresh (Item);
            end if;
         end;
      end if;
      for Row in 1 .. Item.Docs.Tree_Count loop
         declare
            Box  : Grips.Grip renames Item.Docs.Doc_Rows (Row).Row;
            Node : constant Tree_Entry := Item.Docs.Tree (Row);
         begin
            if Node.Kind = Directory_Node then
               Grips.Take_Double_Click (Box, Doubled);
               if Doubled and then Item.Naming.Renaming_Dir /= Node.Dir then
                  --  The press that began it is not let go on its row.
                  Grips.Cancel_Drag (Box);
                  Grips.Take_Click (Box, Clicked);
                  Begin_Rename_Dir (Item, Node.Dir);
                  return;
               end if;
            end if;
            Grips.Take_Click (Box, Clicked);
            if Clicked and then not Was_Moved
             and then Item.Dragging.Drag_Row = 0
            then
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
               return;
            end if;
         end;
      end loop;
   end Take_Documents;

   procedure Take_Sources (Item : in out Session);
   --  The list of sources, and their windows and the pane.

   procedure Take_Sources (Item : in out Session) is
      Clicked : Boolean;
      Action  : Readers.Actions;
   begin
      for Row in 1 .. Item.Reading.Source_Total loop
         Grips.Take_Click (Item.Reading.Source_Rows (Row).Row, Clicked);
         if Clicked then
            Toggle_Source (Item, Item.Reading.Source_Order (Row));
            Refresh (Item);
            return;
         end if;
      end loop;
      for Which in Items.Slot loop
         if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
            Readers.Poll (Item.Reading.Readers (Which), Action);
            case Action is
               when Readers.None =>
                  null;
               when Readers.Close =>
                  Readers.Set_State (Item.Reading.Readers (Which),
                                     Items.Closed);
                  Refresh (Item);
               when Readers.Toggle_Pin =>
                  Pin (Item, Which);
                  Refresh (Item);
                  return;
            end case;
         end if;
      end loop;
      if Readers.Is_Assigned (Item.Reading.Pane_Reader) then
         Readers.Poll (Item.Reading.Pane_Reader, Action);
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
   end Take_Sources;

   procedure Take_Pane (Item : in out Session);
   --  The edge of the pane, dragged to size it.

   procedure Take_Pane (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Across, Down : Float;
   begin
      Grips.Take_Drag (Item.Page_View.Pane_Edge, Across, Down);
      if Across /= 0.0 then
         declare
            Most : constant Float :=
              Float'Max
                (Style.Pane_Least,
                 Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                 - Style.Sidebar_Width - 2.0 * Style.Sidebar_Margin
                 - Style.Page_Min_Width);
         begin
            Item.Page_View.Pane_Wide :=
              Float'Min (Most, Float'Max (Style.Pane_Least,
                                          Item.Page_View.Pane_Wide - Across));
            Set_Width (Widgets.Node (Item.Page_View.Pane),
                       Item.Page_View.Pane_Wide * Pixels);
            Widgets.Request_Layout (Item.Page_View.Pane);
         end;
      end if;
   end Take_Pane;

   procedure Take_Rename (Item : in out Session; Rank : Positive);
   --  Begin renaming a document at a double press on its title, and end
   --  it at Return or when the field is left.

   procedure Take_Rename (Item : in out Session; Rank : Positive) is
      Each    : Doc_Page renames Item.Docs.Pages (Rank);
      Doubled : Boolean;
      Entered : Boolean;
   begin
      Grips.Take_Double_Click (Each.Heading_Area, Doubled);
      if Doubled and then not Each.Renaming and then Each.Bound /= 0 then
         Text_Fields.Attach
           (Each.Title_Field,
            Windows.Title_Document (Item.Windows (Each.Bound)));
         Each.Renaming := True;
         Widgets.Set_Visible (Each.Heading_Area, False);
         --  The press that began it is not let go on what is hidden.
         Grips.Cancel_Drag (Each.Heading_Area);
         Widgets.Set_Visible (Each.Title_Field, True);
         UI.Text_Areas.Select_All (Text_Fields.Area (Each.Title_Field).all);
         Widgets.Focus (Each.Title_Field);
      elsif Each.Renaming then
         Text_Fields.Take_Return (Each.Title_Field, Entered);
         if Entered or else not Widgets.Has_Focus (Each.Title_Field) then
            Each.Renaming := False;
            Widgets.Set_Visible (Each.Title_Field, False);
            Widgets.Set_Visible (Each.Heading_Area, True);
         end if;
      end if;
   end Take_Rename;

   procedure Take_Pages (Item : in out Session);
   --  The buttons above the pages, and the menu of sources.

   procedure Take_Pages (Item : in out Session) is
      Clicked : Boolean;
   begin
      Buttons.Take_Click (Item.Page_View.Docs_Add, Clicked);
      if Clicked then
         Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
         return;
      end if;
      Buttons.Take_Click (Item.Page_View.Docs_Folder, Clicked);
      if Clicked then
         if Item.Docs.Dirs.Count < Items.Max_Directories then
            Make_Directory (Item, Untitled_Directory);
         end if;
         return;
      end if;
      declare
         Chosen : Natural;
      begin
         Menus.Take_Choice (Item.Page_View.Menu, Chosen);
         if Item.Page_View.Menu_Page /= 0 and then Chosen /= 0 then
            if Chosen = Add_Row (Item) then
               --  On the canvas, where its address can be typed.
               declare
                  Document : constant Items.Slot :=
                    Item.Reading.Write_Order (Item.Page_View.Menu_Page);
               begin
                  Close_Menu (Item);
                  Show (Item, Canvas);
                  Canvas_Items.Add_Linked_Source (Item, Document);
               end;
               return;
            elsif Chosen - Rows_Before in 1 .. Item.Page_View.Menu_Count then
               --  Ticked, it is pinned; ticked again, it is let go.
               declare
                  Which : constant Items.Slot :=
                    Item.Page_View.Menu_Slots (Chosen - Rows_Before);
               begin
                  if Item.Reading.Pinned_Slot = Which then
                     Unpin (Item, Reopen => False);
                  else
                     Pin (Item, Which);
                  end if;
               end;
               Close_Menu (Item);
               Refresh (Item);
               return;
            end if;
         end if;
      end;
      for Rank in 1 .. Item.Reading.Write_Count loop
         Take_Rename (Item, Rank);
         Buttons.Take_Click (Item.Docs.Pages (Rank).Sources_Button, Clicked);
         if Clicked then
            Open_Menu (Item, Rank);
            return;
         end if;
         Buttons.Take_Click (Item.Docs.Pages (Rank).Mic_Button, Clicked);
         if Clicked then
            Canvas_Items.Toggle_Dictation (Item,
                                           Item.Reading.Write_Order (Rank));
            return;
         end if;
      end loop;
   end Take_Pages;

   procedure Take (Item : in out Session) is
   begin
      Take_Pages (Item);
      Take_Documents (Item);
      Take_Sources (Item);
      Take_Pane (Item);
   end Take;

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
                           (if Busy then UI.Icons.Stop
                            else UI.Icons.Microphone));
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
                     Fitted (Title_Of (Item, Which)));
                  declare
                     Row : constant Natural := Leaf_Row (Item, Which);
                  begin
                     if Row > 0 then
                        Labels.Set_Text
                          (Item.Docs.Doc_Rows (Row).Count,
                           Count_Image (Windows.Words (Item.Windows (Which))));
                        Labels.Set_Text
                          (Item.Docs.Doc_Rows (Row).Caption,
                           Fitted (Title_Of (Item, Which)));
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
            Keep_Marks
              (Item, Which, Item.Reading.Readers (Which),
               Item.Reading.Reader_Sync (Which));
            declare
               Row : constant Natural := Row_Of (Item, Which);
            begin
               if Row > 0 then
                  Labels.Set_Text
                    (Item.Reading.Source_Rows (Row).Caption,
                     Fitted (Title_Of (Item, Which)));
               end if;
            end;
         end if;
      end loop;
      if Item.Reading.Pinned_Slot /= 0 then
         Keep_Title (Item, Item.Reading.Pinned_Slot, Item.Reading.Pane_Reader);
         Readers.Set_Tag
           (Item.Reading.Pane_Reader,
            Canvas_Items.Source_Ink (Item, Item.Reading.Pinned_Slot));
         Keep_Marks
           (Item, Item.Reading.Pinned_Slot, Item.Reading.Pane_Reader,
            Item.Reading.Pane_Sync);
      end if;
   end Update;

   procedure Fit (Item : in out Session) is
      use Yoga.Nodes;
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
                            (UI.Text_Areas.Content_Height
                               (Editors.Area (Each.Text).all)));
                  begin
                     if Wide /= Each.Wide then
                        Set_Width (Widgets.Node (Each.Box), Wide * Pixels);
                        Each.Wide := Wide;
                        Changed := True;
                     end if;
                     if High /= Each.High then
                        Set_Height (Widgets.Node (Each.Text), High * Pixels);
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

      --  The menu stays under its button, its left edge in line with the
      --  button's (or as far left as keeps it in the view), as the pages
      --  are scrolled.
      if Item.Page_View.Menu_Page /= 0 then
         declare
            Button : Buttons.Button renames
              Item.Docs.Pages (Item.Page_View.Menu_Page).Sources_Button;
            Left   : constant Float :=
              Float'Max
                (0.0,
                 Float'Min
                   ((Widgets.Left_Of (Button)
                     - Widgets.Left_Of (Item.Page_View.Write_View)) / Pixels,
                    Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                    - Style.Menu_Width - Style.Reader_Margin));
            Top    : constant Float :=
              (Widgets.Top_Of (Button) + Widgets.Height_Of (Button)
               - Widgets.Top_Of (Item.Page_View.Write_View)) / Pixels
              + Style.Menu_Gap;
         begin
            if Left /= Item.Page_View.Menu_Left
               or else Top /= Item.Page_View.Menu_Top
            then
               Item.Page_View.Menu_Left := Left;
               Item.Page_View.Menu_Top := Top;
               Set_Position
                 (Widgets.Node (Item.Page_View.Menu), Yoga.Left,
                  Float'Rounding (Left * Pixels));
               Set_Position
                 (Widgets.Node (Item.Page_View.Menu), Yoga.Top,
                  Float'Rounding (Top * Pixels));
               Widgets.Request_Layout (Item.Page_View.Menu);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         end;
      end if;

      --  The caret, where it has gone, is kept in view.
      for Rank in 1 .. Item.Reading.Write_Count loop
         declare
            Each : Doc_Page renames Item.Docs.Pages (Rank);
            Area : UI.Text_Areas.Text_Area renames
              Editors.Area (Each.Text).all;
         begin
            if Widgets.Has_Focus (Each.Text) then
               declare
                  Caret   : constant Texts.Position :=
                    UI.Text_Areas.Caret (Area);
                  Version : constant Docs.Version :=
                    Docs.Current (UI.Text_Areas.Document (Area).all);
               begin
                  if Caret /= Each.Caret_For or else Version /= Each.Caret_Seen
                  then
                     Each.Caret_For := Caret;
                     Each.Caret_Seen := Version;
                     declare
                        X, Y, Wide, High : Float;
                        Top    : constant Float :=
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
                        if Y < Top then
                           Scrollers.Scroll_To
                             (Item.Page_View.Pages_Scroll,
                              Offset - (Top - Y) / Pixels);
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
