with Ada.Strings.Unbounded;
with Texts.Documents;
with UI.Text_Areas;
with UI.Widgets;
with UI.Widgets.Grips;
with UI.Widgets.Labels;
with UI.Widgets.Text_Fields;
with Viewer.Canvas_Items;
with Viewer.Recent;
with Viewer.Writing;

package body Viewer.Navigation is

   package Widgets renames UI.Widgets;
   package Grips renames UI.Widgets.Grips;
   package Text_Fields renames UI.Widgets.Text_Fields;

   procedure Show_Title_Of_Project (Item : in out Session);
   --  Put the title of the current project on the toolbar.

   procedure Show_Title_Of_Project (Item : in out Session) is
      Found  : Boolean;
      Result : Projects.Project;
   begin
      Projects.Find (Item.Nav.Store, Item.Opened.Current, Found, Result);
      declare
         Name : constant String :=
           (if Found then Projects.Titles.To_String (Result.Title) else "");
      begin
         Item.Opened.Project_Name
            := Ada.Strings.Unbounded.To_Unbounded_String (Name);
         UI.Widgets.Labels.Set_Text
           (Item.Toolbar.Project_Title,
            Name (Name'First ..
                  Name'First - 1
                  + Natural'Min
                      (Name'Length, UI.Widgets.Labels.Text_Capacity)));
      end;
   end Show_Title_Of_Project;

   procedure Finish_Rename (Item : in out Session);
   --  Put the name back in place of the field, keeping what was typed
   --  if it is more than spaces.

   procedure Finish_Rename (Item : in out Session) is
      Content : constant String := Texts.Documents.Whole (Item.Toolbar.Title_Doc);
      First   : Positive := Content'First;
      Last    : Natural := Content'Last;
   begin
      Item.Toolbar.Renaming := False;
      Widgets.Set_Visible (Item.Toolbar.Title_Field, False);
      Widgets.Set_Visible (Item.Toolbar.Title_Area, True);
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if Last >= First then
         Projects.Rename
           (Item.Nav.Store, Item.Opened.Current,
            Content (First .. Natural'Min
                                (Last, First + Projects.Title_Capacity - 1)));
         Show_Title_Of_Project (Item);
      end if;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Finish_Rename;

   procedure Take_Rename (Item : in out Session) is
      Doubled : Boolean;
      Entered : Boolean;
   begin
      Grips.Take_Double_Click (Item.Toolbar.Title_Area, Doubled);
      if Doubled and then not Item.Toolbar.Renaming then
         Texts.Documents.Load
           (Item.Toolbar.Title_Doc, Ada.Strings.Unbounded.To_String (Item.Opened.Project_Name));
         Text_Fields.Attach
           (Item.Toolbar.Title_Field, Item.Toolbar.Title_Doc'Unchecked_Access);
         Item.Toolbar.Renaming := True;
         Widgets.Set_Visible (Item.Toolbar.Title_Area, False);
         --  The press that began it is not let go on what is hidden.
         Grips.Cancel_Drag (Item.Toolbar.Title_Area);
         Widgets.Set_Visible (Item.Toolbar.Title_Field, True);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         UI.Text_Areas.Select_All
           (Text_Fields.Area (Item.Toolbar.Title_Field).all);
         Widgets.Focus (Item.Toolbar.Title_Field);
      elsif Item.Toolbar.Renaming then
         Text_Fields.Take_Return (Item.Toolbar.Title_Field, Entered);
         if Entered or else not Widgets.Has_Focus (Item.Toolbar.Title_Field)
         then
            Finish_Rename (Item);
         end if;
      end if;
   end Take_Rename;

   procedure Enter (Item : in out Session; Key : Projects.Id) is
   begin
      Recent.Cancel_Edit (Item);
      Item.Opened.Current := Key;
      Show_Title_Of_Project (Item);
      Item.Nav.Shown := Project;
      Widgets.Set_Visible (Item.Home_View.Home_Panel, False);
      Widgets.Set_Visible (Item.Toolbar.Project_Panel, True);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      --  Once the canvas is laid out, to have an origin.
      Canvas_Items.Enter (Item);
      Writing.Enter (Item);
   end Enter;

   procedure Enter_New (Item : in out Session) is
   begin
      Enter
        (Item, Projects.Create (Item.Nav.Store, "Untitled project"));
   end Enter_New;

   procedure Leave (Item : in out Session) is
   begin
      if Item.Toolbar.Renaming then
         Finish_Rename (Item);
      end if;
      Writing.Leave (Item);
      Canvas_Items.Leave (Item);
      Item.Item_List.Showing_List := False;
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Item.Nav.Shown := Home;
      Item.Opened.Current := 0;
      Widgets.Set_Visible (Item.Toolbar.Project_Panel, False);
      Widgets.Set_Visible (Item.Home_View.Home_Panel, True);
      Recent.Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Leave;

   procedure Keep
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
   is
      Key : constant Projects.Id :=
        Projects.Create (Item.Nav.Store, Name, Time => Updated);
      pragma Unreferenced (Key);
   begin
      Recent.Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Keep;

end Viewer.Navigation;
