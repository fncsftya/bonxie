with UI.Text_Areas;
with UI.Widgets;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Recent is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Docs renames Texts.Documents;

   procedure Cancel_Edit (Item : in out Session) is
      Row : constant Natural := Item.Editing;
   begin
      if Row /= 0 then
         Item.Editing := 0;
         Widgets.Remove (Item.Edit_Panel);
         Widgets.Set_Visible (Item.Recent_Rows (Row), True);
         Widgets.Set_Visible (Item.Rename_Buttons (Row), True);
         Widgets.Set_Visible (Item.Delete_Buttons (Row), True);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Cancel_Edit;

   procedure Refresh (Item : in out Session) is
   begin
      Cancel_Edit (Item);
      Projects.Recent (Item.Store, Item.Listed);
      for I in Item.Recent_Rows'Range loop
         if I <= Item.Listed.Count then
            declare
               Name : constant String :=
                 Projects.Titles.To_String (Item.Listed.Items (I).Title);
            begin
               --  Cut to fit the button.
               Buttons.Set_Label
                 (Item.Recent_Rows (I),
                  Name (Name'First ..
                        Name'First - 1
                        + Natural'Min (Name'Length, Buttons.Label_Capacity)));
            end;
            Item.Row_Keys (I) := Item.Listed.Items (I).Key;
         end if;
         Widgets.Set_Visible (Item.Row_Panels (I), I <= Item.Listed.Count);
      end loop;
      Widgets.Set_Visible (Item.No_Rows, Item.Listed.Count = 0);
   end Refresh;

   procedure Begin_Rename (Item : in out Session; Row : Positive) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Cancel_Edit (Item);
      Item.Editing := Row;
      Widgets.Set_Visible (Item.Recent_Rows (Row), False);
      Widgets.Set_Visible (Item.Rename_Buttons (Row), False);
      Widgets.Set_Visible (Item.Delete_Buttons (Row), False);

      --  Built again each time, top down: it is taken out of the row it
      --  was in, with what is in it.
      Widgets.Add (Item.Row_Panels (Row), Item.Edit_Panel);
      Widgets.Add (Item.Edit_Panel, Item.Edit_Field);
      Widgets.Add (Item.Edit_Panel, Item.Ok_Button);
      Widgets.Add (Item.Edit_Panel, Item.Cancel_Button);
      Set_Flex_Direction (Widgets.Node (Item.Edit_Panel), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Edit_Panel), 1.0);
      Set_Width (Widgets.Node (Item.Edit_Panel), 0.0);
      Set_Gap
        (Widgets.Node (Item.Edit_Panel), Yoga.All_Gutters,
         Style.Row_Gap * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Edit_Field), 1.0);
      Set_Width (Widgets.Node (Item.Edit_Field), 0.0);
      Set_Width
        (Widgets.Node (Item.Ok_Button), Style.Ok_Width * Pixels);
      Set_Width
        (Widgets.Node (Item.Cancel_Button), Style.Cancel_Width * Pixels);

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
