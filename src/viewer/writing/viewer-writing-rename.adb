with Items.Directories;
with Projects.Sections;
with Viewer.Build;
with Pomarine.Boxes;
with Texts.Documents;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Text_Fields;
with Viewer.Outlines;
with Pomarine.Widgets.Layouts;
with Viewer.Writing.Order;
with Viewer.Writing.Support;
with Viewer.Writing.Tree;

package body Viewer.Writing.Rename is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Grips renames Pomarine.Widgets.Grips;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Windows renames Items.Windows;
   package Docs renames Texts.Documents;

   procedure Put_Field
     (Item    : in out Session;
      Field   : in out Text_Fields.Text_Field;
      Content : in out Widgets.Widget'Class;
      Box     : Grips.Grip);
   --  Put the field to rename over the row, which is in Content, with its
   --  text selected and the focus: what it is of is attached already.

   procedure Put_Field
     (Item    : in out Session;
      Field   : in out Text_Fields.Text_Field;
      Content : in out Widgets.Widget'Class;
      Box     : Grips.Grip)
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Layouts.Set_Layout
        (Field,
         Position => (Left => Widgets.Left_Of (Box) - Widgets.Left_Of (Content),
                      Top  => Widgets.Top_Of (Box) - Widgets.Top_Of (Content),
                      others => <>),
         Width => Widgets.Width_Of (Box) - Pomarine.Boxes.Offset (Pixels),
         Unit => Layouts.Device_Pixels);
      Widgets.Set_Visible (Field, True);
      Widgets.Request_Layout (Field);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Pomarine.Text_Areas.Select_All (Text_Fields.Area (Field).all);
      Widgets.Focus (Field);
   end Put_Field;

   procedure Begin_Rename_Dir (Item : in out Session; Dir : Positive) is
      Row : constant Natural := Support.Dir_Row (Item, Dir);
   begin
      if Row = 0 then
         return;
      end if;
      Docs.Load
        (Item.Naming.Dir_Doc,
         Projects.Titles.To_String (Item.Docs.Dirs (Dir).Title));
      Text_Fields.Attach (Item.Naming.Dir_Field,
                          Item.Naming.Dir_Doc'Unchecked_Access);
      Item.Naming.Renaming_Dir := Dir;
      Put_Field
        (Item, Item.Naming.Dir_Field, Item.Page_View.Docs_Content,
         Item.Docs.Doc_Rows (Row).Row);
   end Begin_Rename_Dir;

   procedure End_Rename_Doc (Item : in out Session) is
   begin
      Item.Naming.Renaming_Doc := 0;
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Tree.Refresh (Item);
   end End_Rename_Doc;

   procedure Begin_Rename_Doc (Item : in out Session; Which : Items.Slot) is
      Row : constant Natural := Support.Leaf_Row (Item, Which);
   begin
      if Row = 0 then
         return;
      end if;
      Text_Fields.Attach
        (Item.Naming.Dir_Field, Windows.Title_Document (Item.Windows (Which)));
      Item.Naming.Renaming_Doc := Which;
      Put_Field
        (Item, Item.Naming.Dir_Field, Item.Page_View.Docs_Content,
         Item.Docs.Doc_Rows (Row).Row);
   end Begin_Rename_Doc;

   procedure Begin_Rename_Source (Item : in out Session; Which : Items.Slot)
   is
      Row : constant Natural := Support.Row_Of (Item, Which);
   begin
      if Row = 0 then
         return;
      end if;
      Text_Fields.Attach
        (Item.Naming.Source_Field,
         Windows.Title_Document (Item.Windows (Which)));
      Item.Naming.Renaming_Source := Which;
      Put_Field
        (Item, Item.Naming.Source_Field, Item.Page_View.Sources_Content,
         Item.Reading.Source_Rows (Row).Row);
   end Begin_Rename_Source;

   procedure End_Rename_Dir (Item : in out Session) is
      Content : constant String := Docs.Whole (Item.Naming.Dir_Doc);
      Dir     : constant Natural := Item.Naming.Renaming_Dir;
      First   : Positive := Content'First;
      Last    : Natural := Content'Last;
   begin
      Item.Naming.Renaming_Dir := 0;
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if Dir /= 0 and then Last >= First then
         declare
            Name : constant String := Content (First .. Last);
         begin
            if Support.Is_Section (Item, Dir) then
               --  A section's folder has the section's name, which is kept
               --  with the section, and shown wherever it is.
               declare
                  Key : constant Projects.Sections.Section_Id :=
                    Projects.Sections.Section_Id (Item.Docs.Dirs (Dir).Section);
               begin
                  Projects.Sections.Rename (Item.Nav.Store, Key, Name);
                  Outlines.Reload (Item);
                  Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
                  Item.Docs.Dirs (Dir) :=
                    (Item.Docs.Dirs (Dir) with delta Title => Projects.Titles.To_Text (Name));
               end;
            else
               Items.Directories.Rename_Directory
                 (Item.Nav.Store, Item.Docs.Dirs (Dir).Key, Name);
               Item.Docs.Dirs (Dir) :=
                 (Item.Docs.Dirs (Dir) with delta Title => Projects.Titles.To_Text (Name));
            end if;
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end;
      end if;
      Tree.Refresh (Item);
   end End_Rename_Dir;

   procedure End_Rename_Source (Item : in out Session) is
   begin
      Item.Naming.Renaming_Source := 0;
      Widgets.Set_Visible (Item.Naming.Source_Field, False);
      Tree.Refresh (Item);
   end End_Rename_Source;

   procedure New_Directory (Item : in out Session; Name : String) is
      Key : constant Items.Id :=
        Items.Directories.Create_Directory
          (Item.Nav.Store, Item.Opened.Current, Name);
   begin
      Item.Docs.Dirs.Append ((Key => Key, Title => Projects.Titles.To_Text (Name), others => <>));
      Build.Reserve_Rows (Item);
      --  Last of all.
      Order.Insert_Row
        (Item, Item.Docs.Tree_Count + 1,
         (Kind => Directory_Node, Dir => Item.Docs.Dirs.Count, Doc => 0));
      Order.Keep_Order (Item);
      Tree.Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Begin_Rename_Dir (Item, Item.Docs.Dirs.Count);
   end New_Directory;

end Viewer.Writing.Rename;
