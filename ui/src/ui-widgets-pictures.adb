with SDL3.Pictures;
with SDL3.Pictures.Jobs;

package body UI.Widgets.Pictures is

   package Textures renames SDL3.Windows.Renderers.Textures;
   package Jobs renames SDL3.Pictures.Jobs;

   use type Jobs.States;

   Poll : constant := 10;
   --  Milliseconds between looks for a picture being read.

   procedure Stop_Loading (Item : in out Picture);
   --  Give up the picture being read, if any.

   procedure Stop_Loading (Item : in out Picture) is
   begin
      if Item.Job /= 0 then
         Jobs.Cancel (Item.Job);
         Item.Job := 0;
      end if;
   end Stop_Loading;

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type Vision.Result_Access;

   function File_Name (Item : Picture) return String is
     (Item.Name (1 .. Item.Length));

   function Has_Picture (Item : Picture) return Boolean is (Item.Loaded);

   function Has_Failed (Item : Picture) return Boolean is (Item.Failed);

   function Scrolled (Item : Picture) return Float is (Item.Down);

   function Scrolled_Across (Item : Picture) return Float is (Item.Across);

   procedure Scroll_Across_To (Item : in out Picture; To : Float) is
   begin
      if To /= Item.Across then
         Item.Across := To;
         Invalidate (Item);
      end if;
   end Scroll_Across_To;

   function Zoom (Item : Picture) return Float is (Item.Zoomed);

   function Tool (Item : Picture) return Tools is (Item.Chosen);

   function Is_Marking (Item : Picture) return Boolean is (Item.Marking);

   function Mark_Count (Item : Picture) return Natural is (Item.Marks);

   function Mark_At (Item : Picture; Index : Positive) return Mark is
     (Item.Marked (Index));

   function Marks_Version (Item : Picture) return Natural is (Item.Version);

   overriding function Cursor (Item : Picture) return SDL3.Cursors.Kind is
     (case Item.Chosen is
         when Highlighter => SDL3.Cursors.Crosshair,
         when Eraser      => SDL3.Cursors.Pointer,
         when Pointer     => SDL3.Cursors.Default);

   procedure Set_Tool (Item : in out Picture; To : Tools) is
   begin
      Item.Chosen := To;
      if Item.Marking then
         Item.Marking := False;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Tool;

   procedure Set_Marks (Item : in out Picture; To : Mark_Array) is
   begin
      Item.Marking := False;
      Item.Marks := To'Length;
      Item.Marked (1 .. To'Length) := To;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Marks;

   procedure Clear_Marks (Item : in out Picture) is
   begin
      Item.Marking := False;
      if Item.Marks > 0 then
         Item.Marks := 0;
         Item.Version := Item.Version + 1;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Marks;

   function Has_Words (Item : Picture) return Boolean is
     (Item.Found /= null and then Item.Found.Count > 0);

   function Word_Count (Item : Picture) return Natural is
     (if Item.Found = null then 0 else Item.Found.Count);

   function Has_Selection (Item : Picture) return Boolean is
     (Item.Anchor > 0 and then Item.Head > 0);

   function First_Selected (Item : Picture) return Natural is
     (Natural'Min (Item.Anchor, Item.Head));

   function Last_Selected (Item : Picture) return Natural is
     (Natural'Max (Item.Anchor, Item.Head));

   function Selected_Text (Item : Picture) return String is
      Result : String (1 .. Vision.Text_Capacity + Vision.Max_Words);
      Last   : Natural := 0;

      procedure Append (Text : String) is
      begin
         Result (Last + 1 .. Last + Text'Length) := Text;
         Last := Last + Text'Length;
      end Append;
   begin
      if not Has_Selection (Item) or else Item.Found = null then
         return "";
      end if;
      for Index in First_Selected (Item) .. Last_Selected (Item) loop
         if Index > First_Selected (Item) then
            Append
              (if Item.Found.Words (Index).Line
                    = Item.Found.Words (Index - 1).Line
               then " " else [ASCII.LF]);
         end if;
         Append (Vision.Image (Item.Found.Words (Index), Item.Found.all));
      end loop;
      return Result (1 .. Last);
   end Selected_Text;

   procedure Select_Range (Item : in out Picture; From, To : Natural) is
   begin
      if Item.Anchor /= From or else Item.Head /= To then
         Item.Anchor := From;
         Item.Head := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Select_Range;

   procedure Clear_Selection (Item : in out Picture) is
   begin
      Select_Range (Item, 0, 0);
   end Clear_Selection;

   procedure Select_All (Item : in out Picture) is
   begin
      if Has_Words (Item) then
         Select_Range (Item, 1, Item.Found.Count);
      end if;
   end Select_All;

   procedure Set_Words
     (Item : in out Picture; Found : Vision.Result_Access) is
   begin
      Item.Found := Found;
      Item.Held := False;
      Clear_Selection (Item);
   end Set_Words;

   --  Where the picture is, in pixels, as of the last draw.

   function Wide_Of (Item : Picture) return Float is
     (Width_Of (Item) * Item.Zoomed);

   function Down_Metrics (Item : Picture) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   => Item.Down * Item.Fitted,
      Shown   => Height_Of (Item),
      Total   => Item.Fitted,
      Horizontal => False);

   function Across_Metrics (Item : Picture) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   =>
        Item.Across * Float'Max (0.0, Wide_Of (Item) - Width_Of (Item)),
      Shown   => Width_Of (Item),
      Total   => Wide_Of (Item),
      Horizontal => True);

   function Origin_X (Item : Picture) return Float is
     (Left_Of (Item)
      - Item.Across * Float'Max (0.0, Wide_Of (Item) - Width_Of (Item)));

   function Origin_Y (Item : Picture) return Float is
     (Top_Of (Item) - Item.Down * Item.Fitted);

   function Word_Box (Item : Picture; Index : Positive) return Pixel_Box is
      Each : Vision.Word renames Item.Found.Words (Index);
   begin
      if Item.Fitted <= 0.0 then
         return (others => 0);
      end if;
      return
        (Left   => Integer (Origin_X (Item) + Each.Left * Wide_Of (Item)),
         Top    => Integer (Origin_Y (Item) + Each.Top * Item.Fitted),
         Width  => Integer (Each.Width * Wide_Of (Item)),
         Height => Integer (Each.Height * Item.Fitted));
   end Word_Box;

   function Along (Item : Picture; X : Float) return Float is
     (Float'Min
        (1.0, Float'Max (0.0, (X - Origin_X (Item)) / Wide_Of (Item))));
   --  How far across the picture the pixel X is, clamped to it.

   function Down_Of (Item : Picture; Y : Float) return Float is
     (Float'Min (1.0, Float'Max (0.0, (Y - Origin_Y (Item)) / Item.Fitted)));

   function Being_Made (Item : Picture; X : Float) return Mark is
      Now : constant Float := Along (Item, X);
   begin
      return (Left  => Float'Min (Item.Started, Now),
              Right => Float'Max (Item.Started, Now),
              Y     => Item.Marked (Item.Marks + 1).Y);
   end Being_Made;
   --  The mark as dragged to pixel X.

   function Mark_Under (Item : Picture; X, Y : Float) return Natural is
      Across : constant Float := Along (Item, X);
      Half   : constant Float := Mark_Height * Wide_Of (Item) / 2.0;
   begin
      for Index in reverse 1 .. Item.Marks loop
         if Across in Item.Marked (Index).Left .. Item.Marked (Index).Right
           and then abs (Y - (Origin_Y (Item)
                              + Item.Marked (Index).Y * Item.Fitted)) <= Half
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Mark_Under;
   --  The latest mark at pixel X, Y, 0 if none.

   procedure Handle_Marking
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Density (Item);
      Y : constant Float := Event.Mouse_Y * Density (Item);
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, X, Y)
              and then Item.Chosen = Eraser
            then
               declare
                  Under : constant Natural := Mark_Under (Item, X, Y);
               begin
                  if Under > 0 then
                     Item.Marked (Under .. Item.Marks - 1) :=
                       Item.Marked (Under + 1 .. Item.Marks);
                     Item.Marks := Item.Marks - 1;
                     Item.Version := Item.Version + 1;
                     Invalidate (Item);
                  end if;
                  Handled := True;
               end;
            elsif Event.Button = 1 and then Contains (Item, X, Y) then
               Item.Marking := True;
               Item.Started := Along (Item, X);
               Item.Marked (Item.Marks + 1) :=
                 (Left | Right => Item.Started, Y => Down_Of (Item, Y));
               Clear_Selection (Item);
               Invalidate (Item);
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Marking then
               Item.Marked (Item.Marks + 1) := Being_Made (Item, X);
               Invalidate (Item);
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Item.Marking and then Event.Button = 1 then
               Item.Marking := False;
               Item.Marked (Item.Marks + 1) := Being_Made (Item, X);
               --  A click, that went nowhere, marks nothing.
               if Item.Marks < Max_Marks
                 and then Item.Marked (Item.Marks + 1).Right
                          - Item.Marked (Item.Marks + 1).Left > 0.002
               then
                  Item.Marks := Item.Marks + 1;
                  Item.Version := Item.Version + 1;
               end if;
               Invalidate (Item);
               Handled := True;
            end if;
         when others =>
            null;
      end case;
   end Handle_Marking;

   function Gap (From, To, At_Point : Float) return Float is
     (if At_Point < From then From - At_Point
      elsif At_Point > To then At_Point - To else 0.0);
   --  How far a point is from the span From .. To.

   function Word_At
     (Item : Picture; X, Y : Float; Nearest : Boolean) return Natural
   is
      Best     : Natural := 0;
      Best_Gap : Float := Float'Last;
      Wide     : constant Float := Wide_Of (Item);
      Left     : constant Float := Origin_X (Item);
      Top      : constant Float := Origin_Y (Item);
   begin
      if Item.Found = null or else Item.Fitted <= 0.0 then
         return 0;
      end if;
      for Index in 1 .. Item.Found.Count loop
         declare
            Each   : Vision.Word renames Item.Found.Words (Index);
            Across : constant Float :=
              Gap (Left + Each.Left * Wide,
                   Left + (Each.Left + Each.Width) * Wide, X);
            Down   : constant Float :=
              Gap (Top + Each.Top * Item.Fitted,
                   Top + (Each.Top + Each.Height) * Item.Fitted, Y);
            --  Down counts for more: the nearest on its line is the one
            --  wanted, before one above or below.
            Away   : constant Float := Across + 4.0 * Down;
         begin
            if Away < Best_Gap then
               Best_Gap := Away;
               Best := Index;
            end if;
         end;
      end loop;
      return (if Nearest or else Best_Gap = 0.0 then Best else 0);
   end Word_At;

   procedure Select_Line (Item : in out Picture; Index : Positive) is
      Line  : constant Natural := Item.Found.Words (Index).Line;
      First : Positive := Index;
      Last  : Positive := Index;
   begin
      while First > 1 and then Item.Found.Words (First - 1).Line = Line loop
         First := First - 1;
      end loop;
      while Last < Item.Found.Count
        and then Item.Found.Words (Last + 1).Line = Line
      loop
         Last := Last + 1;
      end loop;
      Select_Range (Item, First, Last);
   end Select_Line;

   overriding function Accepts_Focus (Item : Picture) return Boolean is
     (Has_Words (Item));

   overriding procedure Focus_Changed
     (Item : in out Picture; Focused : Boolean)
   is
      pragma Unreferenced (Focused);
   begin
      if Has_Selection (Item) then
         Invalidate (Item);
      end if;
   end Focus_Changed;

   procedure Set_Zoom (Item : in out Picture; To : Float) is
   begin
      if To /= Item.Zoomed then
         Item.Zoomed := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Zoom;

   procedure Set_File (Item : in out Picture; Path : String) is
   begin
      Stop_Loading (Item);
      Item.Length := Path'Length;
      Item.Name (1 .. Item.Length) := Path;
      Item.Loaded := False;
      Item.Failed := False;
      Item.Down := 0.0;
      Item.Across := 0.0;
      Item.Fitted := 0.0;
      Textures.Release (Item.Pixels);
      Item.Wide := 0;
      Item.High := 0;
      if Path /= "" then
         SDL3.Pictures.Size (Path, Item.Wide, Item.High);
      end if;
      Item.Held := False;
      Item.Anchor := 0;
      Item.Head := 0;
      Item.Marking := False;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_File;

   procedure Load_Soon (Item : in out Picture; Urgent : Boolean) is
   begin
      if Item.Length = 0 or else Item.Loaded or else Item.Failed then
         return;
      elsif Item.Job /= 0 then
         if Urgent then
            Jobs.Prioritize (Item.Job);
         end if;
      else
         Jobs.Request (File_Name (Item), Urgent, Item.Job);
      end if;
   end Load_Soon;

   procedure Unload (Item : in out Picture) is
   begin
      Stop_Loading (Item);
      Textures.Release (Item.Pixels);
      Item.Loaded := False;
      Item.Failed := False;
   end Unload;

   function Furthest (Item : Picture; High : Float) return Float is
     (if Item.Fitted <= 0.0 then 1.0
      elsif High > 0.0 and then Item.Fitted > High
      then 1.0 - High / Item.Fitted else 0.0);
   --  The most Down can be, for a box High pixels high, so that the
   --  picture's end is at the box's; 1.0 until the size of the picture is
   --  known, when it is drawn.

   procedure Scroll_To (Item : in out Picture; To : Float) is
      Wanted : constant Float :=
        Float'Min (To, Furthest (Item, Height_Of (Item)));
   begin
      if Wanted /= Item.Down then
         Item.Down := Wanted;
         Invalidate (Item);
      end if;
   end Scroll_To;

   overriding procedure Update
     (Item : in out Picture; Now : SDL3.Events.Milliseconds)
   is
      pragma Unreferenced (Now);
   begin
      --  It is read; draw it.
      if Item.Job /= 0 and then Jobs.State (Item.Job) /= Jobs.Working then
         Invalidate (Item);
      end if;
   end Update;

   overriding function Until_Update (Item : Picture) return Integer is
     (if Item.Job /= 0 and then Jobs.State (Item.Job) = Jobs.Working
      then Poll else -1);

   overriding procedure Draw
     (Item   : in out Picture;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Box  : constant Float := Width_Of (Item);
      Wide : constant Float := Box * Item.Zoomed;
   begin
      SDL3.Windows.Renderers.Fill_Rect
        (Target, Themes.White,
         Left_Of (Item), Top_Of (Item), Box, Height_Of (Item));
      if Item.Length = 0 or else Item.Failed then
         return;
      end if;
      if not Item.Loaded then
         Load_Soon (Item, Urgent => True);
         if Item.Job /= 0 and then Jobs.State (Item.Job) = Jobs.Failed then
            Stop_Loading (Item);
            Item.Failed := True;
            return;
         elsif Item.Job /= 0 and then Jobs.State (Item.Job) = Jobs.Done then
            begin
               Jobs.Finish (Item.Job, Item.Pixels, Target, Item.Dark);
               Item.Job := 0;
               Item.Loaded := True;
            exception
               when others =>
                  Item.Job := 0;
                  Item.Failed := True;
                  return;
            end;
         end if;
      end if;
      --  As tall as it will be, before it is there.
      if Item.Loaded then
         Item.Fitted :=
           Wide * Float (Textures.Height (Item.Pixels))
             / Float (Textures.Width (Item.Pixels));
      elsif Item.Wide > 0 then
         Item.Fitted := Wide * Float (Item.High) / Float (Item.Wide);
      end if;
      Item.Down :=
        Float'Min (Item.Down, Furthest (Item, Height_Of (Item)));
      Item.Across := Float'Min (Item.Across, 1.0);
      if Item.Loaded then
         Textures.Draw_Scaled
           (Target, Item.Pixels,
            Left_Of (Item) - Item.Across * Float'Max (0.0, Wide - Box),
            Top_Of (Item) - Item.Down * Item.Fitted,
            Wide, Item.Fitted);
      end if;
      declare
         Left : constant Float := Origin_X (Item);
         Top  : constant Float := Origin_Y (Item);
         High : constant Float := Mark_Height * Wide;
      begin
         for Index in 1 .. Item.Marks + (if Item.Marking then 1 else 0) loop
            declare
               Each : Mark renames Item.Marked (Index);
            begin
               SDL3.Windows.Renderers.Fill_Rect
                 (Target, Colors.Marker,
                  (if Item.Dark then SDL3.Windows.Renderers.Add
                   else SDL3.Windows.Renderers.Multiply),
                  Left + Each.Left * Wide,
                  Top + Each.Y * Item.Fitted - High / 2.0,
                  (Each.Right - Each.Left) * Wide, High);
            end;
         end loop;
      end;
      if Has_Selection (Item) then
         declare
            Tint : SDL3.Windows.Renderers.Color :=
              (if Has_Focus (Item) then Themes.Selection (Colors)
               else Themes.Inactive_Selection (Colors));
            Left : constant Float := Origin_X (Item);
            Top  : constant Float := Origin_Y (Item);
         begin
            Tint.Alpha := 110;
            for Index in First_Selected (Item) .. Last_Selected (Item) loop
               declare
                  Each : Vision.Word renames Item.Found.Words (Index);
               begin
                  SDL3.Windows.Renderers.Fill_Rect
                    (Target, Tint,
                     Left + Each.Left * Wide, Top + Each.Top * Item.Fitted,
                     Each.Width * Wide, Each.Height * Item.Fitted);
               end;
            end loop;
         end;
      end if;
      Scrollbars.Draw (Item.Down_Bar, Target, Colors, Down_Metrics (Item));
      Scrollbars.Draw
        (Item.Across_Bar, Target, Colors, Across_Metrics (Item));
   end Draw;

   overriding procedure Hover_Changed
     (Item : in out Picture; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Down_Bar, Hovered);
      Scrollbars.Set_Pane (Item.Across_Bar, Hovered);
      Invalidate (Item);
   end Hover_Changed;

   procedure Handle_Bars
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Moved, Changed, Other_Changed : Boolean;
      Other_Taken, Other_Moved : Boolean;
      To, Other_To : Float;
   begin
      Scrollbars.Handle
        (Item.Down_Bar, Event, Down_Metrics (Item), Handled, Moved, To,
         Changed);
      if Moved then
         Scroll_To
           (Item, Float'Min (1.0, Float'Max (0.0, To / Item.Fitted)));
      end if;
      Scrollbars.Handle
        (Item.Across_Bar, Event, Across_Metrics (Item), Other_Taken,
         Other_Moved, Other_To, Other_Changed);
      if Other_Moved then
         Item.Across :=
           Float'Min
             (1.0,
              Float'Max
                (0.0, Other_To / (Wide_Of (Item) - Width_Of (Item))));
      end if;
      Handled := Handled or else Other_Taken;
      if Changed or else Moved or else Other_Changed or else Other_Moved then
         Invalidate (Item);
      end if;
   end Handle_Bars;

   overriding procedure Handle
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Item.Fitted > 0.0
        and then Event.Kind in SDL3.Events.Mouse_Down
                             | SDL3.Events.Mouse_Move
                             | SDL3.Events.Mouse_Up
      then
         Handle_Bars (Item, Event, Handled);
         if Handled then
            return;
         end if;
      end if;
      if Item.Chosen /= Pointer and then Item.Fitted > 0.0 then
         Handle_Marking (Item, Event, Handled);
         if Handled then
            return;
         end if;
      end if;
      if Has_Words (Item) and then Item.Fitted > 0.0 then
         case Event.Kind is
            when SDL3.Events.Mouse_Down =>
               if Event.Button = 1
                 and then Contains
                            (Item, Event.Mouse_X * Density (Item),
                             Event.Mouse_Y * Density (Item))
               then
                  declare
                     Under : constant Natural :=
                       Word_At
                         (Item, Event.Mouse_X * Density (Item),
                          Event.Mouse_Y * Density (Item), Nearest => False);
                  begin
                     if Under = 0 then
                        Clear_Selection (Item);
                     elsif Event.Clicks >= 3 then
                        Select_Line (Item, Under);
                        Handled := True;
                     elsif Event.Clicks = 2 then
                        Select_Range (Item, Under, Under);
                        Handled := True;
                     else
                        Select_Range (Item, Under, 0);
                        Item.Held := True;
                        Handled := True;
                     end if;
                  end;
               end if;
            when SDL3.Events.Mouse_Move =>
               if Item.Held then
                  declare
                     Under : constant Natural :=
                       Word_At
                         (Item, Event.Mouse_X * Density (Item),
                          Event.Mouse_Y * Density (Item), Nearest => True);
                  begin
                     Select_Range
                       (Item, Item.Anchor,
                        (if Under = Item.Anchor then 0 else Under));
                     Handled := True;
                  end;
               end if;
            when SDL3.Events.Mouse_Up =>
               if Item.Held and then Event.Button = 1 then
                  Item.Held := False;
                  Handled := True;
               end if;
            when SDL3.Events.Key_Down =>
               if Event.Command and then Event.Key = SDL3.Events.Key_C
                 and then Has_Selection (Item)
                 and then Clipboard (Item) /= null
               then
                  Clipboard (Item).Set_Text (Selected_Text (Item));
                  Handled := True;
               elsif Event.Command and then Event.Key = SDL3.Events.Key_A
               then
                  Select_All (Item);
                  Handled := True;
               end if;
            when others =>
               null;
         end case;
         if Handled then
            return;
         end if;
      end if;
      if Event.Kind = SDL3.Events.Mouse_Wheel and then Item.Fitted > 0.0 then
         if Item.Zoomed > 1.0 and then Event.Wheel_X /= 0.0 then
            Item.Across :=
              Float'Min
                (1.0,
                 Float'Max
                   (0.0,
                    Item.Across
                    - Event.Wheel_X * Points_Per_Notch * Density (Item)
                      / (Width_Of (Item) * (Item.Zoomed - 1.0))));
            Invalidate (Item);
         end if;
         Scroll_To
           (Item,
            Float'Min
              (1.0,
               Float'Max
                 (0.0,
                  Item.Down
                  - Event.Wheel_Y * Points_Per_Notch * Density (Item)
                    / Item.Fitted)));
         Handled := True;
      end if;
   end Handle;

end UI.Widgets.Pictures;
