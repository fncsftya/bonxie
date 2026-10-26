with Home_VM;
with Items;
with Items.Records;
with Previews;
with Pomarine.View_Models;
with Pomarine.UI;
with Pomarine.Widgets;
with View.Style;

package body View.Recent is

   package Widgets renames Pomarine.Widgets;
   package UI renames Pomarine.UI;

   use type Items.Kinds;
   use type Items.States;

   --  The canvas of the project of the Rowth card, as the windows that are open on it.
   procedure Show_Picture (Item : in out Session; Row : Positive);

   procedure Show_Picture (Item : in out Session; Row : Positive) is
      Found   : Items.Info_List;
      Sources : Natural := 0;
      Shown   : Previews.Card_Array (1 .. Previews.Max_Shown);
      Drawn   : Natural := 0;
   begin
      Items.Records.Load (Item.Nav.Store, Home_VM.Key_Of (Item.Home_Model.Model, Row), Found);
      for Each of Found.Slice loop
         if Each.Kind = Items.Source then
            Sources := Sources + 1;
         end if;
         if Each.State = Items.Open and then Drawn < Shown'Last then
            Drawn := Drawn + 1;
            Shown (Drawn) :=
              (Where => Each.Where, Kind => Each.Kind,
               Ink   => Style.Source_Ink (Sources));
         end if;
      end loop;
      Previews.Set_Cards (Item.Home_View.Cards (Row).Picture, Shown (1 .. Drawn));
   end Show_Picture;

   procedure Show_Rows (Item : in out Session);

   procedure Show_Rows (Item : in out Session) is
      Model : Home_VM.View_Model renames Item.Home_Model.Model;
   begin
      for I in Item.Home_View.Cards'Range loop
         if I <= Home_VM.Count (Model) then
            --  The picture of its canvas has no words of its own.
            Widgets.Set_Accessible_Name
              (UI.Widget_Of (Item.Forms (Home_Region).Screen.all, Item.Home_View.Cards (I).Peek).all,
               "Open " & Home_VM.Title (Model, I));
            Show_Picture (Item, I);
         end if;
      end loop;
      --  What the cards say, and which are there, are the view's.
   end Show_Rows;

   procedure Sync (Item : in out Session) is
      Model : Home_VM.View_Model renames Item.Home_Model.Model;
   begin
      if Pomarine.View_Models.Changed (Item.Home_Model.Seen, Home_VM.Version (Model)) then
         if Pomarine.View_Models.Changed (Item.Home_Model.Listed, Home_VM.Listed_Version (Model)) then
            Show_Rows (Item);
         end if;
         UI.Synchronize (Item.Forms (Home_Region).Screen.all);
         Widgets.Revalidate (Item.Root.Widgets);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Sync;

   procedure Refresh (Item : in out Session) is
   begin
      Home_VM.Execute (Item.Home_Model.Model, Home_VM.Refresh);
      Sync (Item);
   end Refresh;

   procedure Cancel_Edit (Item : in out Session) is
   begin
      if Home_VM.Can_Execute (Item.Home_Model.Model, Home_VM.Cancel_Rename) then
         Home_VM.Execute (Item.Home_Model.Model, Home_VM.Cancel_Rename);
         Sync (Item);
      end if;
   end Cancel_Edit;

end View.Recent;
