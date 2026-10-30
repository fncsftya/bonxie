with Confirm_VM;

--  Updating the program, as the person sees it: the dialog that offers a newer version (the answers are theirs),
--  shows how the install is getting on, and says what went wrong, and the settings' line about it. Update_VM
--  decides what is wanted; this puts it in the dialog of Confirm_VM and does what the answers say.

private package View.Updates is

   procedure Tick (Item : in out Session);
   --  Move on what is going on, show what changed, and quit when the install asks for it.

   function Busy (Item : Session) return Boolean;
   --  Whether something is going on that is to be looked at again soon: a check, or an install.

   function Leaving (Item : Session) return Boolean;
   --  Whether the install is done on this side: the program is to end.

   procedure Check_Now (Item : in out Session);
   --  The menu's "Check for Updates": look now, and say what is found.

   function Can_Check (Item : Session) return Boolean;

   procedure Answered (Item : in out Session; Choice : Confirm_VM.Command);
   --  The person chose in the dialog about updating.

   procedure Stop (Item : in out Session);
   --  The program is ending: let go of what is being fetched.

end View.Updates;
