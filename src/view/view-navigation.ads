with Nav_VM;

--  Going between the home screen and a project's, and between the views of a project: what Nav_VM says is shown, in
--  the widgets.
private package View.Navigation is

   procedure Do_Command (Item : in out Session; What : Nav_VM.Command; Index : Natural := 0);
   --  Ask the view-model, if it can be done, and show what it comes to.

   procedure Sync (Item : in out Session);
   --  Synchronize the declarative toolbar, then show screen, view and modal-layer transitions.

   procedure Enter (Item : in out Session; Key : Projects.Id)
     with Pre => Screen (Item) = Home;
   --  Go to the screen of the project Key.

   procedure Enter_New (Item : in out Session)
     with Pre => Screen (Item) = Home;
   --  Keep a new project, and go to its screen.

   procedure Leave (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Go back to the home screen.

   procedure Show (Item : in out Session; To : Modes)
     with Pre => Screen (Item) = Project;
   --  Show the view, in place of the one shown, and keep it as the project's.

   procedure Going_To_Execute (Item : in out Session; What : Nav_VM.Command);
   --  Before the navigation does What: let go of the views of the project that is left.

   procedure Executed (Item : in out Session);
   --  After it did: the screens show it (Sync). The model says so around every command it does, including
   --  those of a button that is the view's (Pomarine.UI), which Do_Command is not.

   procedure Keep
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds);
   --  Keep a project last updated at Updated, to be listed.

end View.Navigation;
