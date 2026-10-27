with Nav_VM;
with Pomarine.Native_Menus;
with Pomarine.UI;

package body View.Menus is

   package Menu_Bar renames Pomarine.Native_Menus;
   package Widgets renames Pomarine.Widgets;

   use type Pomarine.Widgets.Command_State;

   Ellipsis : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   --  In UTF-8.

   function Validate (Item : Session; Tag : Integer; Index : Natural) return Widgets.Command_State is
   begin
      for Each of Item.Forms loop
         if Each.Screen /= null and then Pomarine.UI.Owns_Tag (Each.Screen.all, Tag) then
            return Pomarine.UI.Command_State (Each.Screen.all, Tag, Index);
         end if;
      end loop;
      if Is_Nav_Tag (Tag) then
         declare
            State : constant Widgets.Command_State :=
              (if Nav_VM.Can_Execute (Item.Nav_Model.Model, Command_Of (Tag), Index)
               then Widgets.Enabled
               else Widgets.Disabled);
            What  : constant Nav_VM.Command := Command_Of (Tag);
         begin
            --  The menu ticks the view that is shown.
            if State = Widgets.Enabled
              and then Menu_Bar.Is_Installed (Item.Host.Menus)
              and then (case What is
                          when Nav_VM.Show_Outline => View_Mode (Item) = Outline,
                          when Nav_VM.Show_Canvas  => View_Mode (Item) = Canvas,
                          when Nav_VM.Show_Writing => View_Mode (Item) = Write,
                          when Nav_VM.Show_Publish => View_Mode (Item) = Publish,
                          when others              => False)
            then
               return Widgets.Ticked;
            end if;
            return State;
         end;
      end if;
      return Widgets.Enabled;
   end Validate;

   procedure Build (Item : in out Session) is
      File, Edit, Pane : Menu_Bar.Menu;
      Bar              : Menu_Bar.Menu_Bar renames Item.Host.Menus;
   begin
      Menu_Bar.Install (Bar);
      if not Menu_Bar.Is_Installed (Bar) then
         return;
      end if;

      Menu_Bar.Add_Menu (Bar, "File", File);
      Menu_Bar.Add_Item (Bar, File, "New Project", Tag_Of (Nav_VM.Start_Project), Key => "n");
      Menu_Bar.Add_Item (Bar, File, "Settings" & Ellipsis, Tag_Of (Nav_VM.Open_Settings), Key => ",");
      Menu_Bar.Add_Separator (Bar, File);
      Menu_Bar.Add_Item (Bar, File, "Close Project", Tag_Of (Nav_VM.Leave_Project), Key => "w");

      Menu_Bar.Add_Menu (Bar, "Edit", Edit);
      Menu_Bar.Add_Item (Bar, Edit, "Undo", Widgets.Edit_Undo, Key => "z");
      Menu_Bar.Add_Item (Bar, Edit, "Redo", Widgets.Edit_Redo, Key => "z", Shift => True);
      Menu_Bar.Add_Separator (Bar, Edit);
      Menu_Bar.Add_Item (Bar, Edit, "Cut", Widgets.Edit_Cut, Key => "x");
      Menu_Bar.Add_Item (Bar, Edit, "Copy", Widgets.Edit_Copy, Key => "c");
      Menu_Bar.Add_Item (Bar, Edit, "Paste", Widgets.Edit_Paste, Key => "v");
      Menu_Bar.Add_Item (Bar, Edit, "Select All", Widgets.Edit_Select_All, Key => "a");

      Menu_Bar.Add_Menu (Bar, "View", Pane);
      Menu_Bar.Add_Item (Bar, Pane, "Outline", Tag_Of (Nav_VM.Show_Outline), Key => "1");
      Menu_Bar.Add_Item (Bar, Pane, "Canvas", Tag_Of (Nav_VM.Show_Canvas), Key => "2");
      Menu_Bar.Add_Item (Bar, Pane, "Writing", Tag_Of (Nav_VM.Show_Writing), Key => "3");
      Menu_Bar.Add_Item (Bar, Pane, "Publish", Tag_Of (Nav_VM.Show_Publish), Key => "4");
      Menu_Bar.Add_Separator (Bar, Pane);
      Menu_Bar.Add_Item (Bar, Pane, "Items", Tag_Of (Nav_VM.Open_List));
   end Build;

   procedure Key_Taken (Item : in out Session; Event : Pomarine.Events.Event) is
      use type Pomarine.Events.Event_Kind;
      Tag : Integer := Widgets.No_Tag;
   begin
      if not Menu_Bar.Is_Installed (Item.Host.Menus)
        or else Event.Kind /= Pomarine.Events.Key_Down
        or else not Event.Command
        or else Event.Option
      then
         return;
      end if;
      case Event.Key is
         when Pomarine.Events.Key_Z =>
            Tag := (if Event.Shift then Widgets.Edit_Redo else Widgets.Edit_Undo);

         when Pomarine.Events.Key_X =>
            Tag := Widgets.Edit_Cut;

         when Pomarine.Events.Key_C =>
            Tag := Widgets.Edit_Copy;

         when Pomarine.Events.Key_V =>
            Tag := Widgets.Edit_Paste;

         when Pomarine.Events.Key_A =>
            Tag := Widgets.Edit_Select_All;

         when others                =>
            null;
      end case;
      if Tag /= Widgets.No_Tag then
         Menu_Bar.Discard (Item.Host.Menus, Tag);
      end if;
   end Key_Taken;

   procedure Update (Item : in out Session) is
   begin
      if Menu_Bar.Is_Installed (Item.Host.Menus) then
         Menu_Bar.Pump (Item.Host.Menus, Item.Root.Widgets);
         Menu_Bar.Update_States (Item.Host.Menus, Item.Root.Widgets);
      end if;
   end Update;

end View.Menus;
