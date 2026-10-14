with Ada.Strings.Unbounded;
with UI.Widgets;
with UI.Widgets.Labels;
with Viewer.Canvas_Items;
with Viewer.Recent;
with Viewer.Writing;

package body Viewer.Navigation is

   package Widgets renames UI.Widgets;

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
