with Goldens;
with Pomarine.Events;
with Pomarine.Testing;
with Viewer;
with Viewer.Home_Screen;
with Viewer.Outline_Screen;
with Viewer_Driver;

package body Outline_Screen_Tests is

   package Outline renames Viewer.Outline_Screen;
   package Testing renames Pomarine.Testing;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String is (Value'Image);

   function Number (Value : Integer) return String is (Value'Image (2 .. Value'Image'Last));

   procedure By_Name is
      Session : aliased Viewer.Session;
      Ears    : aliased Viewer_Driver.Driver (Session'Access);
      Window  : Testing.Session;

      function Titles return String is
         Said : String (1 .. 300);
         Used : Natural := 0;
      begin
         for Each in 1 .. Outline.Section_Count (Session) loop
            declare
               Title : constant String := Outline.Section_Title (Session, Each);
            begin
               Said (Used + 1 .. Used + Title'Length + 1) := Title & "|";
               Used := Used + Title'Length + 1;
            end;
         end loop;
         return Said (1 .. Used);
      end Titles;

      procedure Rename_Section (Place : Positive; Words : String) is
      begin
         Testing.Click_On (Window, "Section title", Nth => Place);
         Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
         Testing.Type_Text (Window, Words);
      end Rename_Section;
   begin
      Viewer.Open (Session, "", 1000, 800);
      Viewer.Home_Screen.New_Project (Session);
      Testing.Attach (Window, Viewer.Widget_Tree (Session).all, Ears'Access);

      Check ("outline-name-first", "TRUE 0",
             Image (Testing.Shows (Window, "text 'No sections yet'")) & " " & Number (Outline.Section_Count (Session)));

      --  Add: a section last, which is called nothing yet, and its buttons, but not those that go nowhere.
      Testing.Click_On (Window, "Add Section");
      Testing.Click_On (Window, "Add Section");
      Check ("outline-name-added", "2 Untitled section|Untitled section| FALSE",
             Number (Outline.Section_Count (Session)) & " " & Titles & " "
             & Image (Testing.Shows (Window, "No sections yet")));
      Check ("outline-name-ends", "TRUE FALSE TRUE FALSE",
             Image (Testing.Is_Disabled (Window, "Move up", Nth => 1)) & " "
             & Image (Testing.Is_Disabled (Window, "Move up", Nth => 2)) & " "
             & Image (Testing.Is_Disabled (Window, "Move down", Nth => 2)) & " "
             & Image (Testing.Is_Disabled (Window, "Move down", Nth => 1)));

      --  Typing names them, and that is kept.
      Rename_Section (1, "Opening");
      Rename_Section (2, "Closing");
      Check ("outline-name-typed", "Opening|Closing|", Titles);
      Check ("outline-name-typed-shown", "TRUE", Image (Testing.Shows (Window, "'Section title' =Closing")));

      --  Moving.
      Testing.Click_On (Window, "Move up", Nth => 2);
      Check ("outline-name-up", "Closing|Opening|", Titles);
      Testing.Click_On (Window, "Move down", Nth => 1);
      Check ("outline-name-down", "Opening|Closing|", Titles);
      Check ("outline-name-ends-again", "TRUE TRUE", Image (Testing.Is_Disabled (Window, "Move up", Nth => 1)) & " "
             & Image (Testing.Is_Disabled (Window, "Move down", Nth => 2)));

      --  Notes open and shut.
      Check ("outline-name-notes-shut", "FALSE", Image (Outline.Notes_Shown (Session, 2)));
      Testing.Click_On (Window, "Notes", Nth => 2);
      Check ("outline-name-notes-open", "TRUE FALSE", Image (Outline.Notes_Shown (Session, 2)) & " "
             & Image (Outline.Notes_Shown (Session, 1)));
      Testing.Click_On (Window, "Notes", Nth => 2);
      Check ("outline-name-notes-closed", "FALSE", Image (Outline.Notes_Shown (Session, 2)));

      --  The project is named, and is not left without a name.
      Testing.Click_On (Window, "Project title");
      Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
      Testing.Type_Text (Window, "Great skua");
      Check ("outline-name-project", "Great skua TRUE", Outline.Project_Title (Session) & " "
             & Image (Testing.Shows (Window, "heading 'Great skua'")));
      Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
      Testing.Press (Window, Pomarine.Events.Key_Backspace);
      Check ("outline-name-project-nothing", "TRUE", Image (Testing.Shows (Window, "heading 'Great skua'")));

      --  Remove.
      Testing.Click_On (Window, "Delete section", Nth => 1);
      Check ("outline-name-removed", "1 Closing|", Number (Outline.Section_Count (Session)) & " " & Titles);
      Testing.Click_On (Window, "Delete section");
      Check ("outline-name-removed-all", "0 TRUE", Number (Outline.Section_Count (Session)) & " "
             & Image (Testing.Shows (Window, "text 'No sections yet'")));
   end By_Name;

end Outline_Screen_Tests;
