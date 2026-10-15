with Pomarine.Native_Menus;
with Pomarine.Widgets;

package body Viewer.Menus is

   package Menu_Bar renames Pomarine.Native_Menus;
   package Widgets renames Pomarine.Widgets;

   use type Pomarine.Widgets.Command_State;

   Current : Session_Access;
   --  Whose window it is: the validator is told only what a command is.

   Ellipsis : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   --  In UTF-8.

   function Tag_Of (What : Command) return Integer is (Command'Pos (What));

   function Validate (Tag : Integer) return Widgets.Command_State;
   --  What each command is for, as shown.

   function Validate (Tag : Integer) return Widgets.Command_State is
      Here   : constant Boolean := Current /= null and then Is_Open (Current.all);
   begin
      if not Here or else Tag not in 0 .. Command'Pos (Command'Last) then
         return Widgets.Enabled;
      end if;
      declare
         What      : constant Command := Command'Val (Tag);
         In_Project : constant Boolean := Screen (Current.all) = Project;
      begin
         case What is
            when Start_Project | Open_Settings =>
               return (if In_Project then Widgets.Disabled else Widgets.Enabled);
            when Leave_Project | Open_List =>
               return (if In_Project then Widgets.Enabled else Widgets.Disabled);
            when Show_Canvas =>
               return (if not In_Project then Widgets.Disabled
                       elsif Current.Toolbar.Mode = Canvas then Widgets.Ticked
                       else Widgets.Enabled);
            when Show_Writing =>
               return (if not In_Project then Widgets.Disabled
                       elsif Current.Toolbar.Mode = Write then Widgets.Ticked
                       else Widgets.Enabled);
         end case;
      end;
   end Validate;

   procedure Build (Item : in out Session) is
      File, Edit, Go : Menu_Bar.Menu;
      Bar : Menu_Bar.Menu_Bar renames Item.Host.Menus;
   begin
      Menu_Bar.Install (Bar);
      if not Menu_Bar.Is_Installed (Bar) then
         return;
      end if;

      Menu_Bar.Add_Menu (Bar, "File", File);
      Menu_Bar.Add_Item (Bar, File, "New Project", Tag_Of (Start_Project), Key => "n");
      Menu_Bar.Add_Item (Bar, File, "Settings" & Ellipsis, Tag_Of (Open_Settings), Key => ",");
      Menu_Bar.Add_Separator (Bar, File);
      Menu_Bar.Add_Item (Bar, File, "Close Project", Tag_Of (Leave_Project), Key => "w");

      Menu_Bar.Add_Menu (Bar, "Edit", Edit);
      Menu_Bar.Add_Item (Bar, Edit, "Undo", Widgets.Edit_Undo, Key => "z");
      Menu_Bar.Add_Item (Bar, Edit, "Redo", Widgets.Edit_Redo, Key => "z", Shift => True);
      Menu_Bar.Add_Separator (Bar, Edit);
      Menu_Bar.Add_Item (Bar, Edit, "Cut", Widgets.Edit_Cut, Key => "x");
      Menu_Bar.Add_Item (Bar, Edit, "Copy", Widgets.Edit_Copy, Key => "c");
      Menu_Bar.Add_Item (Bar, Edit, "Paste", Widgets.Edit_Paste, Key => "v");
      Menu_Bar.Add_Item (Bar, Edit, "Select All", Widgets.Edit_Select_All, Key => "a");

      Menu_Bar.Add_Menu (Bar, "Go", Go);
      Menu_Bar.Add_Item (Bar, Go, "Canvas", Tag_Of (Show_Canvas), Key => "1");
      Menu_Bar.Add_Item (Bar, Go, "Writing", Tag_Of (Show_Writing), Key => "2");
      Menu_Bar.Add_Separator (Bar, Go);
      Menu_Bar.Add_Item (Bar, Go, "Items", Tag_Of (Open_List), Key => "l");

      Current := Item'Unchecked_Access;
      Widgets.Set_Validator (Item.Root.Widgets, Validate'Access);
   end Build;

   procedure Update (Item : in out Session) is
   begin
      if Menu_Bar.Is_Installed (Item.Host.Menus) then
         Menu_Bar.Pump (Item.Host.Menus, Item.Root.Widgets);
         Menu_Bar.Update_States (Item.Host.Menus, Validate'Access);
      end if;
   end Update;

end Viewer.Menus;
