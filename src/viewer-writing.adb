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
with UI.Widgets.Panels;
with UI.Widgets.Pictures;
with UI.Widgets.Scrollers;
with UI.Widgets.Text_Fields;
with Viewer.Canvas_Items;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Writing is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Editors renames UI.Widgets.Editors;
   package Grips renames UI.Widgets.Grips;
   package Labels renames UI.Widgets.Labels;
   package Pictures renames UI.Widgets.Pictures;
   package Scrollers renames UI.Widgets.Scrollers;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Readers renames Items.Readers;
   package Windows renames Items.Windows;
   package Docs renames Texts.Documents;

   use type Items.Id;
   use type Items.Kinds;
   use type Items.States;
   use type Docs.Version;
   use type Texts.Position;
   use type Pictures.Tools;
   use type Windows.Dictations;

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
      for Rank in 1 .. Item.Write_Count loop
         if Item.Write_Order (Rank) = Which then
            return Rank;
         end if;
      end loop;
      return 0;
   end Rank_Of;
   --  Where the document is among the pages, 0 if it is not one.

   function Row_Of (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Row in 1 .. Item.Source_Total loop
         if Item.Source_Order (Row) = Which then
            return Row;
         end if;
      end loop;
      return 0;
   end Row_Of;
   --  Where the source is in the list of them, 0 if it is not.

   procedure Build_Order (Item : in out Session);
   --  Find the documents, in the order kept, and the sources.

   procedure Build_Order (Item : in out Session) is
      Ordered : Items.Id_List;
   begin
      Item.Write_Count := 0;
      Item.Source_Total := 0;
      Items.Load_Order (Item.Store, Item.Current, Ordered);
      for Place in 1 .. Ordered.Count loop
         for Which in Items.Slot loop
            if Windows.Is_Assigned (Item.Windows (Which))
              and then Windows.Details (Item.Windows (Which)).Key
                       = Ordered.Keys (Place)
            then
               if Is_Note (Item, Which) then
                  Item.Write_Count := Item.Write_Count + 1;
                  Item.Write_Order (Item.Write_Count) := Which;
               else
                  Item.Source_Total := Item.Source_Total + 1;
                  Item.Source_Order (Item.Source_Total) := Which;
               end if;
            end if;
         end loop;
      end loop;
   end Build_Order;

   procedure Keep_Order (Item : in out Session);
   --  Write the order of the documents to the database.

   procedure Keep_Order (Item : in out Session) is
      Keys : Items.Id_Array (1 .. Item.Write_Count);
   begin
      for Rank in Keys'Range loop
         Keys (Rank) :=
           Windows.Details (Item.Windows (Item.Write_Order (Rank))).Key;
      end loop;
      Items.Save_Order (Item.Store, Keys);
      Projects.Touch (Item.Store, Item.Current);
   end Keep_Order;

   procedure Reorder
     (Order : in out Slot_Array; From, To : Positive);
   --  Move the From-th to the To-th place, the others making room.

   procedure Reorder
     (Order : in out Slot_Array; From, To : Positive)
   is
      Moved : constant Items.Slot := Order (From);
   begin
      if From < To then
         for Place in From .. To - 1 loop
            Order (Place) := Order (Place + 1);
         end loop;
      else
         for Place in reverse To + 1 .. From loop
            Order (Place) := Order (Place - 1);
         end loop;
      end if;
      Order (To) := Moved;
   end Reorder;

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
         Grips.Set_Shadow (Row.Row, Style.Colors.Shadow);
      else
         --  Its shadow is the ground: unseen, but the face is the same
         --  size.
         Grips.Set_Fill (Row.Row, Style.Row_Fill);
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
      for Row in 1 .. Item.Source_Total loop
         declare
            Other : constant Items.Id :=
              Windows.Details (Item.Windows (Item.Source_Order (Row))).Key;
         begin
            for Each of Item.Link_Set.Links (1 .. Item.Link_Set.Count) loop
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

   procedure Refresh (Item : in out Session);
   --  Show the pages and the rows of the lists as the items and their
   --  order are now.

   procedure Refresh (Item : in out Session) is
   begin
      for Rank in Items.Slot loop
         declare
            Each : Doc_Page renames Item.Pages (Rank);
            Row  : Index_Row renames Item.Doc_Rows (Rank);
         begin
            if Rank <= Item.Write_Count then
               declare
                  Which : constant Items.Slot := Item.Write_Order (Rank);
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
                  Labels.Set_Text
                    (Row.Caption, Fitted (Title_Of (Item, Which)));
                  Choose_Row
                    (Row,
                     (if Item.Drag_Row /= 0 and then Item.Drag_Moved
                      then Rank = Item.Drag_Target
                      else Widgets.Has_Focus (Each.Text)));
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
            Widgets.Set_Visible (Each.Box, Rank <= Item.Write_Count);
            Widgets.Set_Visible (Row.Row, Rank <= Item.Write_Count);
         end;
      end loop;
      Widgets.Set_Visible (Item.Docs_None, Item.Write_Count = 0);

      for Row in Items.Slot loop
         declare
            Each : Index_Row renames Item.Source_Rows (Row);
         begin
            if Row <= Item.Source_Total then
               declare
                  Which : constant Items.Slot := Item.Source_Order (Row);
               begin
                  Labels.Set_Text
                    (Each.Caption, Fitted (Title_Of (Item, Which)));
                  UI.Widgets.Panels.Set_Fill
                    (Each.Tag, Canvas_Items.Source_Ink (Item, Which));
                  Choose_Row
                    (Each,
                     Item.Pinned_Slot = Which
                     or else Readers.Details (Item.Readers (Which)).State
                             = Items.Open);
               end;
            end if;
            Widgets.Set_Visible (Each.Row, Row <= Item.Source_Total);
         end;
      end loop;
      Widgets.Set_Visible (Item.Sources_None, Item.Source_Total = 0);
   end Refresh;

   procedure Go_To (Item : in out Session; Rank : Positive);
   --  Scroll the pages to the Rankth.

   procedure Go_To (Item : in out Session; Rank : Positive) is
      Pixels : constant Float := Widgets.Density (Item.Widgets);
   begin
      Scrollers.Scroll_To
        (Item.Pages_Scroll,
         (Widgets.Top_Of (Item.Pages (Rank).Box)
          - Widgets.Top_Of (Item.Pages_Content)) / Pixels
         - Style.Page_Margin / 2.0);
   end Go_To;

   --  The windows of the sources

   function Picture_Of (Item : Session; Which : Items.Slot) return String is
     (Items.Image_File
        (Item.Store, Item.Current,
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
      if Items.Has_Words (Item.Store, Key) then
         declare
            Found : Vision.Result;
         begin
            Items.Load_Words (Item.Store, Key, Found);
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
        (Item.Readers (Which), Details,
         (Left  => 0.0, Top => 0.0,
          Width => Readers.Window_Width, Height => Readers.Window_Height),
         (if Details.Captured_At > 0 then Picture_Of (Item, Which) else ""));
      Item.Reader_Placed (Which) := False;
      Show_Kept (Item, Which, Item.Readers (Which), Item.Reader_Sync (Which));
   end Make_Reader;

   procedure Open_Reader (Item : in out Session; Which : Items.Slot);
   --  Show the source's window, over the others, where it was left or, if
   --  it has not been shown, near the right.

   procedure Open_Reader (Item : in out Session; Which : Items.Slot) is
      Each   : Readers.Reader renames Item.Readers (Which);
      Pixels : constant Float := Widgets.Density (Item.Widgets);
   begin
      if not Item.Reader_Placed (Which) then
         declare
            Placed : Natural := 0;
            Step   : Float;
            Wide   : constant Float :=
              Widgets.Width_Of (Item.Write_View) / Pixels;
            High   : constant Float :=
              Widgets.Height_Of (Item.Write_View) / Pixels;
         begin
            for Placed_Already of Item.Reader_Placed loop
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
            Item.Reader_Placed (Which) := True;
         end;
      end if;
      Readers.Set_State (Each, Items.Open);
      Readers.Place (Each);
      Readers.Bring_To_Front (Each);
   end Open_Reader;

   procedure Unpin (Item : in out Session; Reopen : Boolean);
   --  Let go of the pinned source: close it, or show it in a window.

   procedure Unpin (Item : in out Session; Reopen : Boolean) is
      Which : constant Natural := Item.Pinned_Slot;
   begin
      if Which = 0 then
         return;
      end if;
      Readers.Release (Item.Pane_Reader);
      Item.Pinned_Slot := 0;
      Widgets.Set_Visible (Item.Pane, False);
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
      Readers.Set_State (Item.Readers (Which), Items.Closed);
      Readers.Assign
        (Item.Pane_Reader, Details,
         (Left  => 0.0, Top => 0.0,
          Width => Readers.Window_Width, Height => Readers.Window_Height),
         (if Details.Captured_At > 0 then Picture_Of (Item, Which) else ""));
      Show_Kept (Item, Which, Item.Pane_Reader, Item.Pane_Sync);
      Readers.Set_Zoom (Item.Pane_Reader, Readers.Zoom (Item.Readers (Which)));
      Readers.Set_State (Item.Pane_Reader, Items.Open);
      Item.Pinned_Slot := Which;
      Widgets.Set_Visible (Item.Pane, True);
      --  As wide as it was left, unless that does not fit the view.
      Item.Pane_Wide :=
        Float'Max
          (Style.Pane_Least,
           Float'Min
             (Item.Pane_Wide,
              Style.Pane_Share * Widgets.Width_Of (Item.Write_View)
              / Widgets.Density (Item.Widgets)));
      Yoga.Nodes.Set_Width
        (Widgets.Node (Item.Pane),
         Item.Pane_Wide * Widgets.Density (Item.Widgets));
   end Pin;

   procedure Close_Menu (Item : in out Session);
   --  Put the menu of sources away.

   procedure Close_Menu (Item : in out Session) is
   begin
      Item.Menu_Page := 0;
      Widgets.Set_Visible (Item.Menu, False);
   end Close_Menu;

   procedure Open_Menu (Item : in out Session; Rank : Positive);
   --  Show the menu of the sources the Rankth page's document is linked
   --  to, under its button; or put it away, if it is shown already.

   procedure Open_Menu (Item : in out Session; Rank : Positive) is
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Item.Write_Order (Rank))).Key;
   begin
      if Item.Menu_Page = Rank then
         Close_Menu (Item);
         return;
      end if;
      Item.Menu_Count := 0;
      for Row in 1 .. Item.Source_Total loop
         declare
            Which : constant Items.Slot := Item.Source_Order (Row);
         begin
            if Items.Is_Linked
                 (Item.Store, Key, Windows.Details (Item.Windows (Which)).Key)
            then
               Item.Menu_Count := Item.Menu_Count + 1;
               Item.Menu_Slots (Item.Menu_Count) := Which;
               Buttons.Set_Label
                 (Item.Menu_Rows (Item.Menu_Count),
                  Fitted (Title_Of (Item, Which)));
            end if;
         end;
      end loop;
      for Row in Items.Slot loop
         Widgets.Set_Visible (Item.Menu_Rows (Row), Row <= Item.Menu_Count);
      end loop;
      Widgets.Set_Visible (Item.Menu_None, Item.Menu_Count = 0);
      Item.Menu_Page := Rank;
      Item.Menu_Left := -1.0E9;
      Widgets.Set_Visible (Item.Menu, True);
      Widgets.Raise_To_Front (Item.Menu);
   end Open_Menu;

   procedure Toggle_Source (Item : in out Session; Which : Items.Slot);
   --  A source's row was clicked: open its window, or close it.

   procedure Toggle_Source (Item : in out Session; Which : Items.Slot) is
   begin
      if Item.Pinned_Slot = Which then
         Unpin (Item, Reopen => False);
      elsif Readers.Details (Item.Readers (Which)).State = Items.Open then
         Readers.Set_State (Item.Readers (Which), Items.Closed);
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
              (Item.Store, Windows.Details (Item.Windows (Which)).Key, Kept);
            Windows.Set_Marks (Item.Windows (Which), Kept);
            Sync := (Own  => Own,
                     Peer => Windows.Marks_Version (Item.Windows (Which)));
            Projects.Touch (Item.Store, Item.Current);
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
      Item.Drag_Row := 0;
      Refresh (Item);
   end Enter;

   procedure Show (Item : in out Session; To : Modes) is
   begin
      Item.Mode := To;
      Close_Menu (Item);
      Widgets.Set_Visible (Item.Canvas_View, To = Canvas);
      Widgets.Set_Visible (Item.Write_View, To = Write);
      Buttons.Set_Selected (Item.Canvas_Tab, To = Canvas);
      Buttons.Set_Selected (Item.Write_Tab, To = Write);
      Widgets.Set_Visible (Item.Tools, To = Canvas);
      Widgets.Set_Visible (Item.Tool_List, To = Canvas);
      Canvas_Items.Show_Dock (Item);
      if To = Write then
         Refresh (Item);
      end if;
      Widgets.Layout (Item.Widgets, Item.Target);
      if To = Canvas then
         Canvas_Items.Sync (Item);
      end if;
   end Show;

   procedure Leave (Item : in out Session) is
   begin
      Unpin (Item, Reopen => False);
      for Which in Items.Slot loop
         if Readers.Is_Assigned (Item.Readers (Which)) then
            Readers.Release (Item.Readers (Which));
         end if;
      end loop;
      Item.Write_Count := 0;
      Item.Source_Total := 0;
      Item.Drag_Row := 0;
      Refresh (Item);
      Show (Item, Canvas);
   end Leave;

   procedure Added (Item : in out Session; Which : Items.Slot) is
   begin
      if Is_Note (Item, Which) then
         Item.Write_Count := Item.Write_Count + 1;
         Item.Write_Order (Item.Write_Count) := Which;
         Refresh (Item);
         if Item.Mode = Write then
            Widgets.Layout (Item.Widgets, Item.Target);
            Fit (Item);
            Go_To (Item, Item.Write_Count);
            Widgets.Focus (Item.Pages (Item.Write_Count).Text);
         end if;
      else
         Item.Source_Total := Item.Source_Total + 1;
         Item.Source_Order (Item.Source_Total) := Which;
         Make_Reader (Item, Which);
         Refresh (Item);
      end if;
   end Added;

   procedure Removed (Item : in out Session; Which : Items.Slot) is
   begin
      if Is_Note (Item, Which) then
         declare
            Rank : constant Natural := Rank_Of (Item, Which);
         begin
            if Rank > 0 then
               for Place in Rank .. Item.Write_Count - 1 loop
                  Item.Write_Order (Place) := Item.Write_Order (Place + 1);
               end loop;
               Item.Write_Count := Item.Write_Count - 1;
            end if;
         end;
      else
         declare
            Row : constant Natural := Row_Of (Item, Which);
         begin
            if Item.Pinned_Slot = Which then
               Unpin (Item, Reopen => False);
            end if;
            if Readers.Is_Assigned (Item.Readers (Which)) then
               Readers.Release (Item.Readers (Which));
            end if;
            if Row > 0 then
               for Place in Row .. Item.Source_Total - 1 loop
                  Item.Source_Order (Place) := Item.Source_Order (Place + 1);
               end loop;
               Item.Source_Total := Item.Source_Total - 1;
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
      if Readers.Is_Assigned (Item.Readers (Which)) then
         Show (Item.Readers (Which), Item.Reader_Sync (Which));
      end if;
      if Item.Pinned_Slot = Which then
         Show (Item.Pane_Reader, Item.Pane_Sync);
      end if;
   end Picture_Taken;

   procedure Words_Found
     (Item : in out Session; Which : Items.Slot; Found : Vision.Result) is
   begin
      if Readers.Is_Assigned (Item.Readers (Which)) then
         Readers.Set_Recognized (Item.Readers (Which), Found);
      end if;
      if Item.Pinned_Slot = Which then
         Readers.Set_Recognized (Item.Pane_Reader, Found);
      end if;
   end Words_Found;

   procedure Move (Item : in out Session; From, To : Positive) is
   begin
      Reorder (Item.Write_Order, From, To);
      Keep_Order (Item);
      Refresh (Item);
   end Move;

   --  What is clicked and dragged

   procedure Take_Documents (Item : in out Session);
   --  The list of documents: a row dragged is put elsewhere in the order;
   --  one clicked takes the pages to its page.

   procedure Take_Documents (Item : in out Session) is
      Clicked      : Boolean;
      Across, Down : Float;
      Was_Moved    : Boolean := False;
   begin
      if Item.Drag_Row = 0 then
         for Row in 1 .. Item.Write_Count loop
            if Grips.Is_Dragging (Item.Doc_Rows (Row).Row) then
               Item.Drag_Row := Row;
               Item.Drag_Total := 0.0;
               Item.Drag_Moved := False;
               Item.Drag_Target := Row;
               Item.Drag_Start := Item.Write_Order;
            end if;
         end loop;
      end if;
      if Item.Drag_Row /= 0 then
         Grips.Take_Drag (Item.Doc_Rows (Item.Drag_Row).Row, Across, Down);
         Item.Drag_Total := Item.Drag_Total + Down;
         if abs Item.Drag_Total >= Drag_Threshold then
            Item.Drag_Moved := True;
         end if;
         if Item.Drag_Moved then
            declare
               Target : constant Integer :=
                 Integer'Max
                   (1, Integer'Min
                         (Item.Write_Count,
                          Item.Drag_Row
                          + Integer
                              (Float'Rounding
                                 (Item.Drag_Total / Style.Index_Pitch))));
            begin
               if Target /= Item.Drag_Target then
                  Item.Drag_Target := Target;
                  Item.Write_Order := Item.Drag_Start;
                  Reorder (Item.Write_Order, Item.Drag_Row, Target);
                  Refresh (Item);
               end if;
            end;
         end if;
         if not Grips.Is_Dragging (Item.Doc_Rows (Item.Drag_Row).Row) then
            Was_Moved := Item.Drag_Moved;
            if Was_Moved then
               Keep_Order (Item);
            end if;
            Item.Drag_Row := 0;
            Item.Drag_Moved := False;
            Item.Drag_Target := 0;
            Refresh (Item);
         end if;
      end if;
      for Row in 1 .. Item.Write_Count loop
         Grips.Take_Click (Item.Doc_Rows (Row).Row, Clicked);
         if Clicked and then not Was_Moved and then Item.Drag_Row = 0 then
            Go_To (Item, Row);
         end if;
      end loop;
   end Take_Documents;

   procedure Take_Sources (Item : in out Session);
   --  The list of sources, and their windows and the pane.

   procedure Take_Sources (Item : in out Session) is
      Clicked : Boolean;
      Action  : Readers.Actions;
   begin
      for Row in 1 .. Item.Source_Total loop
         Grips.Take_Click (Item.Source_Rows (Row).Row, Clicked);
         if Clicked then
            Toggle_Source (Item, Item.Source_Order (Row));
            Refresh (Item);
            return;
         end if;
      end loop;
      for Which in Items.Slot loop
         if Readers.Is_Assigned (Item.Readers (Which)) then
            Readers.Poll (Item.Readers (Which), Action);
            case Action is
               when Readers.None =>
                  null;
               when Readers.Close =>
                  Readers.Set_State (Item.Readers (Which), Items.Closed);
                  Refresh (Item);
               when Readers.Toggle_Pin =>
                  Pin (Item, Which);
                  Refresh (Item);
                  return;
            end case;
         end if;
      end loop;
      if Readers.Is_Assigned (Item.Pane_Reader) then
         Readers.Poll (Item.Pane_Reader, Action);
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
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Across, Down : Float;
   begin
      Grips.Take_Drag (Item.Pane_Edge, Across, Down);
      if Across /= 0.0 then
         declare
            Most : constant Float :=
              Float'Max
                (Style.Pane_Least,
                 Widgets.Width_Of (Item.Write_View) / Pixels
                 - Style.Sidebar_Width - 2.0 * Style.Sidebar_Margin
                 - Style.Page_Min_Width);
         begin
            Item.Pane_Wide :=
              Float'Min (Most, Float'Max (Style.Pane_Least,
                                          Item.Pane_Wide - Across));
            Set_Width (Widgets.Node (Item.Pane), Item.Pane_Wide * Pixels);
            Widgets.Request_Layout (Item.Pane);
         end;
      end if;
   end Take_Pane;

   procedure Take_Rename (Item : in out Session; Rank : Positive);
   --  Begin renaming a document at a double press on its title, and end
   --  it at Return or when the field is left.

   procedure Take_Rename (Item : in out Session; Rank : Positive) is
      Each    : Doc_Page renames Item.Pages (Rank);
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
      Buttons.Take_Click (Item.Docs_Add, Clicked);
      if Clicked then
         Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
         return;
      end if;
      for Row in 1 .. Item.Menu_Count loop
         Buttons.Take_Click (Item.Menu_Rows (Row), Clicked);
         if Clicked then
            Pin (Item, Item.Menu_Slots (Row));
            Close_Menu (Item);
            Refresh (Item);
            return;
         end if;
      end loop;
      for Rank in 1 .. Item.Write_Count loop
         Take_Rename (Item, Rank);
         Buttons.Take_Click (Item.Pages (Rank).Sources_Button, Clicked);
         if Clicked then
            Open_Menu (Item, Rank);
            return;
         end if;
         Buttons.Take_Click (Item.Pages (Rank).Mic_Button, Clicked);
         if Clicked then
            Canvas_Items.Toggle_Dictation (Item, Item.Write_Order (Rank));
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
      Pixels : constant Float := Widgets.Density (Item.Widgets);

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
      if Item.Menu_Page /= 0 then
         declare
            Menu : constant Items.Frame :=
              (Left   => Widgets.Left_Of (Item.Menu),
               Top    => Widgets.Top_Of (Item.Menu),
               Width  => Widgets.Width_Of (Item.Menu),
               Height => Widgets.Height_Of (Item.Menu));
         begin
            --  Its own button, pressed, is to put it away when clicked.
            if (X * Pixels not in Menu.Left .. Menu.Left + Menu.Width
                or else Y * Pixels not in Menu.Top .. Menu.Top + Menu.Height)
              and then not Widgets.Contains
                             (Item.Pages (Item.Menu_Page).Sources_Button,
                              X * Pixels, Y * Pixels)
            then
               Close_Menu (Item);
            end if;
         end;
      end if;
      for Each of Item.Readers loop
         Away (Each);
      end loop;
      Away (Item.Pane_Reader);
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
                  and then Widgets.Has_Focus (Item.Pages (Rank).Text));
               if Rank > 0 then
                  declare
                     Busy : constant Boolean :=
                       Windows.Dictation (Item.Windows (Which))
                       in Windows.Preparing | Windows.Listening;
                     Mic  : Buttons.Button renames
                       Item.Pages (Rank).Mic_Button;
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
                       (Item.Pages (Rank).Words,
                        Count_Image (Words)
                        & (if Words = 1 then " word" else " words"));
                     Labels.Set_Text
                       (Item.Doc_Rows (Rank).Count, Count_Image (Words));
                  end;
                  Buttons.Set_Badge
                    (Item.Pages (Rank).Sources_Button,
                     Linked_Sources (Item, Which));
                  if Item.Drag_Row = 0 then
                     Choose_Row
                       (Item.Doc_Rows (Rank),
                        Widgets.Has_Focus (Item.Pages (Rank).Text));
                  end if;
                  Labels.Set_Text
                    (Item.Pages (Rank).Heading,
                     Fitted (Title_Of (Item, Which)));
                  Labels.Set_Text
                    (Item.Doc_Rows (Rank).Caption,
                     Fitted (Title_Of (Item, Which)));
               end if;
            end;
         elsif Is_Source (Item, Which)
           and then Readers.Is_Assigned (Item.Readers (Which))
         then
            Keep_Title (Item, Which, Item.Readers (Which));
            Readers.Set_Tag
              (Item.Readers (Which), Canvas_Items.Source_Ink (Item, Which));
            Keep_Marks
              (Item, Which, Item.Readers (Which), Item.Reader_Sync (Which));
            declare
               Row : constant Natural := Row_Of (Item, Which);
            begin
               if Row > 0 then
                  Labels.Set_Text
                    (Item.Source_Rows (Row).Caption,
                     Fitted (Title_Of (Item, Which)));
               end if;
            end;
         end if;
      end loop;
      if Item.Pinned_Slot /= 0 then
         Keep_Title (Item, Item.Pinned_Slot, Item.Pane_Reader);
         Readers.Set_Tag
           (Item.Pane_Reader,
            Canvas_Items.Source_Ink (Item, Item.Pinned_Slot));
         Keep_Marks
           (Item, Item.Pinned_Slot, Item.Pane_Reader, Item.Pane_Sync);
      end if;
   end Update;

   procedure Fit (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Changed : Boolean;
      Moved   : Boolean := False;
   begin
      --  The text is as tall as it needs to be, at the width the sheet
      --  has: laying out again after a change of either settles it.
      for Pass in 1 .. 3 loop
         Changed := False;
         declare
            Room : constant Float :=
              Widgets.Width_Of (Item.Pages_Content) / Pixels
              - 2.0 * Style.Page_Margin;
            Wide : constant Float :=
              Float'Max (Style.Page_Min_Width,
                         Float'Min (Style.Page_Width, Room));
         begin
            for Rank in 1 .. Item.Write_Count loop
               declare
                  Each : Doc_Page renames Item.Pages (Rank);
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
            end loop;
         end;
         exit when not Changed;
         Widgets.Layout (Item.Widgets, Item.Target);
      end loop;

      --  The menu stays under its button, its right edge in line with the
      --  button's, as the pages are scrolled.
      if Item.Menu_Page /= 0 then
         declare
            Button : Buttons.Button renames
              Item.Pages (Item.Menu_Page).Sources_Button;
            Left   : constant Float :=
              (Widgets.Left_Of (Button) + Widgets.Width_Of (Button)
               - Widgets.Left_Of (Item.Write_View)) / Pixels
              - Style.Menu_Width;
            Top    : constant Float :=
              (Widgets.Top_Of (Button) + Widgets.Height_Of (Button)
               - Widgets.Top_Of (Item.Write_View)) / Pixels;
         begin
            if Left /= Item.Menu_Left or else Top /= Item.Menu_Top then
               Item.Menu_Left := Left;
               Item.Menu_Top := Top;
               Set_Position
                 (Widgets.Node (Item.Menu), Yoga.Left,
                  Float'Rounding (Left * Pixels));
               Set_Position
                 (Widgets.Node (Item.Menu), Yoga.Top,
                  Float'Rounding (Top * Pixels));
               Widgets.Request_Layout (Item.Menu);
               Widgets.Layout (Item.Widgets, Item.Target);
            end if;
         end;
      end if;

      --  The caret, where it has gone, is kept in view.
      for Rank in 1 .. Item.Write_Count loop
         declare
            Each : Doc_Page renames Item.Pages (Rank);
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
                          Widgets.Top_Of (Item.Pages_Scroll)
                          + Reveal_Margin * Pixels;
                        Bottom : constant Float :=
                          Widgets.Top_Of (Item.Pages_Scroll)
                          + Widgets.Height_Of (Item.Pages_Scroll)
                          - Reveal_Margin * Pixels;
                        Offset : constant Float :=
                          Scrollers.Offset (Item.Pages_Scroll);
                     begin
                        Editors.Caret_Box (Each.Text, X, Y, Wide, High);
                        if Y < Top then
                           Scrollers.Scroll_To
                             (Item.Pages_Scroll, Offset - (Top - Y) / Pixels);
                           Moved := True;
                        elsif Y + High > Bottom then
                           Scrollers.Scroll_To
                             (Item.Pages_Scroll,
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
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Fit;

end Viewer.Writing;
