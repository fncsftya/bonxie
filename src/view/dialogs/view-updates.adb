with Pomarine.View_Models;
with View.Deletion;
with Update_VM;

package body View.Updates is

   package Parts renames Pomarine.View_Models;

   use type Confirm_VM.Subjects;
   use type Update_VM.Attentions;
   use type Update_VM.States;

   function Busy (Item : Session) return Boolean
   is (Update_VM.State (Item.Choices.Updates.Model)
       in Update_VM.Checking | Update_VM.Downloading | Update_VM.Verifying | Update_VM.Stopping);

   function Leaving (Item : Session) return Boolean
   is (Update_VM.Attention (Item.Choices.Updates.Model) = Update_VM.Leaving);

   function Can_Check (Item : Session) return Boolean
   is (Update_VM.Can_Execute (Item.Choices.Updates.Model, Update_VM.Check_Now));

   procedure Check_Now (Item : in out Session) is
   begin
      if Can_Check (Item) then
         Update_VM.Execute (Item.Choices.Updates.Model, Update_VM.Check_Now, Update_VM.Announcing);
      end if;
   end Check_Now;

   --  The dialog is the update's to use unless it is asking about a deletion, which was the person's doing.
   function Free_For_Update (Item : Session) return Boolean
   is (not Confirm_VM.Is_Asking (Item.Dialog_Model.Model)
       or else Confirm_VM.Subject (Item.Dialog_Model.Model) in Confirm_VM.Updates);

   procedure Show (Item : in out Session);
   --  Put in the dialog what Update_VM wants shown, when it has changed.

   procedure Show (Item : in out Session) is
      Update : Update_VM.View_Model renames Item.Choices.Updates.Model;
      Dialog : Confirm_VM.View_Model renames Item.Dialog_Model.Model;
   begin
      case Update_VM.Attention (Update) is
         when Update_VM.Offering                    =>
            if Free_For_Update (Item) and then Confirm_VM.Subject (Dialog) /= Confirm_VM.Update then
               Confirm_VM.Ask_Update (Dialog, Update_VM.Offer_Message (Update), Update_VM.Offer_Note (Update));
               Deletion.Sync (Item);
            end if;

         when Update_VM.Working                     =>
            if Free_For_Update (Item) then
               Confirm_VM.Ask_Updating (Dialog, Update_VM.Working_Message (Update), Update_VM.Working_Note (Update));
               Deletion.Sync (Item);
            end if;

         when Update_VM.Problem                     =>
            if Free_For_Update (Item) and then Confirm_VM.Subject (Dialog) /= Confirm_VM.Update_Problem then
               Confirm_VM.Ask_Update_Problem
                 (Dialog, Update_VM.Problem_Message (Update), Update_VM.Problem_Note (Update));
               Deletion.Sync (Item);
            end if;

         when Update_VM.Nothing | Update_VM.Leaving =>
            --  What was asked of the update is no more: the dialog goes (its closing is not an answer to give).
            if Confirm_VM.Subject (Dialog) in Confirm_VM.Updates then
               Confirm_VM.Execute (Dialog, Confirm_VM.Cancel);
               Deletion.Sync (Item);
            end if;
      end case;
   end Show;

   procedure Tick (Item : in out Session) is
      Update : Update_VM.View_Model renames Item.Choices.Updates.Model;
   begin
      Update_VM.Poll (Update);
      if Parts.Changed (Item.Choices.Updates.Seen, Update_VM.Version (Update)) then
         --  The settings' lines about it.
         if Has_Screen (Item, Settings_Region) then
            Sync_Screen (Item, Settings_Region);
         end if;
         Show (Item);
      elsif Update_VM.Attention (Update) in Update_VM.Offering | Update_VM.Problem then
         --  Waiting for a deletion's dialog to be done with.
         Show (Item);
      end if;
   end Tick;

   procedure Answered (Item : in out Session; Choice : Confirm_VM.Command) is
      Update : Update_VM.View_Model renames Item.Choices.Updates.Model;
      Wanted : constant Update_VM.Command :=
        (case Choice is
           when Confirm_VM.Confirm => Update_VM.Install,
           when Confirm_VM.Skip    => Update_VM.Skip,
           when Confirm_VM.Cancel  =>
             (if Update_VM.Attention (Update) = Update_VM.Working then Update_VM.Cancel else Update_VM.Later));
   begin
      if Update_VM.Can_Execute (Update, Wanted) then
         Update_VM.Execute (Update, Wanted);
      end if;
      --  (If it could not be, because what is going on cannot be stopped, the dialog comes back.)
      Show (Item);
   end Answered;

   procedure Stop (Item : in out Session) is
   begin
      if Update_VM.Can_Execute (Item.Choices.Updates.Model, Update_VM.Cancel) then
         Update_VM.Execute (Item.Choices.Updates.Model, Update_VM.Cancel);
      end if;
   end Stop;

end View.Updates;
