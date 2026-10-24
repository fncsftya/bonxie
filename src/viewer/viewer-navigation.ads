with Nav_VM;
with Pomarine.Widgets;

--  Going between the home screen and a project's, and between the views of a project: what Nav_VM says is shown, in
--  the widgets.
private package Viewer.Navigation is

   procedure Do_Command (Item : in out Session; What : Nav_VM.Command; Index : Natural := 0);
   --  Ask the view-model, if it can be done, and show what it comes to.

   procedure Sync (Item : in out Session);
   --  Take what was typed in the field of the project's name for the draft, and show what the view-model says if it
   --  has changed: the screen entered or left, the view, the settings and the list put up or away, the field to
   --  rename the project in.

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

   procedure Show_Title_Of_Project (Item : in out Session);
   --  Put the title of the current project, as kept, on the toolbar.

   procedure Title_Double_Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  The project's name was pressed twice: begin renaming it.

   procedure Title_Ended
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  Return was pressed in the name's field, or it has lost the focus:
   --  end the renaming.

   procedure Keep
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds);
   --  Keep a project last updated at Updated, to be listed.

end Viewer.Navigation;
