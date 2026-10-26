with Confirm_VM;
with Home_VM;
with Home_VM.Stored;
with Projects;
with Pomarine.UI;
with Previews;
with Pomarine.Widgets;
with Pomarine.Widgets.Scrollers;
with Pomarine.View_Models;

--  The home screen, and the dialog to confirm deleting.
package View_Parts.Home is

   type Project_Card is limited record
      Panel   : Pomarine.UI.Layout;
      --  A column, outlined, with a shadow: the picture, and below it the name and the buttons.
      Info    : Pomarine.UI.Layout;
      --  The row of the name and the buttons, in which the field to rename the project is put.
      Peek    : Pomarine.UI.Grip_Handle;
      Picture : Previews.Preview;
      --  Of its canvas: clicked, to open it.
      Name    : Pomarine.UI.Grip_Handle;
      --  Clicked, to open it; in the place of which, the field to rename it.
      Rename  : Pomarine.UI.Button_Handle;
      Editing : Pomarine.UI.Layout;
      --  In place of the name and the buttons, while the project is renamed: the field, and OK and Cancel.
      Field   : Pomarine.UI.Field_Handle;
      Ok      : Pomarine.UI.Button_Handle;
      Cancel  : Pomarine.UI.Button_Handle;
   end record;
   --  A project listed on the home screen: the controls are the view's (Pomarine.UI), the title and what is
   --  said under it are bound to the view-model, and the picture is the application's.

   type Card_Array is array (1 .. Projects.Recent_Count) of Project_Card;

   type Home_Parts is limited record
      Home_Layout    : Pomarine.UI.Layout;
      --  A row: the sidebar of actions (the name, New Project at the top, Settings at the foot: the view's
      --  controls, Pomarine.UI), a line, and the recent projects.
      Cards_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      --  The cards, in rows that wrap, scrolled.
      Cards          : Card_Array;
      --  A card to each of the projects listed.
      New_Card       : Pomarine.UI.Grip_Handle;
      New_Card_Plus  : Pomarine.UI.Button_Handle;
      --  After the cards: an outline of one, in dashes, to make a project.
   end record;
   --  The widgets of the home screen: the sidebar, the recent projects as cards, and the
   --  field to rename one.

   type Home_Choices is limited record
      Library : aliased Home_VM.Stored.Projects_Kept;
      Model   : aliased Home_VM.View_Model;
      --  What the home screen means: the projects listed, the one being renamed.
      Seen    : Pomarine.View_Models.Watch;
      Listed  : Pomarine.View_Models.Watch;
      --  The model's version, and its list's, as the widgets last showed them.
   end record;
   --  The view-model of the home screen, and what the widgets show of it.

   type Confirm_Parts is limited record
      Overlay          : Pomarine.UI.Layout;
      --  Over both screens, to grey them out and hold the dialog, which is shown to confirm deleting
      --  a project, a folder, a document, a source or the speech model's files.
      Border           : Pomarine.UI.Layout;
      --  The dialog itself: an outline round a dark bar across its top, as a window's (its title, and a
      --  button to close it), a white body that says what is to be deleted, a line, and a tinted foot with
      --  the buttons.
      Dialog_Close     : Pomarine.UI.Button_Handle;
      Delete_Documents : Pomarine.UI.Check_Handle;
      Confirm_Cancel   : Pomarine.UI.Button_Handle;
      Confirm_Delete   : Pomarine.UI.Button_Handle;
      --  The controls are the view's (Pomarine.UI), bound to Confirm_Choices.Model (see View.Build.Dialogs).
   end record;
   --  The dialog, over both screens, to confirm deleting.

   type Confirm_Choices is limited record
      Model : aliased Confirm_VM.View_Model;
      --  What it is about and what it says: a project, a folder, a document, a source or the
      --  speech model's files.
      Seen  : Pomarine.View_Models.Watch;
      --  The model's version as the widgets last showed it.
   end record;
   --  The view-model of the dialog, and what the widgets show of it.

end View_Parts.Home;
