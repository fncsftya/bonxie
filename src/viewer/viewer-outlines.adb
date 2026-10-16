with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
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
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Docs renames Texts.Documents;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Docs.Version;
   use type Projects.Id;

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

   procedure Enter (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      View.Drag_Block := 0;
      View.Drag_Moved := False;
      View.Drop_Before := 0;
      Load_Form (Item);
      Projects.Sections.Load (Item.Nav.Store, Item.Opened.Current, View.Order);
      Show_Blocks (Item);
      Show_Drop_Line (Item);
   end Enter;

   procedure Leave (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      Sync (Item);
      View.Drag_Block := 0;
      View.Drag_Moved := False;
      View.Drop_Before := 0;
      View.Order.Count := 0;
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
         View.Order.Count := View.Order.Count + 1;
         View.Order.Items (View.Order.Count) :=
           (Key   => Key,
            Title => Projects.Sections.Title_Texts.To_Bounded_String (Untitled_Section));
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
      View.Order.Items (Which .. View.Order.Count - 1) :=
        View.Order.Items (Which + 1 .. View.Order.Count);
      View.Order.Count := View.Order.Count - 1;
      Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Remove_Section;

   --  What the widgets say

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
      for Each in Item.Outline_View.Blocks'Range loop
         declare
            Block : Section_Block renames Item.Outline_View.Blocks (Each);
         begin
            Hear (Block.Row, Drag, Block_Dragged'Access, Each);
            Hear (Block.Row, Release, Block_Released'Access);
            Hear (Block.Field, Submit, Title_Submitted'Access);
            Hear (Block.Up, Click, Up_Clicked'Access, Each);
            Hear (Block.Down, Click, Down_Clicked'Access, Each);
            Hear (Block.Remove, Click, Remove_Clicked'Access, Each);
         end;
      end loop;
   end Listen;

end Viewer.Outlines;
