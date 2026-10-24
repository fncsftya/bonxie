with Items.Models;
with Pomarine.Widgets;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Viewer.Recent;
with Viewer.Settings_View;
with Viewer.Writing;

package body Viewer.Deletion is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;
   package Checks renames Pomarine.Widgets.Checks;

   use type Confirm_VM.Subjects;
   use type Items.Kinds;

   --  Show the dialog over the rest: Tab goes round only its buttons, and Return, which a button has when it has
   --  the focus, is for Cancel. The speech model's has no scope: it is the settings' own.
   procedure Raise_Dialog (Item : in out Session);

   procedure Raise_Dialog (Item : in out Session) is
   begin
      Widgets.Set_Visible (Item.Confirm.Overlay, True);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if Confirm_VM.Subject (Item.Dialog_Model.Model) /= Confirm_VM.Model then
         Widgets.Set_Focus_Scope (Item.Root.Widgets, Item.Confirm.Dialog_Border);
         --  Its buttons are on now (see Revalidate), so that one can have the focus.
         Widgets.Revalidate (Item.Root.Widgets);
         Widgets.Focus (Item.Confirm.Confirm_Cancel);
      end if;
   end Raise_Dialog;

   procedure Lower_Dialog (Item : in out Session);

   procedure Lower_Dialog (Item : in out Session) is
   begin
      Widgets.Clear_Focus_Scope (Item.Root.Widgets);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Confirm.Overlay, False);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Lower_Dialog;

   procedure Sync (Item : in out Session) is
      Model : Confirm_VM.View_Model renames Item.Dialog_Model.Model;
   begin
      --  The box is the person's to tick.
      if Confirm_VM.Offers_Documents (Model) then
         Confirm_VM.Set_Delete_Documents (Model, Checks.Is_Checked (Item.Confirm.Delete_Documents));
      end if;
      if Confirm_Binding.Changed (Item.Dialog_Model.Seen, Model) then
         Labels.Set_Text (Item.Confirm.Dialog_Title, Confirm_VM.Title (Model));
         Labels.Set_Text (Item.Confirm.Confirm_Message, Confirm_VM.Message (Model));
         Labels.Set_Text (Item.Confirm.Confirm_Note, Confirm_VM.Note (Model));
         Widgets.Set_Visible (Item.Confirm.Delete_Documents, Confirm_VM.Offers_Documents (Model));
         Checks.Set_Checked (Item.Confirm.Delete_Documents, Confirm_VM.Delete_Documents (Model));
         Widgets.Revalidate (Item.Root.Widgets);
         if Confirm_VM.Is_Asking (Model) and then not Widgets.Is_Visible (Item.Confirm.Overlay) then
            Raise_Dialog (Item);
         elsif not Confirm_VM.Is_Asking (Model) and then Widgets.Is_Visible (Item.Confirm.Overlay) then
            Lower_Dialog (Item);
         end if;
      end if;
   end Sync;

   procedure Confirm (Item : in out Session; Row : Positive) is
   begin
      Recent.Cancel_Edit (Item);
      Confirm_VM.Ask_Project (Item.Dialog_Model.Model, Row, Home_VM.Title (Item.Home_Model.Model, Row));
      Sync (Item);
   end Confirm;

   procedure Confirm_Node (Item : in out Session; Node : Tree_Entry) is
      Kind : constant Confirm_VM.Nodes :=
        (if Node.Kind = Directory_Node then Confirm_VM.Folder
         elsif Items.Models.Details (Item.Models (Node.Doc)).Kind = Items.Source then Confirm_VM.Source
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

   procedure Answer (Item : in out Session; Command : Confirm_VM.Command) is
      use all type Confirm_VM.Command;
   begin
      Sync (Item);
      if not Confirm_VM.Can_Execute (Item.Dialog_Model.Model, Command) then
         return;
      end if;
      Confirm_VM.Execute (Item.Dialog_Model.Model, Command);
      Sync (Item);
      if Command = Confirm then
         declare
            Said : constant Confirm_VM.Answer := Confirm_VM.Last_Answer (Item.Dialog_Model.Model);
         begin
            case Said.Subject is
               when Confirm_VM.Nothing =>
                  null;
               when Confirm_VM.Project =>
                  Home_VM.Execute (Item.Home_Model.Model, Home_VM.Delete_Project, Said.Row);
                  Recent.Sync (Item);
               when Confirm_VM.Folder =>
                  Writing.Delete_Node
                    (Item, (Kind => Directory_Node, Dir => Said.Dir, Doc => 0), Said.Delete_Documents);
               when Confirm_VM.Document | Confirm_VM.Source =>
                  Writing.Delete_Node
                    (Item, (Kind => Document_Leaf, Dir => Said.Dir, Doc => Said.Doc), Said.Delete_Documents);
               when Confirm_VM.Model =>
                  Settings_View.Delete_Files (Item);
            end case;
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         end;
      end if;
   end Answer;

end Viewer.Deletion;
