with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Unbounded;
with Icon_Set;
with MLX;
with MLX.Hub;
with MLX.Jobs;
with Outline_Generation;
with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Menus;
with Preferences;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;
with Viewer.Gestures;
with Viewer.Navigation;
with Viewer.Style;

package body Viewer.Outlines is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Menus renames Pomarine.Widgets.Menus;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Panels renames Pomarine.Widgets.Panels;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Docs renames Texts.Documents;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Docs.Version;
   use type Projects.Id;
   use type Projects.Sections.Section_Id;
   use type MLX.Jobs.States;

   Untitled_Section : constant String := "Untitled section";

   Drag_Threshold : constant Float := 4.0;
   --  How far, in points, a press on a block has to go to be a drag.

   subtype Source_Widget is Widgets.Widget'Class;

   function In_Outline (Item : Session) return Boolean is
     (Gestures.Active (Item) and then Item.Toolbar.Mode = Outline);
   --  Whether the outline is the view in use, and not under a dialog.

   function Cut (Content : String; Most : Positive) return String;
   --  Content, or its first Most bytes, less any part of a character.

   function Cut (Content : String; Most : Positive) return String is
      Last : Natural := Content'First - 1 + Natural'Min (Content'Length, Most);
   begin
      if Last < Content'Last then
         --  The next byte goes on a character that began in the part kept.
         while Last >= Content'First
           and then Character'Pos (Content (Last + 1)) in 16#80# .. 16#BF#
         loop
            Last := Last - 1;
         end loop;
      end if;
      return Content (Content'First .. Last);
   end Cut;

   function Trimmed (Content : String) return String;
   --  Without the spaces at either end.

   function Trimmed (Content : String) return String is
      First : Positive := Content'First;
      Last  : Natural := Content'Last;
   begin
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      return Content (First .. Last);
   end Trimmed;

   function Section_Count (Item : Session) return Natural is
     (Item.Outline_View.Order.Count);

   function Section_Title (Item : Session; Which : Positive) return String is
     (Projects.Sections.Title_Texts.To_String
        (Item.Outline_View.Order.Items (Which).Title));

   function Section_At (Item : Session; Which : Positive) return Projects.Sections.Section is
     (Item.Outline_View.Order.Items (Which));

   function Index_Of_Key (Item : Session; Key : Projects.Sections.Section_Id) return Natural is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Place in 1 .. View.Order.Count loop
         if View.Order.Items (Place).Key = Key then
            return Place;
         end if;
      end loop;
      return 0;
   end Index_Of_Key;

   function Section_Of_Item (Item : Session; Key : Long_Integer) return Natural is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in 1 .. View.Links.Count loop
         if View.Links.Items (Each).Item = Key then
            for Place in 1 .. View.Order.Count loop
               if View.Order.Items (Place).Key = View.Links.Items (Each).Section then
                  return Place;
               end if;
            end loop;
         end if;
      end loop;
      return 0;
   end Section_Of_Item;

   function Documents_In (Item : Session; Which : Positive) return Natural is
      View  : Outline_Parts renames Item.Outline_View;
      Total : Natural := 0;
   begin
      for Each in 1 .. View.Links.Count loop
         if View.Links.Items (Each).Section = View.Order.Items (Which).Key then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Documents_In;

   procedure Load_Sections (Item : in out Session; Owner : Projects.Id);
   --  Read the sections and their links again. A section shows its notes
   --  if it did, or if it has some now.

   procedure Load_Sections (Item : in out Session; Owner : Projects.Id) is
      View : Outline_Parts renames Item.Outline_View;
      Was  : constant Projects.Sections.Section_List := View.Order;
   begin
      Projects.Sections.Load (Item.Nav.Store, Owner, View.Order);
      Projects.Sections.Load_Links (Item.Nav.Store, Owner, View.Links);
      for Each in 1 .. View.Order.Count loop
         declare
            Section : Projects.Sections.Section renames View.Order.Items (Each);
         begin
            Section.Open := Projects.Sections.Note_Texts.Length (Section.Notes) > 0;
            for Before in 1 .. Was.Count loop
               if Was.Items (Before).Key = Section.Key then
                  Section.Open := Was.Items (Before).Open or else Section.Open;
               end if;
            end loop;
         end;
      end loop;
   end Load_Sections;

   --  What is shown

   procedure Style_Blocks (Item : in out Session);
   --  Outline the block being dragged, once it has moved.

   procedure Style_Blocks (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in 1 .. View.Order.Count loop
         if View.Drag_Block = Each and then View.Drag_Moved then
            Grips.Set_Border (View.Blocks (Each).Row, Pomarine.Themes.Focus);
         else
            Grips.Set_Border (View.Blocks (Each).Row, Pomarine.Themes.Border);
         end if;
      end loop;
   end Style_Blocks;

   procedure Show_Blocks (Item : in out Session);
   --  Show a block for each section, with its title, and the note that
   --  there are none if there are none.

   procedure Show_Blocks (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in View.Blocks'Range loop
         declare
            Block : Section_Block renames View.Blocks (Each);
         begin
            if Each <= View.Order.Count then
               Docs.Load
                 (Block.Doc,
                  Projects.Sections.Title_Texts.To_String (View.Order.Items (Each).Title));
               Block.Seen := Docs.Current (Block.Doc);
               Docs.Load
                 (Block.Notes_Doc,
                  Projects.Sections.Note_Texts.To_String (View.Order.Items (Each).Notes));
               Block.Notes_Seen := Docs.Current (Block.Notes_Doc);
               Buttons.Set_Selected (Block.Notes, View.Order.Items (Each).Open);
               Widgets.Set_Visible (Block.Notes_Sheet, View.Order.Items (Each).Open);
            end if;
            if Each <= View.Order.Count then
               declare
                  Section : constant Projects.Sections.Section := View.Order.Items (Each);
                  Ink     : constant Pomarine.Themes.Slot := Style.Section_Ink (Section.Colour);
               begin
                  if Documents_In (Item, Each) > 0 then
                     Panels.Set_Fill (Block.Swatch, Ink);
                  else
                     Panels.Set_Fill (Block.Swatch, Pomarine.Themes.Page);
                  end if;
                  Panels.Set_Border (Block.Swatch, Ink);
               end;
            end if;
            Widgets.Set_Visible (Block.Row, Each <= View.Order.Count);
            Buttons.Set_Enabled (Block.Up, Each > 1);
            Buttons.Set_Enabled (Block.Down, Each < View.Order.Count);
         end;
      end loop;
      Widgets.Set_Visible (View.None, View.Order.Count = 0);
      Buttons.Set_Enabled (View.Add_Button, View.Order.Count < Section_Capacity);
      Style_Blocks (Item);
   end Show_Blocks;

   procedure Show_Drop_Line (Item : in out Session);
   --  Put the line where a block would go between two, or hide it.

   procedure Show_Drop_Line (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      if View.Drop_Before = 0 or else View.Order.Count = 0 then
         Widgets.Set_Visible (View.Drop_Line, False);
         return;
      end if;
      declare
         First : Grips.Grip renames View.Blocks (1).Row;
         Gap   : constant Float := Style.Index_Gap * Pixels - Offset;
         Mid   : constant Float :=
           (if View.Drop_Before > View.Order.Count
            then Widgets.Top_Of (View.Blocks (View.Order.Count).Row)
                 + Widgets.Height_Of (View.Blocks (View.Order.Count).Row) + Gap / 2.0
            else Widgets.Top_Of (View.Blocks (View.Drop_Before).Row) - Gap / 2.0);
         Thick : constant Float := Style.Drop_Line_Height * Pixels;
      begin
         Layouts.Set_Layout
           (View.Drop_Line,
            Position =>
              (Left => Widgets.Left_Of (First) - Widgets.Left_Of (View.Content),
               Top  => Float'Max
                         (0.0, Float'Rounding
                                 (Mid - Thick / 2.0 - Widgets.Top_Of (View.Content))),
               others => <>),
            Width => Widgets.Width_Of (First) - Offset,
            Unit => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (View.Drop_Line, True);
      Widgets.Request_Layout (View.Drop_Line);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Drop_Line;

   procedure Show_Ghost (Item : in out Session);
   --  Put the ghost of the block dragged under the pointer, or hide it.

   procedure Show_Ghost (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      if View.Drag_Block = 0 or else not View.Drag_Moved
        or else View.Drag_Block > View.Order.Count
      then
         Widgets.Set_Visible (View.Ghost, False);
         return;
      end if;
      declare
         Held  : Grips.Grip renames View.Blocks (View.Drag_Block).Row;
         X, Y  : Float;
         High  : constant Float := Widgets.Height_Of (Held) - Offset;
         Least : constant Float := 0.0;
         Most  : constant Float :=
           Float'Max (Least, Widgets.Height_Of (View.Content) - High);
      begin
         Grips.Pointer (Held, X, Y);
         Layouts.Set_Layout
           (View.Ghost,
            Position =>
              (Left => Widgets.Left_Of (Held) - Widgets.Left_Of (View.Content),
               Top  => Float'Min
                         (Most, Float'Max
                                  (Least, Float'Rounding
                                            (Y * Pixels - High / 2.0
                                             - Widgets.Top_Of (View.Content)))),
               others => <>),
            Width  => Widgets.Width_Of (Held) - Offset,
            Height => High,
            Unit   => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (View.Ghost, True);
      Widgets.Request_Layout (View.Ghost);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Ghost;

   --  What is kept

   procedure Keep_Order (Item : in out Session);
   --  Write the order of the sections to the database.

   procedure Keep_Order (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
      Keys : constant Projects.Sections.Key_Array (1 .. View.Order.Count) :=
        [for Each in 1 .. View.Order.Count => View.Order.Items (Each).Key];
   begin
      Projects.Sections.Set_Order (Item.Nav.Store, Item.Opened.Current, Keys);
   end Keep_Order;

   procedure Sync (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if Item.Opened.Current = 0 then
         return;
      end if;
      if Docs.Current (View.Name_Doc) /= View.Name_Seen then
         View.Name_Seen := Docs.Current (View.Name_Doc);
         declare
            Name : constant String :=
              Trimmed (Docs.Whole (View.Name_Doc));
         begin
            --  A project is not left without a name.
            if Name /= "" then
               Projects.Rename
                 (Item.Nav.Store, Item.Opened.Current,
                  Cut (Name, Projects.Title_Capacity));
               Navigation.Show_Title_Of_Project (Item);
            end if;
         end;
      end if;
      if Docs.Current (View.Desc_Doc) /= View.Desc_Seen then
         View.Desc_Seen := Docs.Current (View.Desc_Doc);
         Projects.Set_Description
           (Item.Nav.Store, Item.Opened.Current,
            Cut (Docs.Whole (View.Desc_Doc), Projects.Description_Capacity));
      end if;
      for Each in 1 .. View.Order.Count loop
         declare
            Block : Section_Block renames View.Blocks (Each);
         begin
            if Docs.Current (Block.Doc) /= Block.Seen then
               Block.Seen := Docs.Current (Block.Doc);
               declare
                  Name  : constant String :=
                    Cut (Docs.Whole (Block.Doc), Projects.Sections.Max_Title);
               begin
                  View.Order.Items (Each).Title :=
                    Projects.Sections.Title_Texts.To_Bounded_String (Name);
                  Projects.Sections.Rename
                    (Item.Nav.Store, View.Order.Items (Each).Key, Name);
               end;
            end if;
            if Docs.Current (Block.Notes_Doc) /= Block.Notes_Seen then
               Block.Notes_Seen := Docs.Current (Block.Notes_Doc);
               declare
                  Notes : constant String :=
                    Cut (Docs.Whole (Block.Notes_Doc), Projects.Sections.Max_Notes);
               begin
                  View.Order.Items (Each).Notes :=
                    Projects.Sections.Note_Texts.To_Bounded_String (Notes);
                  Projects.Sections.Set_Notes
                    (Item.Nav.Store, View.Order.Items (Each).Key, Notes);
               end;
            end if;
         end;
      end loop;
   end Sync;

   procedure Load_Form (Item : in out Session);
   --  Show the project's title and description.

   procedure Load_Form (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Found  : Boolean;
      Result : Projects.Project;
   begin
      Projects.Find (Item.Nav.Store, Item.Opened.Current, Found, Result);
      if Found then
         Docs.Load (View.Name_Doc, Projects.Titles.To_String (Result.Title));
         View.Name_Seen := Docs.Current (View.Name_Doc);
         Docs.Load (View.Desc_Doc, Projects.Descriptions.To_String (Result.Description));
         View.Desc_Seen := Docs.Current (View.Desc_Doc);
      end if;
   end Load_Form;

   procedure Show_Generate (Item : in out Session);
   --  The button is on while AI is on and the model is not being asked.

   procedure Show_Note (Item : in out Session; Words : String; Ink : Pomarine.Themes.Slot);
   --  Say Words, as much as fits, under the heading in Ink; nothing if "".

   procedure Show_Note (Item : in out Session; Words : String; Ink : Pomarine.Themes.Slot) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Labels.Set_Text (View.Generate_Error, Labels.Fitted (Words));
      Labels.Set_Ink (View.Generate_Error, Ink);
      Widgets.Set_Visible (View.Generate_Error, Words /= "");
   end Show_Note;

   procedure Reload (Item : in out Session) is
   begin
      if Item.Toolbar.Mode = Outline then
         Sync (Item);
      end if;
      Load_Sections (Item, Item.Opened.Current);
      Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Reload;

   procedure Enter (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Generate_Tries = 0 then
         Show_Note (Item, "", Style.Quiet_Ink);
      end if;
      View.Drag_Block := 0;
      View.Drag_Moved := False;
      View.Drop_Before := 0;
      Load_Form (Item);
      View.Order.Count := 0;
      Load_Sections (Item, Item.Opened.Current);
      Show_Blocks (Item);
      Show_Drop_Line (Item);
      Show_Generate (Item);
   end Enter;

   procedure Leave (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Close_Menu (Item);
      Sync (Item);
      View.Drag_Block := 0;
      View.Drag_Moved := False;
      View.Drop_Before := 0;
      View.Order.Count := 0;
      View.Links.Count := 0;
      Show_Blocks (Item);
      Show_Drop_Line (Item);
      Show_Ghost (Item);
   end Leave;

   procedure Shown (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Found  : Boolean;
      Result : Projects.Project;
   begin
      Sync (Item);
      Show_Generate (Item);
      --  The project may have been renamed on the toolbar.
      Projects.Find (Item.Nav.Store, Item.Opened.Current, Found, Result);
      if Found
        and then Projects.Titles.To_String (Result.Title)
                 /= Trimmed (Docs.Whole (View.Name_Doc))
      then
         Docs.Load (View.Name_Doc, Projects.Titles.To_String (Result.Title));
         View.Name_Seen := Docs.Current (View.Name_Doc);
      end if;
   end Shown;

   --  What is done to the sections

   procedure Add_Section (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Order.Count = Section_Capacity then
         return;
      end if;
      Sync (Item);
      declare
         Key : constant Projects.Sections.Section_Id :=
           Projects.Sections.Add (Item.Nav.Store, Item.Opened.Current, Untitled_Section);
      begin
         pragma Unreferenced (Key);
         --  As kept, with the colour it was given.
         Load_Sections (Item, Item.Opened.Current);
      end;
      Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      declare
         Block  : Section_Block renames View.Blocks (View.Order.Count);
         Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      begin
         Scrollers.Scroll_To
           (View.Scroll,
            Float'Max (0.0, (Widgets.Top_Of (Block.Row) + Widgets.Height_Of (Block.Row)
                             - Widgets.Top_Of (View.Content)) / Pixels
                            - Widgets.Height_Of (View.Scroll) / Pixels));
         Widgets.Focus (Block.Field);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (Block.Field).all);
      end;
   end Add_Section;

   procedure Move_Section (Item : in out Session; From, To : Positive) is
      View  : Outline_Parts renames Item.Outline_View;
   begin
      if From = To then
         return;
      end if;
      Sync (Item);
      declare
         Moved : constant Projects.Sections.Section := View.Order.Items (From);
      begin
         if From < To then
            View.Order.Items (From .. To - 1) := View.Order.Items (From + 1 .. To);
         else
            View.Order.Items (To + 1 .. From) := View.Order.Items (To .. From - 1);
         end if;
         View.Order.Items (To) := Moved;
      end;
      Keep_Order (Item);
      Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Move_Section;

   procedure Remove_Section (Item : in out Session; Which : Positive) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Sync (Item);
      Projects.Sections.Delete (Item.Nav.Store, View.Order.Items (Which).Key);
      Projects.Sections.Load_Links (Item.Nav.Store, Item.Opened.Current, View.Links);
      View.Order.Items (Which .. View.Order.Count - 1) :=
        View.Order.Items (Which + 1 .. View.Order.Count);
      View.Order.Count := View.Order.Count - 1;
      Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Remove_Section;

   procedure Toggle_Notes (Item : in out Session; Which : Positive; Focus : Boolean := True) is
      View  : Outline_Parts renames Item.Outline_View;
      Block : Section_Block renames View.Blocks (Which);
      Now_Open : constant Boolean := not View.Order.Items (Which).Open;
   begin
      View.Order.Items (Which).Open := Now_Open;
      Buttons.Set_Selected (Block.Notes, Now_Open);
      Widgets.Set_Visible (Block.Notes_Sheet, Now_Open);
      Widgets.Request_Layout (Block.Row);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if Now_Open and then Focus then
         Widgets.Focus (Block.Notes_Text);
      end if;
   end Toggle_Notes;

   function Section_Notes (Item : Session; Which : Positive) return String is
     (Projects.Sections.Note_Texts.To_String (Item.Outline_View.Order.Items (Which).Notes));

   function Notes_Shown (Item : Session; Which : Positive) return Boolean is
     (Item.Outline_View.Order.Items (Which).Open);

   --  Asking the model

   function Generating (Item : Session) return Boolean is (Item.Outline_View.Generate_Tries > 0);

   function Generate_Enabled (Item : Session) return Boolean is
     (Buttons.Is_Enabled (Item.Outline_View.Generate_Button));

   procedure Show_Generate (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
      Want : constant Boolean := Item.Prefs.AI_On and then not Generating (Item);
   begin
      if Buttons.Is_Enabled (View.Generate_Button) /= Want then
         Buttons.Set_Enabled (View.Generate_Button, Want);
      end if;
   end Show_Generate;

   function Generate_Label (With_Notes : Boolean) return String is
     (if With_Notes then "Generate + Notes" else "Generate Sections");

   procedure Show_Choice (Item : in out Session) is
   begin
      Buttons.Set_Label (Item.Outline_View.Generate_Button, Generate_Label (Item.Outline_View.With_Notes));
   end Show_Choice;

   function Generate_Menu_Shown (Item : Session) return Boolean is (Item.Outline_View.Generate_Open);

   procedure Generate_Point (Item : in out Session; Caret : Boolean; X, Y : out Float) is
      Button : Buttons.Button renames Item.Outline_View.Generate_Button;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Side   : constant Float := Float'Rounding (Widgets.Height_Of (Button));
      Right  : constant Float := Widgets.Left_Of (Button) + Widgets.Width_Of (Button);
   begin
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      X := (if Caret then Right - Side / 2.0 else Widgets.Left_Of (Button) + Widgets.Width_Of (Button) / 4.0) / Pixels;
      Y := (Widgets.Top_Of (Button) + Widgets.Height_Of (Button) / 2.0) / Pixels;
   end Generate_Point;

   procedure Place_Menu (Item : in out Session);
   --  Put the menu under the button, its right edge by the button's.

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

   procedure Close_Menu (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Generate_Open then
         View.Generate_Open := False;
         Widgets.Set_Visible (View.Generate_Menu, False);
         Buttons.Set_Selected (View.Generate_Button, False);
      end if;
   end Close_Menu;

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

   procedure Choose_Generate (Item : in out Session; Row : Positive) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Close_Menu (Item);
      View.With_Notes := Row = 2;
      Show_Choice (Item);
      if Item.Prefs.Persist then
         Preferences.Save_Generate_Notes
           (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir), View.With_Notes);
      end if;
      Generate_Sections (Item, View.With_Notes);
   end Choose_Generate;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if View.Generate_Open
        and then not Widgets.Contains (View.Generate_Menu, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (View.Generate_Button, X * Pixels, Y * Pixels)
      then
         Close_Menu (Item);
      end if;
   end Pressed;

   procedure Apply (Item : in out Session; Wanted : Projects.Sections.Section_List)
     with Pre => Item.Opened.Current /= 0 and then Wanted.Count > 0;
   --  Make the outline the sections of Wanted, in order. A section that is
   --  already there, by its title, is kept, as it is; those the model left
   --  out go after the rest, and are not lost.

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
      Load_Sections (Item, Owner);
      Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Apply;

   function Take_Reply (Item : in out Session; Reply : String) return Boolean is
      Parsed : Projects.Sections.Section_List;
      Valid  : Boolean;
   begin
      Outline_Generation.Parse (Reply, Parsed, Valid);
      if Valid then
         Apply (Item, Parsed);
      end if;
      return Valid;
   end Take_Reply;

   procedure Start_Try (Item : in out Session);
   --  Ask the model, thinking first, for the outline.

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

   procedure Give_Up (Item : in out Session; Words : String);
   --  The work is over, and did not come out: say why.

   procedure Give_Up (Item : in out Session; Words : String) is
   begin
      Item.Outline_View.Generate_Tries := 0;
      Show_Note (Item, Words, Pomarine.Themes.Danger_Ink);
   end Give_Up;

   procedure Generate_Sections (Item : in out Session; With_Notes : Boolean) is
      View   : Outline_Parts renames Item.Outline_View;
      Name   : constant String := Ada.Strings.Unbounded.To_String (Item.Prefs.AI_Model);
      Folder : constant String := (if Name = "" then "" else MLX.Hub.Snapshot (Name));
      Reason : constant String :=
        (if Name = "" then "Choose an AI model in Settings"
         elsif Folder = "" then "The AI model is not in the cache"
         elsif Folder'Length > MLX.Max_Path then "The model's folder is too deep"
         else MLX.Problem (Folder));
   begin
      if not Item.Prefs.AI_On or else Generating (Item) then
         return;
      end if;
      if Reason /= "" then
         Show_Note (Item, Reason, Pomarine.Themes.Danger_Ink);
         return;
      end if;
      Sync (Item);
      View.Generate_Project := Item.Opened.Current;
      View.Generate_Notes := With_Notes;
      View.Generate_Folder := Ada.Strings.Unbounded.To_Unbounded_String (Folder);
      View.Generate_Prompt :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Outline_Generation.Prompt
             (Trimmed (Docs.Whole (View.Name_Doc)), Docs.Whole (View.Desc_Doc), View.Order));
      View.Generate_Tries := 1;
      Show_Note (Item, "Generating sections, this can take a while", Style.Quiet_Ink);
      Start_Try (Item);
      Show_Generate (Item);
   end Generate_Sections;

   procedure Finish_Try (Item : in out Session);
   --  The model has replied: use the sections, or ask again.

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

   procedure Update (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if Generating (Item) then
         case MLX.Jobs.State (View.Generate_Job) is
            when MLX.Jobs.Idle =>
               View.Generate_Tries := 0;
            when MLX.Jobs.Running =>
               if Item.Opened.Current /= View.Generate_Project then
                  MLX.Jobs.Cancel (View.Generate_Job);
               end if;
            when MLX.Jobs.Done =>
               Finish_Try (Item);
            when MLX.Jobs.Failed =>
               declare
                  Why : constant String := MLX.Jobs.Text (View.Generate_Job);
               begin
                  MLX.Jobs.Reset (View.Generate_Job);
                  if Item.Opened.Current = View.Generate_Project then
                     Give_Up (Item, (if Why = "" then "The AI could not make the outline" else Why));
                  else
                     View.Generate_Tries := 0;
                     Show_Note (Item, "", Style.Quiet_Ink);
                  end if;
               end;
            when MLX.Jobs.Cancelled =>
               MLX.Jobs.Reset (View.Generate_Job);
               View.Generate_Tries := 0;
               Show_Note (Item, "", Style.Quiet_Ink);
         end case;
      end if;
      if View.Generate_Open then
         if In_Outline (Item) and then Buttons.Is_Enabled (View.Generate_Button) then
            Place_Menu (Item);
         else
            Close_Menu (Item);
         end if;
      end if;
      Show_Generate (Item);
   end Update;

   --  What the widgets say

   procedure Generate_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Chosen
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Chosen
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Item.Outline_View.Generate_Open and then Event.Row in 1 .. 2 and then In_Outline (Item) then
         Choose_Generate (Item, Event.Row);
      end if;
   end Chosen;

   procedure Generate_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if not In_Outline (Item) then
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

   procedure Add_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Add_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if In_Outline (Item) then
         Add_Section (Item);
      end if;
   end Add_Clicked;

   procedure Up_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Up_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if In_Outline (Item) and then Event.Index in 2 .. Item.Outline_View.Order.Count then
         Move_Section (Item, Event.Index, Event.Index - 1);
      end if;
   end Up_Clicked;

   procedure Down_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Down_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if In_Outline (Item) and then Event.Index in 1 .. Item.Outline_View.Order.Count - 1 then
         Move_Section (Item, Event.Index, Event.Index + 1);
      end if;
   end Down_Clicked;

   procedure Remove_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Remove_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if In_Outline (Item) and then Event.Index in 1 .. Item.Outline_View.Order.Count then
         Remove_Section (Item, Event.Index);
      end if;
   end Remove_Clicked;

   procedure Notes_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Notes_Clicked
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if In_Outline (Item) and then Event.Index in 1 .. Item.Outline_View.Order.Count then
         Toggle_Notes (Item, Event.Index);
      end if;
   end Notes_Clicked;

   procedure Title_Submitted
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);
   --  Return in a section's title: it is done with.

   procedure Title_Submitted
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if In_Outline (Item) then
         Widgets.Clear_Focus (Item.Root.Widgets);
      end if;
   end Title_Submitted;

   function Drop_Before (Item : Session; Y : Float) return Natural;
   --  Which block the one dragged would go in front of, if let go at Y
   --  points down the window: Count + 1 for last; 0 where it already is.

   function Drop_Before (Item : Session; Y : Float) return Natural is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Point  : constant Float := Y * Pixels;
      Before : Positive := View.Order.Count + 1;
   begin
      for Each in 1 .. View.Order.Count loop
         declare
            Row : Grips.Grip renames View.Blocks (Each).Row;
         begin
            if Point < Widgets.Top_Of (Row) + Widgets.Height_Of (Row) / 2.0 then
               Before := Each;
               exit;
            end if;
         end;
      end loop;
      return (if Before in View.Drag_Block .. View.Drag_Block + 1 then 0 else Before);
   end Drop_Before;

   procedure Block_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Block_Dragged
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      View : Outline_Parts renames Item.Outline_View;
      Row  : constant Natural := Event.Index;
   begin
      if not In_Outline (Item) or else Row not in 1 .. View.Order.Count then
         return;
      end if;
      if View.Drag_Block = 0 then
         View.Drag_Block := Row;
         View.Drag_Total := 0.0;
         View.Drag_Moved := False;
         View.Drop_Before := 0;
      end if;
      if View.Drag_Block /= Row then
         return;
      end if;
      View.Drag_Total := View.Drag_Total + abs Event.Across + abs Event.Down;
      if View.Drag_Total >= Drag_Threshold and then not View.Drag_Moved then
         View.Drag_Moved := True;
         Style_Blocks (Item);
         declare
            Words : constant String := Section_Title (Item, Row);
         begin
            Labels.Set_Text
              (View.Ghost_Title,
               Words (Words'First ..
                      Words'First - 1
                      + Natural'Min (Words'Length, Labels.Text_Capacity)));
         end;
      end if;
      if View.Drag_Moved then
         declare
            X, Y   : Float;
            Before : Natural;
         begin
            Grips.Pointer (View.Blocks (Row).Row, X, Y);
            Before := Drop_Before (Item, Y);
            if Before /= View.Drop_Before then
               View.Drop_Before := Before;
               Show_Drop_Line (Item);
            end if;
            Show_Ghost (Item);
         end;
      end if;
   end Block_Dragged;

   procedure Block_Released
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Block_Released
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Drag_Block = 0 or else View.Drag_Block /= Event.Index then
         return;
      end if;
      declare
         Held   : constant Positive := View.Drag_Block;
         Before : constant Natural := View.Drop_Before;
         Moved  : constant Boolean := View.Drag_Moved;
      begin
         View.Drag_Block := 0;
         View.Drag_Moved := False;
         View.Drop_Before := 0;
         Show_Drop_Line (Item);
         Show_Ghost (Item);
         if Moved and then Before /= 0 and then In_Outline (Item) then
            Move_Section (Item, Held, (if Before > Held then Before - 1 else Before));
         else
            Style_Blocks (Item);
         end if;
      end;
   end Block_Released;

   procedure Listen (Item : in out Session) is
      use all type Widgets.Event_Kind;

      procedure Hear
        (Part    : in out Widgets.Widget'Class;
         Kind    : Widgets.Event_Kind;
         Do_This : Hooks.Handler;
         Index   : Natural := 0) is
      begin
         if Index /= 0 then
            Widgets.Set_Tag (Part, Widgets.No_Tag, Index);
         end if;
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      Hear (Item.Outline_View.Add_Button, Click, Add_Clicked'Access);
      Hear (Item.Outline_View.Generate_Button, Click, Generate_Clicked'Access);
      Hear (Item.Outline_View.Generate_Menu, Choose, Chosen'Access);
      for Each in Item.Outline_View.Blocks'Range loop
         declare
            Block : Section_Block renames Item.Outline_View.Blocks (Each);
         begin
            Hear (Block.Row, Drag, Block_Dragged'Access, Each);
            Hear (Block.Row, Release, Block_Released'Access);
            Hear (Block.Field, Submit, Title_Submitted'Access);
            Hear (Block.Notes, Click, Notes_Clicked'Access, Each);
            Hear (Block.Up, Click, Up_Clicked'Access, Each);
            Hear (Block.Down, Click, Down_Clicked'Access, Each);
            Hear (Block.Remove, Click, Remove_Clicked'Access, Each);
         end;
      end loop;
   end Listen;

end Viewer.Outlines;
