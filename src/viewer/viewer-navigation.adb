with Settings_VM;
with Texts.Documents;
with Pomarine.Text_Areas;
with Pomarine.View_Models;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Text_Fields;
with Viewer.Canvas_Items;
with Viewer.Listing;
with Viewer.Outlines;
with Viewer.Section_Links;
with Viewer.Settings_View;
with Viewer.Recent;
with Viewer.Writing;

package body Viewer.Navigation is

   package Widgets renames Pomarine.Widgets;
   package Bindings renames Pomarine.Widgets.Bindings;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Parts renames Pomarine.View_Models;

   use type Nav_VM.Command;
   use type Nav_VM.Screens;

   procedure Show_Title_Of_Project (Item : in out Session) is
   begin
      Labels.Set_Text (Item.Toolbar.Project_Title, Nav_VM.Name (Item.Nav_Model.Model));
   end Show_Title_Of_Project;

   --  The name's field in place of the name, to type over it; or the name, with what it has come to.
   procedure Show_Renaming (Item : in out Session);

   procedure Show_Renaming (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
   begin
      if Nav_VM.Is_Renaming (Model) then
         Bindings.Show (Item.Nav_Model.Link, Item.Toolbar.Title_Doc, Nav_VM.Draft (Model));
         Text_Fields.Attach (Item.Toolbar.Title_Field, Item.Toolbar.Title_Doc'Unchecked_Access);
         Widgets.Set_Visible (Item.Toolbar.Title_Area, False);
         --  The press that began it is not let go on what is hidden.
         Grips.Cancel_Drag (Item.Toolbar.Title_Area);
         Widgets.Set_Visible (Item.Toolbar.Title_Field, True);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (Item.Toolbar.Title_Field).all);
         Widgets.Focus (Item.Toolbar.Title_Field);
      else
         Widgets.Set_Visible (Item.Toolbar.Title_Field, False);
         Widgets.Set_Visible (Item.Toolbar.Title_Area, True);
         Show_Title_Of_Project (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Show_Renaming;

   procedure Show_Entered (Item : in out Session);

   procedure Show_Entered (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
   begin
      Recent.Cancel_Edit (Item);
      Widgets.Set_Visible (Item.Home_View.Home_Panel, False);
      Widgets.Set_Visible (Item.Toolbar.Project_Panel, True);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      --  Once the canvas is laid out, to have an origin.
      Canvas_Items.Enter (Item);
      Writing.Enter (Item);
      Outlines.Enter (Item);
      --  The view it was left at, which is shown in any case.
      Nav_VM.Restore_Mode (Model);
      Writing.Show_View (Item);
      Parts.See (Item.Nav_Model.Views, Nav_VM.Mode_Version (Model));
   end Show_Entered;

   --  The project's views let go of it, while it is still the one shown: what was typed is kept and the windows are
   --  written under it.
   procedure Close_Views (Item : in out Session);

   procedure Close_Views (Item : in out Session) is
   begin
      Section_Links.Close (Item);
      Outlines.Leave (Item);
      Writing.Leave (Item);
      Canvas_Items.Leave (Item);
   end Close_Views;

   procedure Show_Left (Item : in out Session);

   procedure Show_Left (Item : in out Session) is
   begin
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Set_Visible (Item.Toolbar.Project_Panel, False);
      Widgets.Set_Visible (Item.Home_View.Home_Panel, True);
      Recent.Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Parts.See (Item.Nav_Model.Views, Nav_VM.Mode_Version (Item.Nav_Model.Model));
   end Show_Left;

   procedure Sync (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
      Home  : constant Boolean := Nav_VM.Screen (Model) = Nav_VM.Home;
   begin
      --  What was typed is the draft.
      if Nav_VM.Is_Renaming (Model) and then Bindings.Edited (Item.Nav_Model.Link, Item.Toolbar.Title_Doc) then
         Nav_VM.Set_Draft (Model, Texts.Documents.Whole (Item.Toolbar.Title_Doc));
      end if;
      if Nav_Binding.Changed (Item.Nav_Model.Seen, Model) then
         if Parts.Changed (Item.Nav_Model.Naming, Nav_VM.Renaming_Version (Model)) then
            Show_Renaming (Item);
         end if;
         if Parts.Changed (Item.Nav_Model.Names, Nav_VM.Name_Version (Model)) then
            Show_Title_Of_Project (Item);
         end if;
         if Parts.Changed (Item.Nav_Model.Screens, Nav_VM.Screen_Version (Model)) then
            if Home then
               Show_Left (Item);
            else
               Show_Entered (Item);
            end if;
         elsif Parts.Changed (Item.Nav_Model.Views, Nav_VM.Mode_Version (Model)) then
            Writing.Show_View (Item);
         end if;
         --  The settings take the place of the home screen; the list of items goes over a project.
         if Widgets.Is_Visible (Item.Prefs.Settings_Panel) /= Settings_VM.Is_Showing (Item.Choices.Model) then
            if Settings_VM.Is_Showing (Item.Choices.Model) then
               Settings_View.Show_Form (Item);
            else
               Settings_View.Hide_Form (Item);
            end if;
         end if;
         if not Home and then Widgets.Is_Visible (Item.Item_List.List_Overlay) /= Nav_VM.Is_Listing (Model) then
            if Nav_VM.Is_Listing (Model) then
               Listing.Show_List (Item);
            else
               Listing.Hide_List (Item);
            end if;
         end if;
         --  The buttons the commands are on are turned on and off as the view-model says.
         Widgets.Revalidate (Item.Root.Widgets);
      end if;
   end Sync;

   procedure Do_Command (Item : in out Session; What : Nav_VM.Command; Index : Natural := 0) is
   begin
      Sync (Item);
      if Nav_VM.Can_Execute (Item.Nav_Model.Model, What, Index) then
         if What = Nav_VM.Leave_Project then
            Close_Views (Item);
         end if;
         Nav_VM.Execute (Item.Nav_Model.Model, What, Index);
      end if;
      Sync (Item);
   end Do_Command;

   procedure Title_Double_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Do_Command (Item, Nav_VM.Begin_Rename);
   end Title_Double_Clicked;

   procedure Title_Ended
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Do_Command (Item, Nav_VM.Accept_Rename);
   end Title_Ended;

   procedure Show (Item : in out Session; To : Modes) is
   begin
      Do_Command
        (Item,
         (case To is
             when Outline => Nav_VM.Show_Outline,
             when Canvas  => Nav_VM.Show_Canvas,
             when Write   => Nav_VM.Show_Writing,
             when Publish => Nav_VM.Show_Publish));
   end Show;

   procedure Enter (Item : in out Session; Key : Projects.Id) is
   begin
      Sync (Item);
      Nav_VM.Open (Item.Nav_Model.Model, Key);
      Sync (Item);
   end Enter;

   procedure Enter_New (Item : in out Session) is
   begin
      Do_Command (Item, Nav_VM.Start_Project);
   end Enter_New;

   procedure Leave (Item : in out Session) is
   begin
      Do_Command (Item, Nav_VM.Leave_Project);
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
