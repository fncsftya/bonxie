with Goldens;
with Pomarine.Events;
with Pomarine.Testing;
with Viewer;
with Viewer.Project_Screen;
with Viewer_Driver;

package body Nav_Tests is

   package Testing renames Pomarine.Testing;
   package Project renames Viewer.Project_Screen;

   use type Viewer.Screens;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String is (Value'Image);

   procedure By_Name is
      Session : aliased Viewer.Session;
      Ears    : aliased Viewer_Driver.Driver (Session'Access);
      Window  : Testing.Session;
   begin
      Viewer.Open (Session, "", 1000, 800);
      Testing.Attach (Window, Viewer.Widget_Tree (Session).all, Ears'Access);

      --  A new project opens at the outline, as one that has not been left anywhere does.
      Testing.Click_On (Window, "New project");
      Check ("nav-name-new", "PROJECT OUTLINE TRUE FALSE",
             Viewer.Screen (Session)'Image & " " & Project.Mode (Session)'Image & " "
             & Image (Testing.Shows (Window, "button 'Outline' selected")) & " "
             & Image (Testing.Shows (Window, "button 'Canvas' selected")));

      --  The tabs go to the views.
      Testing.Click_On (Window, "Write");
      Check ("nav-name-write", "WRITE TRUE FALSE",
             Project.Mode (Session)'Image & " " & Image (Testing.Shows (Window, "button 'Write' selected")) & " "
             & Image (Testing.Shows (Window, "button 'Outline' selected")));
      Testing.Click_On (Window, "Canvas");
      Check ("nav-name-canvas", "CANVAS TRUE", Project.Mode (Session)'Image & " "
            & Image (Testing.Shows (Window, "button 'Canvas' selected")));

      --  The list of items is over the project, and Escape puts it away.
      Testing.Click_On (Window, "Items");
      Check ("nav-name-list", "TRUE", Image (Project.Is_Listing (Session)));
      Testing.Press (Window, Pomarine.Events.Key_Escape);
      Check ("nav-name-list-escaped", "FALSE CANVAS", Image (Project.Is_Listing (Session)) & " "
            & Project.Mode (Session)'Image);
      Testing.Click_On (Window, "Items");
      Testing.Click_On (Window, "Close");
      Check ("nav-name-list-closed", "FALSE", Image (Project.Is_Listing (Session)));

      --  The way back keeps the view, which the project opens to again.
      Testing.Click_On (Window, "Projects");
      Check ("nav-name-home", "TRUE FALSE", Image (Viewer.Screen (Session) = Viewer.Home) & " "
            & Image (Testing.Exists (Window, "Canvas")));
      Testing.Click_On (Window, "Open Untitled project");
      Check ("nav-name-reopened", "PROJECT CANVAS", Viewer.Screen (Session)'Image & " " & Project.Mode (Session)'Image);

      --  The settings take the place of the home screen, as far as the person can tell.
      Testing.Click_On (Window, "Projects");
      Testing.Click_On (Window, "Settings");
      Check ("nav-name-settings", "TRUE TRUE", Image (Testing.Exists (Window, "Dark")) & " "
            & Image (not Testing.Exists (Window, "New project")));
      Testing.Press (Window, Pomarine.Events.Key_Escape);
      Check ("nav-name-settings-escaped", "TRUE FALSE", Image (Testing.Exists (Window, "New project")) & " "
            & Image (Testing.Exists (Window, "Dark")));
   end By_Name;

end Nav_Tests;
