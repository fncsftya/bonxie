with Goldens;
with Items.Readers;
with Pomarine.Testing;
with Pomarine.Themes;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pictures;

package body Reader_Binding_Tests is
   procedure By_Name is
      package Widgets renames Pomarine.Widgets;
      package Testing renames Pomarine.Testing;
      package Readers renames Items.Readers;
      use type Widgets.Pictures.Tools;
      Tree   : aliased Widgets.Tree;
      Root   : Widgets.Panels.Panel;
      Reader : Readers.Reader;
      Window : Testing.Session;
      procedure Check (Name : String; Passed : Boolean) is
      begin
         Goldens.Check_Text (Name, "TRUE", Passed'Image);
      end Check;
   begin
      Widgets.Set_Root (Tree, Root);
      Readers.Build (Reader, Root, Pomarine.Themes.Strip, 1.0);
      Readers.Assign
        (Reader,
         (Key => 1, Kind => Items.Source, others => <>),
         (Left => 10.0, Top => 10.0, Width => 500.0, Height => 350.0));
      Readers.Set_State (Reader, Items.Open);
      Readers.Place (Reader);
      Testing.Open (Window, Tree, 720, 480);
      Testing.Click_On (Window, "Mark");
      Check
        ("reader-binding-marker",
         Readers.Tool (Reader) = Widgets.Pictures.Highlighter
         and then Testing.Shows (Window, "button 'Mark' selected"));
      Testing.Click_On (Window, "Rub");
      Check
        ("reader-binding-eraser",
         Readers.Tool (Reader) = Widgets.Pictures.Eraser
         and then Testing.Shows (Window, "button 'Rub' selected")
         and then not Testing.Shows (Window, "button 'Mark' selected"));
      Readers.Select_Tool (Reader, Widgets.Pictures.Pointer);
      Check ("reader-binding-external-tool", Testing.Shows (Window, "button 'Ptr' selected"));
      Readers.Set_State (Reader, Items.Closed);
      Readers.Release (Reader);
      Readers.Assign
        (Reader,
         (Key => 2, Kind => Items.Source, others => <>),
         (Left => 10.0, Top => 10.0, Width => 500.0, Height => 350.0));
      Readers.Set_State (Reader, Items.Open);
      Readers.Place (Reader);
      Testing.Settle (Window);
      Testing.Click_On (Window, "Mark");
      Check ("reader-binding-reused", Readers.Tool (Reader) = Widgets.Pictures.Highlighter);
   end By_Name;
end Reader_Binding_Tests;
