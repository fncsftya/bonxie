with Ada.Strings.Fixed;
with Items;
with Previews;
with UI.Text_Areas;
with UI.Widgets;
with UI.Widgets.Labels;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Recent is

   package Widgets renames UI.Widgets;
   package Labels renames UI.Widgets.Labels;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Docs renames Texts.Documents;

   use type Items.Kinds;
   use type Items.States;

   procedure Show_Name (Card : in out Project_Card; To : Boolean);
   --  Show the card's name and buttons, or hide them for the field to
   --  rename it.

   procedure Show_Name (Card : in out Project_Card; To : Boolean) is
   begin
      Widgets.Set_Visible (Card.Name, To);
      Widgets.Set_Visible (Card.Rename, To);
      Widgets.Set_Visible (Card.Delete, To);
   end Show_Name;

   procedure Cancel_Edit (Item : in out Session) is
      Row : constant Natural := Item.Editing;
   begin
      if Row /= 0 then
         Item.Editing := 0;
         Widgets.Remove (Item.Edit_Panel);
         Show_Name (Item.Cards (Row), True);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Cancel_Edit;

   Middle_Dot : constant String :=
     [Character'Val (16#C2#), Character'Val (16#B7#)];
   --  In UTF-8.

   function Counted (Number : Natural; One, Many : String) return String is
     (Ada.Strings.Fixed.Trim (Number'Image, Ada.Strings.Both) & " "
      & (if Number = 1 then One else Many));

   procedure Show_Contents (Item : in out Session; Row : Positive);
   --  Say how many documents and sources the project of the Rowth card
   --  has, and show its canvas.

   procedure Show_Contents (Item : in out Session; Row : Positive) is
      Found     : Items.Info_List;
      Documents : Natural := 0;
      Sources   : Natural := 0;
      Shown     : Previews.Card_Array (1 .. Previews.Max_Shown);
      Drawn     : Natural := 0;
   begin
      Items.Load (Item.Store, Item.Row_Keys (Row), Found);
      for Each of Found.Items (1 .. Found.Count) loop
         if Each.Kind = Items.Source then
            Sources := Sources + 1;
         else
            Documents := Documents + 1;
         end if;
         if Each.State = Items.Open and then Drawn < Shown'Last then
            Drawn := Drawn + 1;
            Shown (Drawn) :=
              (Where => Each.Where, Kind => Each.Kind,
               Ink   => Style.Source_Ink (Sources));
         end if;
      end loop;
      Labels.Set_Text
        (Item.Cards (Row).Meta,
         Counted (Documents, "document", "documents") & " " & Middle_Dot
         & " "
         & Counted (Sources, "source", "sources"));
      Previews.Set_Cards (Item.Cards (Row).Picture, Shown (1 .. Drawn));
   end Show_Contents;

   procedure Refresh (Item : in out Session) is
   begin
      Cancel_Edit (Item);
      Projects.Recent (Item.Store, Item.Listed);
      for I in Item.Cards'Range loop
         if I <= Item.Listed.Count then
            declare
               Name : constant String :=
                 Projects.Titles.To_String (Item.Listed.Items (I).Title);
            begin
               --  Cut to fit the label.
               Labels.Set_Text
                 (Item.Cards (I).Title,
                  Name (Name'First ..
                        Name'First - 1
                        + Natural'Min (Name'Length, Labels.Text_Capacity)));
            end;
            Item.Row_Keys (I) := Item.Listed.Items (I).Key;
            Show_Contents (Item, I);
         end if;
         Widgets.Set_Visible (Item.Cards (I).Panel, I <= Item.Listed.Count);
      end loop;
      --  The outline to make one stands in for them all when there are
      --  none.
      Widgets.Set_Visible (Item.No_Rows, False);
   end Refresh;

   procedure Begin_Rename (Item : in out Session; Row : Positive) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Cancel_Edit (Item);
      Item.Editing := Row;
      Show_Name (Item.Cards (Row), False);

      --  Built again each time, top down: it is taken out of the card it
      --  was in, with what is in it.
      Widgets.Add (Item.Cards (Row).Info, Item.Edit_Panel);
      Widgets.Add (Item.Edit_Panel, Item.Edit_Field);
      Widgets.Add (Item.Edit_Panel, Item.Ok_Button);
      Widgets.Add (Item.Edit_Panel, Item.Cancel_Button);
      Set_Flex_Direction (Widgets.Node (Item.Edit_Panel), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Edit_Panel), Yoga.Center);
      Set_Flex_Grow (Widgets.Node (Item.Edit_Panel), 1.0);
      Set_Width (Widgets.Node (Item.Edit_Panel), 0.0);
      Set_Gap
        (Widgets.Node (Item.Edit_Panel), Yoga.All_Gutters,
         Style.Row_Gap * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Edit_Field), 1.0);
      Set_Width (Widgets.Node (Item.Edit_Field), 0.0);
      Set_Height
        (Widgets.Node (Item.Edit_Field), Style.Card_Button * Pixels);
      Set_Width
        (Widgets.Node (Item.Ok_Button), Style.Ok_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Ok_Button), Style.Card_Button * Pixels);
      Set_Width
        (Widgets.Node (Item.Cancel_Button), Style.Cancel_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Cancel_Button), Style.Card_Button * Pixels);

      Docs.Load
        (Item.Edit_Doc,
         Projects.Titles.To_String (Item.Listed.Items (Row).Title));
      Text_Fields.Attach (Item.Edit_Field, Item.Edit_Doc'Unchecked_Access);
      UI.Text_Areas.Select_All
        (Text_Fields.Area (Item.Edit_Field).all);
      Widgets.Focus (Item.Edit_Field);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Begin_Rename;

   procedure Accept_Rename (Item : in out Session) is
      Content : constant String := Docs.Whole (Item.Edit_Doc);
      First   : Positive := Content'First;
      Last    : Natural := Content'Last;
   begin
      --  Not spaces about it.
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if Last >= First and then Item.Editing /= 0 then
         Projects.Rename
           (Item.Store, Item.Row_Keys (Item.Editing),
            Content (First .. Natural'Min
                                (Last, First + Projects.Title_Capacity - 1)));
         Refresh (Item);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Accept_Rename;

end Viewer.Recent;
