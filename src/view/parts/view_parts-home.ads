with Confirm_VM;
with Home_VM;
with Home_VM.Stored;
with Projects;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Bindings.For_Commands;
with Pomarine.Widgets.Checks;
with Previews;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Pomarine.View_Models;

--  The home screen, and the dialog to confirm deleting.
package View_Parts.Home is

   Home_Tag_Base    : constant := 200;
   Confirm_Tag_Base : constant := 300;
   --  The tags of the home screen's commands and the dialog's: after the settings' (see
   --  View_Parts.Settings), and the window's own are below those.

   package Home_Binding is new Pomarine.Widgets.Bindings.For_Commands (Home_VM.Commands, Home_Tag_Base);

   package Confirm_Binding is new Pomarine.Widgets.Bindings.For_Commands (Confirm_VM.Commands, Confirm_Tag_Base);

   type Project_Card is limited record
      Panel   : Pomarine.Widgets.Panels.Panel;
      --  A column, outlined, with a shadow: the picture, and below it
      --  the name and the buttons.
      Peek    : Pomarine.Widgets.Grips.Grip;
      Picture : Previews.Preview;
      --  Of its canvas: clicked, to open it.
      Info    : Pomarine.Widgets.Panels.Panel;
      Name    : Pomarine.Widgets.Grips.Grip;
      --  Clicked, to open it; in the place of which, the field to rename
      --  it.
      Title   : Pomarine.Widgets.Labels.Label;
      Meta    : Pomarine.Widgets.Labels.Label;
      --  How many documents and sources it has.
      Rename  : Pomarine.Widgets.Buttons.Button;
      Delete  : Pomarine.Widgets.Buttons.Button;
   end record;
   --  A project listed on the home screen.

   type Card_Array is array (1 .. Projects.Recent_Count) of Project_Card;

   type Home_Parts is limited record
      Home_Panel     : Pomarine.Widgets.Panels.Panel;
      --  A row: the sidebar of actions, and the recent projects.
      Home_Side      : Pomarine.Widgets.Panels.Panel;
      Logo           : Pomarine.Widgets.Panels.Panel;
      Logo_Name      : Pomarine.Widgets.Labels.Label;
      New_Button     : Pomarine.Widgets.Buttons.Button;
      Side_Room      : Pomarine.Widgets.Panels.Panel;
      --  Between New Project at the top and Settings at the foot.
      Settings_Button : Pomarine.Widgets.Buttons.Button;
      Home_Rule      : Pomarine.Widgets.Panels.Panel;
      --  The line between the sidebar and the projects.
      Recent_Panel   : Pomarine.Widgets.Panels.Panel;
      Recent_Title   : Pomarine.Widgets.Labels.Label;
      Cards_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Cards_Content  : Pomarine.Widgets.Panels.Panel;
      --  The cards, in rows that wrap, scrolled.
      Cards          : Card_Array;
      --  A card to each of the projects listed.
      No_Rows        : Pomarine.Widgets.Labels.Label;
      --  Shown when there are none.
      New_Card       : Pomarine.Widgets.Grips.Grip;
      New_Card_Plus  : Pomarine.Widgets.Buttons.Button;
      New_Card_Label : Pomarine.Widgets.Labels.Label;
      --  After the cards: an outline of one, in dashes, to make a project.

      Edit_Panel     : Pomarine.Widgets.Panels.Panel;
      Ok_Button      : Pomarine.Widgets.Buttons.Button;
      Cancel_Button  : Pomarine.Widgets.Buttons.Button;
      --  Put in the card of the project being renamed, in place of its
      --  name and buttons, which are hidden.
   end record;
   --  The widgets of the home screen: the sidebar, the recent projects as cards, and the
   --  field to rename one.

   type Home_Choices is limited record
      Library : aliased Home_VM.Stored.Projects_Kept;
      Model   : aliased Home_VM.View_Model;
      --  What the home screen means: the projects listed, the one being renamed.
      Judge   : aliased Home_Binding.Judge;
      Seen    : Pomarine.View_Models.Watch;
      Listed  : Pomarine.View_Models.Watch;
      --  The model's version, and its list's, as the widgets last showed them.
      Link    : Pomarine.Widgets.Bindings.Text_Link;
      --  The field's text and the draft.
      Editing : Natural := 0;
      --  The card the field is in, 0 if none, as shown.
   end record;
   --  The view-model of the home screen, and what the widgets show of it.

   type Confirm_Parts is limited record
      Overlay        : Pomarine.Widgets.Panels.Panel;
      --  Over both screens, to grey them out and hold the dialog, which
      --  is shown to confirm deleting a project.
      Dialog_Border  : Pomarine.Widgets.Panels.Panel;
      Dialog_Bar     : Pomarine.Widgets.Panels.Panel;
      Dialog_Title   : Pomarine.Widgets.Labels.Label;
      Dialog_Close   : Pomarine.Widgets.Buttons.Button;
      --  A dark bar across its top, as a window's: its title, and a
      --  button to close it, as Cancel does.
      Dialog         : Pomarine.Widgets.Panels.Panel;
      Confirm_Message : Pomarine.Widgets.Labels.Label;
      Delete_Documents : Pomarine.Widgets.Checks.Check;
      Confirm_Note   : Pomarine.Widgets.Labels.Label;
      Dialog_Rule    : Pomarine.Widgets.Panels.Panel;
      Confirm_Buttons : Pomarine.Widgets.Panels.Panel;
      --  The white body, saying what is to be deleted, a line, and a
      --  tinted foot with the buttons.
      Confirm_Cancel : Pomarine.Widgets.Buttons.Button;
      Confirm_Delete : Pomarine.Widgets.Buttons.Button;
   end record;
   --  The widgets of the dialog, over both screens, to confirm deleting.

   type Confirm_Choices is limited record
      Model : aliased Confirm_VM.View_Model;
      --  What it is about and what it says: a project, a folder, a document, a source or the
      --  speech model's files.
      Judge : aliased Confirm_Binding.Judge;
      Seen  : Pomarine.View_Models.Watch;
      --  The model's version as the widgets last showed it.
   end record;
   --  The view-model of the dialog, and what the widgets show of it.

end View_Parts.Home;
