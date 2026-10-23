with Ada.Strings.Unbounded;
with MLX;
with MLX.Jobs;
with Outline_Generation;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Preferences;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;
with Viewer.Navigation;
with Viewer.Settings_View;
with Viewer.Style;
with Viewer.Outlines.Blocks;
with Viewer.Outlines.Clicks;
with Viewer.Outlines.Generation;
with Viewer.Outlines.Support;

package body Viewer.Outlines is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Docs renames Texts.Documents;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Docs.Version;
   use type Projects.Id;
   use type Projects.Sections.Section_Id;
   use type MLX.Jobs.States;

   Untitled_Section : constant String := "Untitled section";

   function Section_Count (Item : Session) return Natural is
     (Item.Outline_View.Order.Count);

   function Section_Title (Item : Session; Which : Positive) return String is
     (Projects.Sections.Title_Texts.To_String
        (Item.Outline_View.Order (Which).Title));

   function Section_At (Item : Session; Which : Positive) return Projects.Sections.Section is
     (Item.Outline_View.Order (Which));

   function Index_Of_Key (Item : Session; Key : Projects.Sections.Section_Id) return Natural is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Place in 1 .. View.Order.Count loop
         if View.Order (Place).Key = Key then
            return Place;
         end if;
      end loop;
      return 0;
   end Index_Of_Key;

   function Section_Of_Item (Item : Session; Key : Long_Integer) return Natural is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in 1 .. View.Links.Count loop
         if View.Links (Each).Item = Key then
            for Place in 1 .. View.Order.Count loop
               if View.Order (Place).Key = View.Links (Each).Section then
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
         if View.Links (Each).Section = View.Order (Which).Key then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Documents_In;

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
              Support.Trimmed (Docs.Whole (View.Name_Doc));
         begin
            --  A project is not left without a name.
            if Name /= "" then
               Projects.Rename
                 (Item.Nav.Store, Item.Opened.Current,
                  Name);
               Navigation.Show_Title_Of_Project (Item);
            end if;
         end;
      end if;
      if Docs.Current (View.Desc_Doc) /= View.Desc_Seen then
         View.Desc_Seen := Docs.Current (View.Desc_Doc);
         Projects.Set_Description
           (Item.Nav.Store, Item.Opened.Current,
            Docs.Stored (View.Desc_Doc));
      end if;
      for Each in 1 .. View.Order.Count loop
         declare
            Block : Section_Block renames View.Blocks (Each);
         begin
            if Docs.Current (Block.Doc) /= Block.Seen then
               Block.Seen := Docs.Current (Block.Doc);
               declare
                  Name  : constant String :=
                    Docs.Whole (Block.Doc);
               begin
                  declare
                     Section : Projects.Sections.Section renames View.Order (Each);
                  begin
                     Section.Title := Projects.Sections.Title_Texts.To_Text (Name);
                  end;
                  Projects.Sections.Rename
                    (Item.Nav.Store, View.Order (Each).Key, Name);
               end;
            end if;
            if Docs.Current (Block.Notes_Doc) /= Block.Notes_Seen then
               Block.Notes_Seen := Docs.Current (Block.Notes_Doc);
               declare
                  Notes : constant String :=
                    Docs.Whole (Block.Notes_Doc);
               begin
                  declare
                     Section : Projects.Sections.Section renames View.Order (Each);
                  begin
                     Section.Notes := Projects.Sections.Note_Texts.To_Text (Notes);
                  end;
                  Projects.Sections.Set_Stored_Notes
                    (Item.Nav.Store, View.Order (Each).Key, Docs.Stored (Block.Notes_Doc));
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
         Docs.Load_Stored (View.Desc_Doc, Projects.Stored_Description (Item.Nav.Store, Result.Key));
         View.Desc_Seen := Docs.Current (View.Desc_Doc);
      end if;
   end Load_Form;

   procedure Reload (Item : in out Session) is
   begin
      if Item.Toolbar.Mode = Outline then
         Sync (Item);
      end if;
      Support.Load_Sections (Item, Item.Opened.Current);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Reload;

   procedure Enter (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Generate_Tries = 0 then
         Generation.Show_Note (Item, "", Style.Quiet_Ink);
      end if;
      View.Drag_Block := 0;
      View.Drag_Moved := False;
      View.Drop_Before := 0;
      Load_Form (Item);
      View.Order.Count := 0;
      Support.Load_Sections (Item, Item.Opened.Current);
      Blocks.Show_Blocks (Item);
      Blocks.Show_Drop_Line (Item);
      Generation.Show_Generate (Item);
   end Enter;

   procedure Leave (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Close_Menu (Item);
      View.Colour_Key := 0;
      Widgets.Set_Visible (View.Colour_Popout, False);
      Sync (Item);
      View.Drag_Block := 0;
      View.Drag_Moved := False;
      View.Drop_Before := 0;
      View.Order.Count := 0;
      View.Links.Count := 0;
      Blocks.Show_Blocks (Item);
      Blocks.Show_Drop_Line (Item);
      Blocks.Show_Ghost (Item);
   end Leave;

   procedure Shown (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Found  : Boolean;
      Result : Projects.Project;
   begin
      Sync (Item);
      Generation.Show_Generate (Item);
      --  The project may have been renamed on the toolbar.
      Projects.Find (Item.Nav.Store, Item.Opened.Current, Found, Result);
      if Found
        and then Projects.Titles.To_String (Result.Title)
                 /= Support.Trimmed (Docs.Whole (View.Name_Doc))
      then
         Docs.Load (View.Name_Doc, Projects.Titles.To_String (Result.Title));
         View.Name_Seen := Docs.Current (View.Name_Doc);
      end if;
   end Shown;

   --  What is done to the sections

   procedure Add_Section (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Sync (Item);
      declare
         Key : constant Projects.Sections.Section_Id :=
           Projects.Sections.Add (Item.Nav.Store, Item.Opened.Current, Untitled_Section);
      begin
         pragma Unreferenced (Key);
         --  As kept, with the colour it was given.
         Support.Load_Sections (Item, Item.Opened.Current);
      end;
      Blocks.Show_Blocks (Item);
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
         Moved : constant Projects.Sections.Section := View.Order (From);
      begin
         if From < To then
            for Each in From .. To - 1 loop
               View.Order (Each) := View.Order (Each + 1);
            end loop;
         else
            for Each in reverse To + 1 .. From loop
               View.Order (Each) := View.Order (Each - 1);
            end loop;
         end if;
         View.Order (To) := Moved;
      end;
      Blocks.Keep_Order (Item);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Move_Section;

   procedure Remove_Section (Item : in out Session; Which : Positive) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Sync (Item);
      Projects.Sections.Delete (Item.Nav.Store, View.Order (Which).Key);
      Projects.Sections.Load_Links (Item.Nav.Store, Item.Opened.Current, View.Links);
      View.Order.Delete (Which);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Remove_Section;

   procedure Toggle_Notes (Item : in out Session; Which : Positive; Focus : Boolean := True) is
      View  : Outline_Parts renames Item.Outline_View;
      Block : Section_Block renames View.Blocks (Which);
      Now_Open : constant Boolean := not View.Order (Which).Open;
   begin
      View.Order (Which).Open := Now_Open;
      Buttons.Set_Selected (Block.Notes, Now_Open);
      Widgets.Set_Visible (Block.Notes_Sheet, Now_Open);
      Widgets.Request_Layout (Block.Row);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if Now_Open and then Focus then
         Widgets.Focus (Block.Notes_Text);
      end if;
   end Toggle_Notes;

   function Section_Notes (Item : Session; Which : Positive) return String is
     (Projects.Sections.Note_Texts.To_String (Item.Outline_View.Order (Which).Notes));

   function Notes_Shown (Item : Session; Which : Positive) return Boolean is
     (Item.Outline_View.Order (Which).Open);

   --  Asking the model

   function Generating (Item : Session) return Boolean is (Item.Outline_View.Generate_Tries > 0);

   function Generate_Enabled (Item : Session) return Boolean is
     (Buttons.Is_Enabled (Item.Outline_View.Generate_Button));

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

   procedure Close_Menu (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Generate_Open then
         View.Generate_Open := False;
         Widgets.Set_Visible (View.Generate_Menu, False);
         Buttons.Set_Selected (View.Generate_Button, False);
      end if;
   end Close_Menu;

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
      if Widgets.Is_Visible (View.Colour_Popout)
        and then not Widgets.Contains (View.Colour_Popout, X * Pixels, Y * Pixels)
      then
         View.Colour_Key := 0;
         Widgets.Set_Visible (View.Colour_Popout, False);
      end if;
      if View.Generate_Open
        and then not Widgets.Contains (View.Generate_Menu, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (View.Generate_Button, X * Pixels, Y * Pixels)
      then
         Close_Menu (Item);
      end if;
   end Pressed;

   function Take_Reply (Item : in out Session; Reply : String) return Boolean is
      Parsed : Projects.Sections.Section_List;
      Valid  : Boolean;
   begin
      Outline_Generation.Parse (Reply, Parsed, Valid);
      if Valid then
         Generation.Apply (Item, Parsed);
      end if;
      return Valid;
   end Take_Reply;

   procedure Generate_Sections (Item : in out Session; With_Notes : Boolean) is
      View   : Outline_Parts renames Item.Outline_View;
      Located : Ada.Strings.Unbounded.Unbounded_String;
      Why     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Item.Prefs.AI_On or else Settings_View.Premium_Chosen (Item) or else Generating (Item) then
         return;
      end if;
      Settings_View.Locate_AI_Model (Item, Located, Why);
      if Ada.Strings.Unbounded.Length (Why) > 0 then
         Generation.Show_Note (Item, Ada.Strings.Unbounded.To_String (Why), Pomarine.Themes.Danger_Ink);
         return;
      end if;
      Sync (Item);
      View.Generate_Project := Item.Opened.Current;
      View.Generate_Notes := With_Notes;
      View.Generate_Folder := Located;
      View.Generate_Prompt :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Outline_Generation.Prompt
             (Support.Trimmed (Docs.Whole (View.Name_Doc)), Docs.Whole (View.Desc_Doc), View.Order));
      View.Generate_Tries := 1;
      Generation.Show_Note (Item, "Generating sections, this can take a while", Style.Quiet_Ink);
      Generation.Start_Try (Item);
      Generation.Show_Generate (Item);
   end Generate_Sections;

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
               Generation.Finish_Try (Item);
            when MLX.Jobs.Failed =>
               declare
                  Why : constant String := MLX.Jobs.Text (View.Generate_Job);
               begin
                  MLX.Jobs.Reset (View.Generate_Job);
                  if Item.Opened.Current = View.Generate_Project then
                     Generation.Give_Up (Item, (if Why = "" then "The AI could not make the outline" else Why));
                  else
                     View.Generate_Tries := 0;
                     Generation.Show_Note (Item, "", Style.Quiet_Ink);
                  end if;
               end;
            when MLX.Jobs.Cancelled =>
               MLX.Jobs.Reset (View.Generate_Job);
               View.Generate_Tries := 0;
               Generation.Show_Note (Item, "", Style.Quiet_Ink);
         end case;
      end if;
      if View.Colour_Key /= 0 and then not Support.In_Outline (Item) then
         View.Colour_Key := 0;
         Widgets.Set_Visible (View.Colour_Popout, False);
      end if;
      if View.Generate_Open then
         if Support.In_Outline (Item) and then Buttons.Is_Enabled (View.Generate_Button) then
            Generation.Place_Menu (Item);
         else
            Close_Menu (Item);
         end if;
      end if;
      Generation.Show_Generate (Item);
   end Update;

   --  What the widgets say

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
      Hear (Item.Outline_View.Colour_OK, Click, Clicks.Colour_Accepted'Access);
      Hear (Item.Outline_View.Colour_Cancel, Click, Clicks.Colour_Cancelled'Access);

      Hear (Item.Outline_View.Add_Button, Click, Clicks.Add_Clicked'Access);
      Hear (Item.Outline_View.Generate_Button, Click, Generation.Generate_Clicked'Access);
      Hear (Item.Outline_View.Generate_Menu, Choose, Generation.Chosen'Access);
   end Listen;

   procedure Listen_Block (Item : in out Session; Index : Positive) is
      use all type Widgets.Event_Kind;
      Block : Section_Block renames Item.Outline_View.Blocks (Index);

      procedure Hear
        (Part    : in out Widgets.Widget'Class;
         Kind    : Widgets.Event_Kind;
         Do_This : Hooks.Handler;
         Tag     : Natural := 0) is
      begin
         if Tag /= 0 then
            Widgets.Set_Tag (Part, Widgets.No_Tag, Tag);
         end if;
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      Hear (Block.Swatch, Click, Clicks.Colour_Clicked'Access, Index);
      Hear (Block.Row, Drag, Blocks.Block_Dragged'Access, Index);
      Hear (Block.Row, Release, Blocks.Block_Released'Access);
      Hear (Block.Field, Submit, Clicks.Title_Submitted'Access);
      Hear (Block.Notes, Click, Clicks.Notes_Clicked'Access, Index);
      Hear (Block.Up, Click, Clicks.Up_Clicked'Access, Index);
      Hear (Block.Down, Click, Clicks.Down_Clicked'Access, Index);
      Hear (Block.Remove, Click, Clicks.Remove_Clicked'Access, Index);
   end Listen_Block;

end Viewer.Outlines;
