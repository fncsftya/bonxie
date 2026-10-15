with Ada.Strings.Fixed;
with Items;
with Items.Records;
with Previews;
with Pomarine.Text_Areas;
with Pomarine.Widgets;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Viewer.Style;

package body Viewer.Recent is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
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
      Row : constant Natural := Item.Home_View.Editing;
   begin
      if Row /= 0 then
         Item.Home_View.Editing := 0;
         Widgets.Remove (Item.Home_View.Edit_Panel);
         Show_Name (Item.Home_View.Cards (Row), True);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
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
      Items.Records.Load
        (Item.Nav.Store, Item.Home_View.Row_Keys (Row), Found);
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
        (Item.Home_View.Cards (Row).Meta,
         Counted (Documents, "document", "documents") & " " & Middle_Dot
         & " "
         & Counted (Sources, "source", "sources"));
      Previews.Set_Cards (Item.Home_View.Cards (Row).Picture,
                          Shown (1 .. Drawn));
   end Show_Contents;

   procedure Refresh (Item : in out Session) is
   begin
      Cancel_Edit (Item);
      Projects.Recent (Item.Nav.Store, Item.Home_View.Listed);
      for I in Item.Home_View.Cards'Range loop
         if I <= Item.Home_View.Listed.Count then
            declare
               Name : constant String :=
                 Projects.Titles.To_String
                   (Item.Home_View.Listed.Items (I).Title);
            begin
               --  Cut to fit the label.
               Labels.Set_Text
                 (Item.Home_View.Cards (I).Title,
                  Name (Name'First ..
                        Name'First - 1
                        + Natural'Min (Name'Length, Labels.Text_Capacity)));
            end;
            Item.Home_View.Row_Keys (I) := Item.Home_View.Listed.Items (I).Key;
            Show_Contents (Item, I);
         end if;
         Widgets.Set_Visible (Item.Home_View.Cards (I).Panel,
                              I <= Item.Home_View.Listed.Count);
      end loop;
      --  The outline to make one stands in for them all when there are
      --  none.
      Widgets.Set_Visible (Item.Home_View.No_Rows, False);
   end Refresh;

   procedure Begin_Rename (Item : in out Session; Row : Positive) is
   begin
      Cancel_Edit (Item);
      Item.Home_View.Editing := Row;
      Show_Name (Item.Home_View.Cards (Row), False);

      --  Built again each time, top down: it is taken out of the card it
      --  was in, with what is in it.
      Widgets.Add (Item.Home_View.Cards (Row).Info, Item.Home_View.Edit_Panel);
      Widgets.Add (Item.Home_View.Edit_Panel, Item.Title_Edit.Edit_Field);
      Widgets.Add (Item.Home_View.Edit_Panel, Item.Home_View.Ok_Button);
      Widgets.Add (Item.Home_View.Edit_Panel, Item.Home_View.Cancel_Button);
      Layouts.Set_Layout
        (Item.Home_View.Edit_Panel, Flow => Layouts.Row, Align => Layouts.Center, Grow => 1.0, Width => 0.0,
         Gap => Style.Row_Gap);
      Layouts.Set_Layout (Item.Title_Edit.Edit_Field, Grow => 1.0, Width => 0.0, Height => Style.Card_Button);
      Layouts.Set_Layout
        (Item.Home_View.Ok_Button, Width => Style.Ok_Width, Height => Style.Card_Button);
      Layouts.Set_Layout
        (Item.Home_View.Cancel_Button, Width => Style.Cancel_Width, Height => Style.Card_Button);

      Docs.Load
        (Item.Title_Edit.Edit_Doc,
         Projects.Titles.To_String (Item.Home_View.Listed.Items (Row).Title));
      Text_Fields.Attach (Item.Title_Edit.Edit_Field,
                          Item.Title_Edit.Edit_Doc'Unchecked_Access);
      Pomarine.Text_Areas.Select_All
        (Text_Fields.Area (Item.Title_Edit.Edit_Field).all);
      Widgets.Focus (Item.Title_Edit.Edit_Field);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Begin_Rename;

   procedure Accept_Rename (Item : in out Session) is
      Content : constant String := Docs.Whole (Item.Title_Edit.Edit_Doc);
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
      if Last >= First and then Item.Home_View.Editing /= 0 then
         Projects.Rename
           (Item.Nav.Store, Item.Home_View.Row_Keys (Item.Home_View.Editing),
            Content (First .. Natural'Min
                                (Last, First + Projects.Title_Capacity - 1)));
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Accept_Rename;

end Viewer.Recent;
