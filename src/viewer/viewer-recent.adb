with Home_VM;
with Items;
with Items.Records;
with Previews;
with Pomarine.Text_Areas;
with Pomarine.View_Models;
with Pomarine.Widgets;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Viewer.Style;

package body Viewer.Recent is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Docs renames Texts.Documents;
   package Bindings renames Pomarine.Widgets.Bindings;

   use type Items.Kinds;
   use type Items.States;

   procedure Show_Name (Card : in out Project_Card; To : Boolean);
   --  Show the card's name and buttons, or hide them for the field to rename it.

   procedure Show_Name (Card : in out Project_Card; To : Boolean) is
   begin
      Widgets.Set_Visible (Card.Name, To);
      Widgets.Set_Visible (Card.Rename, To);
      Widgets.Set_Visible (Card.Delete, To);
   end Show_Name;

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
            Labels.Set_Text (Item.Home_View.Cards (I).Title, Home_VM.Title (Model, I));
            --  The picture of its canvas has no words of its own.
            Widgets.Set_Accessible_Name (Item.Home_View.Cards (I).Peek, "Open " & Home_VM.Title (Model, I));
            Labels.Set_Text (Item.Home_View.Cards (I).Meta, Home_VM.Meta (Model, I));
            Show_Picture (Item, I);
         end if;
         Widgets.Set_Visible (Item.Home_View.Cards (I).Panel, I <= Home_VM.Count (Model));
      end loop;
      --  The outline to make one stands in for them all when there are none.
      Widgets.Set_Visible (Item.Home_View.No_Rows, False);
   end Show_Rows;

   --  The field to rename a project is in the card of the one being renamed, in place of its name and
   --  buttons, which are hidden.
   procedure Show_Editing (Item : in out Session);

   procedure Show_Editing (Item : in out Session) is
      Model : Home_VM.View_Model renames Item.Home_Model.Model;
      Now   : constant Natural := Home_VM.Editing (Model);
      Was   : Natural renames Item.Home_Model.Editing;
   begin
      if Was = Now then
         return;
      end if;
      if Was /= 0 then
         Widgets.Remove (Item.Home_View.Edit_Panel);
         Show_Name (Item.Home_View.Cards (Was), True);
      end if;
      Was := Now;
      if Now /= 0 then
         Show_Name (Item.Home_View.Cards (Now), False);

         --  Built again each time, top down: it is taken out of the card it was in, with what is in it.
         Layouts.Add (Item.Home_View.Cards (Now).Info, Item.Home_View.Edit_Panel,
                      (Flow => Layouts.Row, Align => Layouts.Center, Grow => 1.0, Width => 0.0, Gap => Style.Row_Gap,
                       others => <>));
         Layouts.Add (Item.Home_View.Edit_Panel, Item.Title_Edit.Edit_Field,
                      (Grow => 1.0, Width => 0.0, Height => Style.Card_Button, others => <>));
         Layouts.Add (Item.Home_View.Edit_Panel, Item.Home_View.Ok_Button,
                      (Width => Style.Ok_Width, Height => Style.Card_Button, others => <>));
         Layouts.Add (Item.Home_View.Edit_Panel, Item.Home_View.Cancel_Button,
                      (Width => Style.Cancel_Width, Height => Style.Card_Button, others => <>));

         Bindings.Show (Item.Home_Model.Link, Item.Title_Edit.Edit_Doc, Home_VM.Draft (Model));
         Text_Fields.Attach (Item.Title_Edit.Edit_Field, Item.Title_Edit.Edit_Doc'Unchecked_Access);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (Item.Title_Edit.Edit_Field).all);
         --  Not before the buttons of the field are on (see Revalidate).
         Widgets.Revalidate (Item.Root.Widgets);
         Widgets.Focus (Item.Title_Edit.Edit_Field);
      end if;
   end Show_Editing;

   procedure Sync (Item : in out Session) is
      Model : Home_VM.View_Model renames Item.Home_Model.Model;
   begin
      --  What was typed is the draft.
      if Bindings.Edited (Item.Home_Model.Link, Item.Title_Edit.Edit_Doc) and then Home_VM.Editing (Model) /= 0 then
         Home_VM.Set_Draft (Model, Docs.Whole (Item.Title_Edit.Edit_Doc));
      end if;
      if Home_Binding.Changed (Item.Home_Model.Seen, Model) then
         --  A field goes before the cards it is in are set again.
         if Home_VM.Editing (Model) = 0 then
            Show_Editing (Item);
         end if;
         if Pomarine.View_Models.Changed (Item.Home_Model.Listed, Home_VM.Listed_Version (Model)) then
            Show_Rows (Item);
         end if;
         Show_Editing (Item);
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

end Viewer.Recent;
