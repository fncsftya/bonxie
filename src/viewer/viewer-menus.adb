with Pomarine.Native_Menus;

package body Viewer.Menus is

   package Menu_Bar renames Pomarine.Native_Menus;
   package Widgets renames Pomarine.Widgets;

   use type Pomarine.Widgets.Command_State;

   Ellipsis : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   --  In UTF-8.

   function Tag_Of (What : Command) return Integer is (Command'Pos (What));

   function Validate (Item : Session; Tag : Integer; Index : Natural) return Widgets.Command_State is
   begin
      if Binding.Is_Mine (Tag) then
         return Binding.Validate (Item.Choices.Judge, Tag, Index);
      elsif Home_Binding.Is_Mine (Tag) then
         return Home_Binding.Validate (Item.Home_Model.Judge, Tag, Index);
      elsif Outline_Binding.Is_Mine (Tag) then
         return Outline_Binding.Validate (Item.Outline_Model.Judge, Tag, Index);
      elsif Confirm_Binding.Is_Mine (Tag) then
         return Confirm_Binding.Validate (Item.Dialog_Model.Judge, Tag, Index);
      end if;
      --  Without a menu bar, the window's buttons are as they are set.
      if not Menu_Bar.Is_Installed (Item.Host.Menus) or else not Is_Open (Item)
        or else Tag not in 0 .. Command'Pos (Command'Last)
      then
         return Widgets.Enabled;
      end if;
      declare
         What       : constant Command := Command'Val (Tag);
         In_Project : constant Boolean := Screen (Item) = Project;
      begin
         case What is
            when Start_Project | Open_Settings =>
               return (if In_Project then Widgets.Disabled else Widgets.Enabled);
            when Leave_Project | Open_List =>
               return (if In_Project then Widgets.Enabled else Widgets.Disabled);
            when Show_Outline =>
               return (if not In_Project then Widgets.Disabled
                       elsif Item.Toolbar.Mode = Outline then Widgets.Ticked
                       else Widgets.Enabled);
            when Show_Canvas =>
               return (if not In_Project then Widgets.Disabled
                       elsif Item.Toolbar.Mode = Canvas then Widgets.Ticked
                       else Widgets.Enabled);
            when Show_Writing =>
               return (if not In_Project then Widgets.Disabled
                       elsif Item.Toolbar.Mode = Write then Widgets.Ticked
                       else Widgets.Enabled);
            when Show_Publish =>
               return (if not In_Project then Widgets.Disabled
                       elsif Item.Toolbar.Mode = Publish then Widgets.Ticked
                       else Widgets.Enabled);
         end case;
      end;
   end Validate;

   procedure Build (Item : in out Session) is
      File, Edit, View : Menu_Bar.Menu;
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

      Menu_Bar.Add_Menu (Bar, "View", View);
      Menu_Bar.Add_Item (Bar, View, "Outline", Tag_Of (Show_Outline), Key => "1");
      Menu_Bar.Add_Item (Bar, View, "Canvas", Tag_Of (Show_Canvas), Key => "2");
      Menu_Bar.Add_Item (Bar, View, "Writing", Tag_Of (Show_Writing), Key => "3");
      Menu_Bar.Add_Item (Bar, View, "Publish", Tag_Of (Show_Publish), Key => "4");
      Menu_Bar.Add_Separator (Bar, View);
      Menu_Bar.Add_Item (Bar, View, "Items", Tag_Of (Open_List));
   end Build;

   procedure Key_Taken (Item : in out Session; Event : Pomarine.Events.Event) is
      use type Pomarine.Events.Event_Kind;
      Tag : Integer := Widgets.No_Tag;
   begin
      if not Menu_Bar.Is_Installed (Item.Host.Menus)
        or else Event.Kind /= Pomarine.Events.Key_Down
        or else not Event.Command or else Event.Option
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
         when others =>
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

end Viewer.Menus;
