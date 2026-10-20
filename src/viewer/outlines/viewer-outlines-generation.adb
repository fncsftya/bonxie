with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Unbounded;
with Icon_Set;
with MLX;
with MLX.Jobs;
with Outline_Generation;
with Pomarine.Boxes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Viewer.Style;
with Viewer.Outlines.Blocks;
with Viewer.Outlines.Support;

package body Viewer.Outlines.Generation is

   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Menus renames Pomarine.Widgets.Menus;
   package Labels renames Pomarine.Widgets.Labels;

   procedure Show_Note (Item : in out Session; Words : String; Ink : Pomarine.Themes.Slot) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Labels.Set_Text (View.Generate_Error, Labels.Fitted (Words));
      Labels.Set_Ink (View.Generate_Error, Ink);
      Widgets.Set_Visible (View.Generate_Error, Words /= "");
   end Show_Note;

   procedure Show_Generate (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
      Want : constant Boolean := Item.Prefs.AI_On and then not Generating (Item);
   begin
      if Buttons.Is_Enabled (View.Generate_Button) /= Want then
         Buttons.Set_Enabled (View.Generate_Button, Want);
      end if;
   end Show_Generate;

   procedure Place_Menu (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Button : Buttons.Button renames View.Generate_Button;
      Panel  : Pomarine.Widgets.Panels.Panel renames Item.Toolbar.Content_Panel;
      Wide   : constant Float := Style.Generate_Menu_Width * Pixels;
      Left   : constant Float :=
        Float'Max
          (0.0, Widgets.Left_Of (Button) + Widgets.Width_Of (Button) + Pomarine.Boxes.Offset (Pixels) - Wide
                - Widgets.Left_Of (Panel));
      Top    : constant Float :=
        Widgets.Top_Of (Button) + Widgets.Height_Of (Button) + Style.Menu_Gap * Pixels - Widgets.Top_Of (Panel);
   begin
      if Float'Rounding (Left) /= View.Generate_Left or else Float'Rounding (Top) /= View.Generate_Top then
         View.Generate_Left := Float'Rounding (Left);
         View.Generate_Top := Float'Rounding (Top);
         Layouts.Set_Layout
           (View.Generate_Menu,
            Position => (Left => View.Generate_Left, Top => View.Generate_Top, others => <>),
            Unit => Layouts.Device_Pixels);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Place_Menu;

   procedure Open_Menu (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Menus.Clear (View.Generate_Menu);
      Menus.Add (View.Generate_Menu, Menus.Action, Generate_Label (False));
      Menus.Set_Icon (View.Generate_Menu, 1, Icon_Set.Sparkles);
      Menus.Add (View.Generate_Menu, Menus.Action, "Generate + Notes");
      Menus.Set_Icon (View.Generate_Menu, 2, Icon_Set.Sparkles);
      View.Generate_Open := True;
      View.Generate_Left := -1.0E9;
      Buttons.Set_Selected (View.Generate_Button, True);
      Widgets.Set_Visible (View.Generate_Menu, True);
      Widgets.Raise_To_Front (View.Generate_Menu);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Place_Menu (Item);
   end Open_Menu;

   procedure Start_Try (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      MLX.Jobs.Start
        (View.Generate_Job,
         Ada.Strings.Unbounded.To_String (View.Generate_Folder),
         Ada.Strings.Unbounded.To_String (View.Generate_Prompt),
         Outline_Generation.System_Prompt (View.Generate_Notes),
         Tuning => (Max_Tokens => Outline_Generation.Tokens, Temperature => 0.6, Thinking => MLX.On,
                    others => <>));
   exception
      when MLX.Jobs.Capacity_Error =>
         View.Generate_Tries := 0;
         Show_Note (Item, "The AI is busy, try again", Pomarine.Themes.Danger_Ink);
   end Start_Try;

   procedure Give_Up (Item : in out Session; Words : String) is
   begin
      Item.Outline_View.Generate_Tries := 0;
      Show_Note (Item, Words, Pomarine.Themes.Danger_Ink);
   end Give_Up;

   procedure Finish_Try (Item : in out Session) is
      View  : Outline_Parts renames Item.Outline_View;
      Reply : constant String := MLX.Jobs.Text (View.Generate_Job);
   begin
      MLX.Jobs.Reset (View.Generate_Job);
      if Item.Opened.Current /= View.Generate_Project then
         View.Generate_Tries := 0;
         Show_Note (Item, "", Style.Quiet_Ink);
      elsif Take_Reply (Item, Reply) then
         View.Generate_Tries := 0;
         Show_Note (Item, "", Style.Quiet_Ink);
      elsif View.Generate_Tries < Outline_Generation.Max_Tries then
         View.Generate_Tries := View.Generate_Tries + 1;
         Start_Try (Item);
      else
         Give_Up
           (Item,
            "No outline after" & Outline_Generation.Max_Tries'Image & " tries, try again");
      end if;
   end Finish_Try;

   procedure Apply (Item : in out Session; Wanted : Projects.Sections.Section_List) is
      package Sects renames Projects.Sections;
      Owner : constant Projects.Id := Item.Opened.Current;
      Have  : Sects.Section_List;
      Taken : array (1 .. Sects.Max_Sections) of Boolean := [others => False];
      Match : array (1 .. Wanted.Count) of Natural := [others => 0];
      Kept  : Natural := 0;
      Added : Natural := 0;
      Keys  : Sects.Key_Array (1 .. Sects.Max_Sections);
      Total : Natural := 0;

      procedure Give_Notes (Key : Sects.Section_Id; Notes : Sects.Note_Texts.Bounded_String) is
      begin
         if Sects.Note_Texts.Length (Notes) > 0 then
            Sects.Set_Notes (Item.Nav.Store, Key, Sects.Note_Texts.To_String (Notes));
         end if;
      end Give_Notes;
   begin
      if Item.Toolbar.Mode = Outline then
         Sync (Item);
      end if;
      Sects.Load (Item.Nav.Store, Owner, Have);
      for Each in 1 .. Wanted.Count loop
         for Other in 1 .. Have.Count loop
            if not Taken (Other)
              and then Ada.Strings.Equal_Case_Insensitive
                         (Sects.Title_Texts.To_String (Have.Items (Other).Title),
                          Sects.Title_Texts.To_String (Wanted.Items (Each).Title))
            then
               Taken (Other) := True;
               Match (Each) := Other;
               Kept := Kept + 1;
               exit;
            end if;
         end loop;
      end loop;
      declare
         Room : constant Integer := Sects.Max_Sections - Have.Count;
         --  Of the sections to add, as many as fit with all that are there.
      begin
         for Each in 1 .. Wanted.Count loop
            if Match (Each) /= 0 then
               Total := Total + 1;
               Keys (Total) := Have.Items (Match (Each)).Key;
               --  What the writer wrote is not written over.
               if Sects.Note_Texts.Length (Have.Items (Match (Each)).Notes) = 0 then
                  Give_Notes (Keys (Total), Wanted.Items (Each).Notes);
               end if;
            elsif Added < Room then
               Added := Added + 1;
               Total := Total + 1;
               Keys (Total) :=
                 Sects.Add (Item.Nav.Store, Owner, Sects.Title_Texts.To_String (Wanted.Items (Each).Title));
               Give_Notes (Keys (Total), Wanted.Items (Each).Notes);
            end if;
         end loop;
      end;
      for Each in 1 .. Have.Count loop
         if not Taken (Each) then
            Total := Total + 1;
            Keys (Total) := Have.Items (Each).Key;
         end if;
      end loop;
      pragma Assert (Total <= Sects.Max_Sections and then Kept <= Have.Count);
      Sects.Set_Order (Item.Nav.Store, Owner, Keys (1 .. Total));
      --  The blocks now show other sections: nothing is typed in one.
      Widgets.Clear_Focus (Item.Root.Widgets);
      Support.Load_Sections (Item, Owner);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Apply;

   procedure Generate_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if not Support.In_Outline (Item) then
         return;
      end if;
      if Buttons.Caret_Clicked (Item.Outline_View.Generate_Button) then
         if Item.Outline_View.Generate_Open then
            Close_Menu (Item);
         else
            Open_Menu (Item);
         end if;
      else
         Close_Menu (Item);
         Generate_Sections (Item, Item.Outline_View.With_Notes);
      end if;
   end Generate_Clicked;

   procedure Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Item.Outline_View.Generate_Open and then Event.Row in 1 .. 2 and then Support.In_Outline (Item) then
         Choose_Generate (Item, Event.Row);
      end if;
   end Chosen;

end Viewer.Outlines.Generation;
