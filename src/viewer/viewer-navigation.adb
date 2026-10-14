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
      Projects.Find (Item.Store, Item.Current, Found, Result);
      declare
         Name : constant String :=
           (if Found then Projects.Titles.To_String (Result.Title) else "");
      begin
         Item.Project_Name := Ada.Strings.Unbounded.To_Unbounded_String (Name);
         UI.Widgets.Labels.Set_Text
           (Item.Project_Title,
            Name (Name'First ..
                  Name'First - 1
                  + Natural'Min
                      (Name'Length, UI.Widgets.Labels.Text_Capacity)));
      end;
   end Show_Title_Of_Project;

   procedure Enter (Item : in out Session; Key : Projects.Id) is
   begin
      Recent.Cancel_Edit (Item);
      Item.Current := Key;
      Show_Title_Of_Project (Item);
      Item.Shown := Project;
      Widgets.Set_Visible (Item.Home_Panel, False);
      Widgets.Set_Visible (Item.Project_Panel, True);
      Widgets.Clear_Focus (Item.Widgets);
      Widgets.Layout (Item.Widgets, Item.Target);
      --  Once the canvas is laid out, to have an origin.
      Canvas_Items.Enter (Item);
      Writing.Enter (Item);
   end Enter;

   procedure Enter_New (Item : in out Session) is
   begin
      Enter
        (Item, Projects.Create (Item.Store, "Untitled project"));
   end Enter_New;

   procedure Leave (Item : in out Session) is
   begin
      Writing.Leave (Item);
      Canvas_Items.Leave (Item);
      Item.Showing_List := False;
      Widgets.Set_Visible (Item.List_Overlay, False);
      Item.Shown := Home;
      Item.Current := 0;
      Widgets.Set_Visible (Item.Project_Panel, False);
      Widgets.Set_Visible (Item.Home_Panel, True);
      Recent.Refresh (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Leave;

   procedure Keep
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
   is
      Key : constant Projects.Id :=
        Projects.Create (Item.Store, Name, Time => Updated);
      pragma Unreferenced (Key);
   begin
      Recent.Refresh (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Keep;

end Viewer.Navigation;
