with Items.Models;
with Pomarine.UI;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with View.Recent;
with View.Updates;
with View.Style;
with View.Settings_View;
with View.Writing;

package body View.Deletion is

   package Widgets renames Pomarine.Widgets;
   package UI renames Pomarine.UI;

   use type Confirm_VM.Subjects;
   use type Confirm_VM.Command;
   use type Items.Kinds;

   function Dialog (Item : Session) return access Widgets.Widget'Class
   is (UI.Named (Screen_Of (Item, Confirm_Region).all, Confirm_Overlay));
   --  The grey that covers the window, and holds the dialog.

   --  Show the dialog over the rest: Tab goes round only its buttons, and Return, which a button has when it has
   --  the focus, is for Cancel. The speech model's has no scope: it is the settings' own.
   procedure Raise_Dialog (Item : in out Session);

   procedure Raise_Dialog (Item : in out Session) is
      Form : UI.View renames Screen_Of (Item, Confirm_Region).all;
   begin
      Widgets.Set_Visible (Dialog (Item).all, True);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if Confirm_VM.Subject (Item.Dialog_Model.Model) /= Confirm_VM.Model then
         Widgets.Set_Focus_Scope (Item.Root.Widgets, UI.Named (Form, Confirm_Border).all);
         --  Its buttons are on now (see Revalidate), so that one can have the focus: the one that does nothing.
         Widgets.Revalidate (Item.Root.Widgets);
         Widgets.Focus
           (UI.Named
              (Form,
               (case Confirm_VM.Subject (Item.Dialog_Model.Model) is
                  when Confirm_VM.Update         => Confirm_Later_Button,
                  when Confirm_VM.Update_Problem => Confirm_Ok_Button,
                  when others                    => Confirm_Cancel_Button)).all);
      end if;
   end Raise_Dialog;

   procedure Lower_Dialog (Item : in out Session);

   procedure Lower_Dialog (Item : in out Session) is
   begin
      Widgets.Clear_Focus_Scope (Item.Root.Widgets);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Dialog (Item).all, False);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Lower_Dialog;

   procedure Sync (Item : in out Session) is
      Model : Confirm_VM.View_Model renames Item.Dialog_Model.Model;
   begin
      --  What it says, and the box the person ticks, are the view's.
      if Pomarine.View_Models.Changed (Item.Dialog_Model.Seen, Confirm_VM.Version (Model)) then
         Sync_Screen (Item, Confirm_Region);
         --  What is said of an update has more words than what is said of a deletion.
         Widgets.Layouts.Set_Layout
           (UI.Named (Screen_Of (Item, Confirm_Region).all, Confirm_Border).all,
            (Width  =>
               (if Confirm_VM.Subject (Model) in Confirm_VM.Updates
                then Style.Update_Dialog_Width
                else Style.Dialog_Width),
             others => <>));
         Widgets.Revalidate (Item.Root.Widgets);
      end if;
      if Confirm_VM.Is_Asking (Model) and then not Widgets.Is_Visible (Dialog (Item).all) then
         Raise_Dialog (Item);
      elsif not Confirm_VM.Is_Asking (Model) and then Widgets.Is_Visible (Dialog (Item).all) then
         Lower_Dialog (Item);
      end if;
   end Sync;

   procedure Confirm_Node (Item : in out Session; Node : Tree_Entry) is
      Kind : constant Confirm_VM.Nodes :=
        (if Node.Kind = Directory_Node
         then Confirm_VM.Folder
         elsif Items.Models.Details (Item.Models (Node.Doc)).Kind = Items.Source
         then Confirm_VM.Source
         else Confirm_VM.Document);
      Name : constant String :=
        (if Node.Kind = Directory_Node
         then Projects.Titles.To_String (Item.Docs.Dirs (Node.Dir).Title)
         else Projects.Titles.To_String (Items.Models.Details (Item.Models (Node.Doc)).Title));
   begin
      Confirm_VM.Ask_Node (Item.Dialog_Model.Model, Kind, Node.Dir, Node.Doc, Name);
      Sync (Item);
   end Confirm_Node;

   procedure Confirm_Model (Item : in out Session; Size : String) is
   begin
      Confirm_VM.Ask_Model (Item.Dialog_Model.Model, Size);
      Sync (Item);
   end Confirm_Model;

   procedure Close (Item : in out Session) is
   begin
      if Confirm_VM.Can_Execute (Item.Dialog_Model.Model, Confirm_VM.Cancel) then
         Confirm_VM.Execute (Item.Dialog_Model.Model, Confirm_VM.Cancel);
      end if;
      Sync (Item);
   end Close;

   procedure Answered (Item : in out Session; Said : Confirm_VM.Answer) is
   begin
      case Said.Subject is
         when Confirm_VM.Nothing                      =>
            null;

         when Confirm_VM.Project                      =>
            Home_VM.Delete_Confirmed (Item.Home_Model.Model, Said.Project_Key);
            Recent.Sync (Item);

         when Confirm_VM.Folder                       =>
            Writing.Delete_Node (Item, (Kind => Directory_Node, Dir => Said.Dir, Doc => 0), Said.Delete_Documents);

         when Confirm_VM.Document | Confirm_VM.Source =>
            Writing.Delete_Node
              (Item, (Kind => Document_Leaf, Dir => Said.Dir, Doc => Said.Doc), Said.Delete_Documents);

         when Confirm_VM.Model                        =>
            Settings_View.Delete_Files (Item);

         when Confirm_VM.Updates                      =>
            Updates.Answered (Item, Said.Choice);
      end case;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Answered;

end View.Deletion;
