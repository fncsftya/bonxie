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

   --  The parts of the dialogs that other files reach for, by the names they are Called in their screens
   --  (Pomarine.UI.Named): the grey over the window that holds a dialog, the dialog's outline (a dark bar
   --  across its top as a window's, a white body, a line, and a tinted foot with the buttons), and the
   --  controls that are focused, clicked or measured.

   Confirm_Overlay       : constant String := "confirm-overlay";
   --  Over both screens, to grey them out and hold the dialog, which is shown to confirm deleting a project,
   --  a folder, a document, a source or the speech model's files.
   Confirm_Border        : constant String := "confirm-border";
   Delete_Documents_Check : constant String := "confirm-delete-documents";
   Confirm_Cancel_Button : constant String := "confirm-cancel";
   Confirm_Delete_Button : constant String := "confirm-delete";
   List_Overlay          : constant String := "list-overlay";
   --  Over the project screen, to grey it out and hold the list of items, which is shown while Nav_VM says it
   --  is up.
   List_Border           : constant String := "list-border";

   type Confirm_Choices is limited record
      Model : aliased Confirm_VM.View_Model;
      --  What it is about and what it says: a project, a folder, a document, a source or the
      --  speech model's files.
      Seen  : Pomarine.View_Models.Watch;
      --  The model's version as the widgets last showed it.
   end record;
   --  The view-model of the dialog, and what the widgets show of it.

end View_Parts.Home;
