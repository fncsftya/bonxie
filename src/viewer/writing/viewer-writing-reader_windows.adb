with Items.Marks;
with Items.Sources;
with Items.Words;
with Viewer.Style;
with Pomarine.Widgets.Layouts;
with Viewer.Writing.Support;

package body Viewer.Writing.Reader_Windows is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Windows renames Items.Windows;

   use type Items.States;

   function Picture_Of (Item : Session; Which : Items.Slot) return String is
     (Items.Sources.Shown_File
        (Item.Nav.Store, Item.Opened.Current, Windows.Details (Item.Windows (Which))));

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
     (Item : Session; Which : Items.Slot; Shown : in out Readers.Reader) is
   begin
      if Projects.Titles.To_String (Readers.Details (Shown).Title)
         /= Support.Title_Of (Item, Which)
      then
         Readers.Set_Title (Shown, Support.Title_Of (Item, Which));
      end if;
   end Keep_Title;

end Viewer.Writing.Reader_Windows;
