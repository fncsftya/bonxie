with UI.Widgets;
with Viewer.Recent;

package body Viewer.Navigation is

   package Widgets renames UI.Widgets;
   package Labels renames UI.Widgets.Labels;

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
         --  Cut to fit the label.
         Labels.Set_Text
           (Item.Project_Title,
            Name (Name'First ..
                  Name'First - 1
                  + Natural'Min (Name'Length, Labels.Text_Capacity)));
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
      Widgets.Focus (Item.Area);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Enter;

   procedure Enter_New (Item : in out Session) is
   begin
      Enter
        (Item, Projects.Create (Item.Store, "Untitled project"));
   end Enter_New;

   procedure Leave (Item : in out Session) is
   begin
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
