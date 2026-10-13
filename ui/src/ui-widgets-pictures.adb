package body UI.Widgets.Pictures is

   package Textures renames SDL3.Windows.Renderers.Textures;

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type Vision.Result_Access;

   function File_Name (Item : Picture) return String is
     (Item.Name (1 .. Item.Length));

   function Has_Picture (Item : Picture) return Boolean is (Item.Loaded);

   function Has_Failed (Item : Picture) return Boolean is (Item.Failed);

   function Scrolled (Item : Picture) return Float is (Item.Down);

   function Zoom (Item : Picture) return Float is (Item.Zoomed);

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
      Item.Length := Path'Length;
      Item.Name (1 .. Item.Length) := Path;
      Item.Loaded := False;
      Item.Failed := False;
      Item.Down := 0.0;
      Item.Across := 0.0;
      Item.Fitted := 0.0;
      Textures.Release (Item.Pixels);
      Item.Held := False;
      Item.Anchor := 0;
      Item.Head := 0;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_File;

   procedure Unload (Item : in out Picture) is
   begin
      Textures.Release (Item.Pixels);
      Item.Loaded := False;
      Item.Failed := False;
   end Unload;

   function Furthest (Item : Picture; High : Float) return Float is
     (if High > 0.0 and then Item.Fitted > High
      then 1.0 - High / Item.Fitted else 0.0);
   --  The most Down can be, for a box High pixels high, so that the
   --  picture's end is at the box's.

   procedure Scroll_To (Item : in out Picture; To : Float) is
      Wanted : constant Float :=
        Float'Min (To, Furthest (Item, Height_Of (Item)));
   begin
      if Wanted /= Item.Down then
         Item.Down := Wanted;
         Invalidate (Item);
      end if;
   end Scroll_To;

   overriding procedure Draw
     (Item   : in out Picture;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Box  : constant Float := Width_Of (Item);
      Wide : constant Float := Box * Item.Zoomed;
   begin
      SDL3.Windows.Renderers.Fill_Rect
        (Target, Themes.Mix (Colors.Background, Colors.Foreground, 0.08),
         Left_Of (Item), Top_Of (Item), Box, Height_Of (Item));
      if Item.Length = 0 or else Item.Failed then
         return;
      end if;
      if not Item.Loaded then
         begin
            Textures.Create_From_PNG (Item.Pixels, Target, File_Name (Item));
            Item.Loaded := True;
         exception
            when others =>
               Item.Failed := True;
               return;
         end;
      end if;
      Item.Fitted :=
        Wide * Float (Textures.Height (Item.Pixels))
          / Float (Textures.Width (Item.Pixels));
      Item.Down :=
        Float'Min (Item.Down, Furthest (Item, Height_Of (Item)));
      Item.Across := Float'Min (Item.Across, 1.0);
      Textures.Draw_Scaled
        (Target, Item.Pixels,
         Left_Of (Item) - Item.Across * Float'Max (0.0, Wide - Box),
         Top_Of (Item) - Item.Down * Item.Fitted,
         Wide, Item.Fitted);
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
   end Draw;

   overriding procedure Handle
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
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
