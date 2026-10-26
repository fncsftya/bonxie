with Settings_VM;
with Pomarine.UI;
with Pomarine.View_Models;
with View.Canvas_Items;
with View.Listing;
with View.Outlines;
with View.Section_Links;
with View.Settings_View;
with View.Recent;
with View.Writing;

package body View.Navigation is

   package Widgets renames Pomarine.Widgets;
   package Parts renames Pomarine.View_Models;

   use type Nav_VM.Command;
   use type Nav_VM.Screens;

   procedure Show_Entered (Item : in out Session);

   procedure Show_Entered (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
   begin
      Recent.Cancel_Edit (Item);
      Widgets.Set_Visible (Home_Panel (Item).all, False);
      Widgets.Set_Visible (Project_Panel (Item).all, True);
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
      Widgets.Set_Visible (Listing.Overlay (Item).all, False);
      Widgets.Set_Visible (Project_Panel (Item).all, False);
      Widgets.Set_Visible (Home_Panel (Item).all, True);
      Recent.Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Parts.See (Item.Nav_Model.Views, Nav_VM.Mode_Version (Item.Nav_Model.Model));
   end Show_Left;

   procedure Sync (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
      Home  : constant Boolean := Nav_VM.Screen (Model) = Nav_VM.Home;
   begin
      if Item.Forms (Project_Region).Screen /= null then
         Pomarine.UI.Synchronize (Item.Forms (Project_Region).Screen.all);
      end if;
      if Parts.Changed (Item.Nav_Model.Seen, Nav_VM.Version (Model)) then
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
         if not Home and then Widgets.Is_Visible (Listing.Overlay (Item).all) /= Nav_VM.Is_Listing (Model) then
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
         Nav_VM.Execute (Item.Nav_Model.Model, What, Index);
      end if;
      Sync (Item);
   end Do_Command;

   procedure Going_To_Execute (Item : in out Session; What : Nav_VM.Command) is
   begin
      if What = Nav_VM.Leave_Project then
         Close_Views (Item);
      end if;
   end Going_To_Execute;

   procedure Executed (Item : in out Session) is
   begin
      Sync (Item);
   end Executed;

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

end View.Navigation;
