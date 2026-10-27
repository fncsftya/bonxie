with Goldens;
with Pomarine.Events;
with Pomarine.Testing;
with View;
with View.Project_Screen;
with View.Canvas_Windows;
with View_Driver;

package body Nav_Tests is

   package Testing renames Pomarine.Testing;
   package Project renames View.Project_Screen;

   use type View.Screens;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   procedure By_Name is
      Session : aliased View.Session;
      Ears    : aliased View_Driver.Driver (Session'Access);
      Window  : Testing.Session;
   begin
      View.Open (Session, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);

      --  A new project opens at the outline, as one that has not been left anywhere does.
      Testing.Click_On (Window, "New project");
      Check
        ("nav-name-new",
         "PROJECT OUTLINE TRUE FALSE",
         View.Screen (Session)'Image
         & " "
         & Project.Mode (Session)'Image
         & " "
         & Image (Testing.Shows (Window, "button 'Outline' selected"))
         & " "
         & Image (Testing.Shows (Window, "button 'Canvas' selected")));

      --  The tabs go to the views.
      Testing.Click_On (Window, "Write");
      Check
        ("nav-name-write",
         "WRITE TRUE FALSE",
         Project.Mode (Session)'Image
         & " "
         & Image (Testing.Shows (Window, "button 'Write' selected"))
         & " "
         & Image (Testing.Shows (Window, "button 'Outline' selected")));
      Testing.Click_On (Window, "Canvas");
      Check
        ("nav-name-canvas",
         "CANVAS TRUE",
         Project.Mode (Session)'Image & " " & Image (Testing.Shows (Window, "button 'Canvas' selected")));

      --  The list of items is over the project, and Escape puts it away.
      Testing.Click_On (Window, "Items");
      Check ("nav-name-list", "TRUE", Image (Project.Is_Listing (Session)));
      Testing.Press (Window, Pomarine.Events.Key_Escape);
      Check
        ("nav-name-list-escaped",
         "FALSE CANVAS",
         Image (Project.Is_Listing (Session)) & " " & Project.Mode (Session)'Image);
      Testing.Click_On (Window, "Items");
      Testing.Click_On (Window, "Close");
      Check ("nav-name-list-closed", "FALSE", Image (Project.Is_Listing (Session)));

      --  The way back keeps the view, which the project opens to again.
      Testing.Click_On (Window, "Projects");
      Check
        ("nav-name-home",
         "TRUE FALSE",
         Image (View.Screen (Session) = View.Home) & " " & Image (Testing.Exists (Window, "Canvas")));
      Testing.Click_On (Window, "Open Untitled project");
      Check ("nav-name-reopened", "PROJECT CANVAS", View.Screen (Session)'Image & " " & Project.Mode (Session)'Image);

      --  The toolbar collects the edit before Return or blur executes the command.
      Testing.Click_On (Window, "Untitled project", Clicks => 2);
      Check ("nav-name-rename-focused", "Untitled project", Testing.Value_Of (Window, "Project name"));
      Testing.Type_Text (Window, "Great skua");
      Check ("nav-name-rename-typed", "Great skua", Testing.Value_Of (Window, "Project name"));
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check
        ("nav-name-rename-submit",
         "TRUE FALSE",
         Image (Testing.Exists (Window, "Great skua")) & " " & Image (Testing.Exists (Window, "Project name")));
      Testing.Click_On (Window, "Great skua", Clicks => 2);
      Testing.Type_Text (Window, "Arctic skua");
      Testing.Press (Window, Pomarine.Events.Key_Tab);
      Check
        ("nav-name-rename-blur",
         "TRUE FALSE",
         Image (Testing.Exists (Window, "Arctic skua")) & " " & Image (Testing.Exists (Window, "Project name")));
      Testing.Click_On (Window, "Arctic skua", Clicks => 2);
      Testing.Press (Window, Pomarine.Events.Key_Backspace);
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check
        ("nav-name-rename-blank",
         "TRUE FALSE",
         Image (Testing.Exists (Window, "Arctic skua")) & " " & Image (Testing.Exists (Window, "Project name")));

      --  The settings take the place of the home screen, as far as the person can tell.
      Testing.Click_On (Window, "Projects");
      Testing.Click_On (Window, "Settings");
      Check
        ("nav-name-settings",
         "TRUE TRUE",
         Image (Testing.Exists (Window, "Dark")) & " " & Image (not Testing.Exists (Window, "New project")));
      Testing.Press (Window, Pomarine.Events.Key_Escape);
      Check
        ("nav-name-settings-escaped",
         "TRUE FALSE",
         Image (Testing.Exists (Window, "New project")) & " " & Image (Testing.Exists (Window, "Dark")));
   end By_Name;

   procedure Creating is
      Session : aliased View.Session;
      Ears    : aliased View_Driver.Driver (Session'Access);
      Window  : Testing.Session;
   begin
      View.Open (Session, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Canvas");
      --  The canvas toolbar declares creation commands and preserves the existing default names and kinds.
      Testing.Click_On (Window, "Add document");
      Testing.Click_On (Window, "Add source");
      Check
        ("nav-name-created",
         " 2 Untitled item NOTE Untitled source SOURCE",
         Natural'Image (View.Canvas_Windows.Item_Count (Session))
         & " "
         & View.Canvas_Windows.Item_Title (Session, 1)
         & " "
         & View.Canvas_Windows.Item_Kind (Session, 1)'Image
         & " "
         & View.Canvas_Windows.Item_Title (Session, 2)
         & " "
         & View.Canvas_Windows.Item_Kind (Session, 2)'Image);

      Testing.Click_On (Window, "Items");
      Testing.Press (Window, Pomarine.Events.Key_Escape);
      Testing.Click_On (Window, "Projects");
      Testing.Click_On (Window, "Open Untitled project");
      Check
        ("nav-name-created-reopened",
         " 2 Untitled item Untitled source",
         Natural'Image (View.Canvas_Windows.Item_Count (Session))
         & " "
         & View.Canvas_Windows.Item_Title (Session, 1)
         & " "
         & View.Canvas_Windows.Item_Title (Session, 2));

   end Creating;

end Nav_Tests;
