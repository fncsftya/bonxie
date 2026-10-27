with Goldens;
with Pomarine.Events;
with Pomarine.Testing;
with View;
with View.Home_Screen;
with View_Driver;

package body Home_Tests is

   package Home renames View.Home_Screen;
   package Testing renames Pomarine.Testing;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   Dot : constant String := [Character'Val (16#C2#), Character'Val (16#B7#)];

   procedure By_Name is
      Session : aliased View.Session;
      Ears    : aliased View_Driver.Driver (Session'Access);
      Window  : Testing.Session;
   begin
      View.Open (Session, "", 1000, 800);
      Home.Add_Project (Session, "Episode 1", 3600);
      Home.Add_Project (Session, "Episode 2", 7200);
      Home.Add_Project (Session, "Episode 3", 10800);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);

      --  The latest first, each with what it holds.
      Check
        ("home-name-listed",
         "Episode 3 Episode 2 Episode 1",
         Home.Row_Title (Session, 1) & " " & Home.Row_Title (Session, 2) & " " & Home.Row_Title (Session, 3));
      Check
        ("home-name-shown",
         "TRUE",
         Image
           (Testing.Exists (Window, "Open Episode 3")
            and then Testing.Exists (Window, "Open Episode 1")
            and then Testing.Shows (Window, "heading 'Episode 2'")
            and then Testing.Shows (Window, "'0 documents " & Dot & " 0 sources'")));

      --  Rename: the field has the title, selected, and what is typed replaces it.
      Testing.Click_On (Window, "Rename", Nth => 2);
      Check
        ("home-name-renaming",
         "TRUE TRUE",
         Image (Home.Is_Renaming (Session))
         & " "
         & Image
             (Testing.Shows (Window, "text field =Episode 2")
              and then Testing.Exists (Window, "OK")
              and then Testing.Exists (Window, "Cancel")));
      Testing.Type_Text (Window, "Pilot");
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check
        ("home-name-renamed",
         "FALSE Pilot Episode 3",
         Image (Home.Is_Renaming (Session)) & " " & Home.Row_Title (Session, 1) & " " & Home.Row_Title (Session, 2));
      Check
        ("home-name-renamed-shown",
         "TRUE FALSE",
         Image (Testing.Shows (Window, "heading 'Pilot'")) & " " & Image (Testing.Exists (Window, "OK")));

      --  Nothing is not a title: the field stays, and its OK is no use.
      Testing.Click_On (Window, "Rename", Nth => 3);
      Testing.Press (Window, Pomarine.Events.Key_Backspace);
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check
        ("home-name-rename-nothing",
         "TRUE Episode 1",
         Image (Home.Is_Renaming (Session)) & " " & Home.Row_Title (Session, 3));
      Testing.Click_On (Window, "OK");
      Check
        ("home-name-ok-nothing",
         "TRUE Episode 1",
         Image (Home.Is_Renaming (Session)) & " " & Home.Row_Title (Session, 3));

      --  Cancel puts the buttons back.
      Testing.Click_On (Window, "Cancel");
      Check
        ("home-name-rename-cancelled",
         "FALSE Episode 1",
         Image (Home.Is_Renaming (Session)) & " " & Home.Row_Title (Session, 3));
      Check ("home-name-rename-buttons", "TRUE", Image (Testing.Exists (Window, "Rename", Nth => 3)));

      --  Typing and OK.
      Testing.Click_On (Window, "Rename", Nth => 3);
      Testing.Type_Text (Window, "  Last  ");
      Testing.Click_On (Window, "OK");
      --  Both were renamed at once (to the second), so the one made later is still the first.
      Check
        ("home-name-ok",
         "FALSE Pilot Last",
         Image (Home.Is_Renaming (Session)) & " " & Home.Row_Title (Session, 1) & " " & Home.Row_Title (Session, 2));

      --  Delete asks first, stops a rename on another card, and asks of the chosen card.
      Testing.Click_On (Window, "Rename", Nth => 3);
      Testing.Click_On (Window, "Delete", Nth => 2);
      Check
        ("home-name-delete-asks",
         "TRUE TRUE",
         Image (Home.Is_Confirming (Session))
         & " "
         & Image
             (Testing.Shows (Window, "text 'Delete project'")
              and then Testing.Shows (Window, "Last")
              and then Testing.Shows (Window, "This cannot be undone.")));
      Check ("home-name-delete-stops-rename", "FALSE", Image (Home.Is_Renaming (Session)));
      Testing.Click_On (Window, "Cancel");
      Check
        ("home-name-delete-cancelled",
         "FALSE Last",
         Image (Home.Is_Confirming (Session)) & " " & Home.Row_Title (Session, 2));
      Testing.Click_On (Window, "Delete", Nth => 2);
      Testing.Press (Window, Pomarine.Events.Key_Escape);
      Check
        ("home-name-delete-escaped",
         "FALSE Last",
         Image (Home.Is_Confirming (Session)) & " " & Home.Row_Title (Session, 2));
      Testing.Click_On (Window, "Delete", Nth => 2);
      Testing.Click_On (Window, "Delete", Nth => 4);
      Check
        ("home-name-deleted",
         "FALSE Pilot Episode 3 ",
         Image (Home.Is_Confirming (Session))
         & " "
         & Home.Row_Title (Session, 1)
         & " "
         & Home.Row_Title (Session, 2)
         & " "
         & Home.Row_Title (Session, 3));
      --  A card added after initial mounting has the same declared command.
      Home.Add_Project (Session, "Episode 4", 14400);
      Testing.Click_On (Window, "Delete", Nth => 2);
      Check ("home-name-late-delete-asks", "TRUE", Image (Home.Is_Confirming (Session)));
      Testing.Click_On (Window, "Delete", Nth => 4);
      Check
        ("home-name-late-deleted",
         "Pilot Episode 3 ",
         Home.Row_Title (Session, 1) & " " & Home.Row_Title (Session, 2) & " " & Home.Row_Title (Session, 3));
   end By_Name;

end Home_Tests;
