with Ada.Numerics.Elementary_Functions;

package body UI.Widgets.Canvases is

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use SDL3.Windows.Renderers;

   Points_Per_Notch : constant Float := 24.0;
   --  How far a notch of the wheel pans.
   Zoom_Per_Notch   : constant Float := 1.1;
   Grid             : constant Float := 16.0;
   --  Between dots, in canvas units, at least; more as it zooms out.
   Closest          : constant Float := 12.0;
   --  The nearest the dots are drawn, in points.
   Dot              : constant Float := 1.5;
   --  A dot's side, in points.
   Middle_Button    : constant := 2;

   function Zoom (Item : Canvas) return Float is (Item.Scale);

   function Snapped (Item : Canvas; Points : Float) return Float is
     (if Is_Attached (Item)
      then Float'Rounding (Points * Density (Item)) / Density (Item)
      else Points);
   --  On a whole pixel, so that all that is on the canvas moves by the
   --  same whole pixels while it is panned, and does not jiggle.

   function Origin_X (Item : Canvas) return Float is
     (Snapped (Item, Item.Across));

   function Origin_Y (Item : Canvas) return Float is
     (Snapped (Item, Item.Down));

   function Is_Panning (Item : Canvas) return Boolean is (Item.Panning);

   function To_Canvas_X (Item : Canvas; Point : Float) return Float is
     ((Point - Item.Across) / Item.Scale);

   function To_Canvas_Y (Item : Canvas; Point : Float) return Float is
     ((Point - Item.Down) / Item.Scale);

   function To_Screen_X (Item : Canvas; Unit : Float) return Float is
     (To_Screen (Unit, Item.Scale, Item.Across));

   function To_Screen_Y (Item : Canvas; Unit : Float) return Float is
     (To_Screen (Unit, Item.Scale, Item.Down));

   procedure Pan_By (Item : in out Canvas; Across, Down : Float) is
   begin
      if Across /= 0.0 or else Down /= 0.0 then
         Item.Across := Item.Across + Across;
         Item.Down := Item.Down + Down;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Pan_By;

   procedure Zoom_By
     (Item : in out Canvas; Factor : Float; About_X, About_Y : Float)
   is
      Scale : constant Float :=
        Float'Min (Max_Zoom, Float'Max (Min_Zoom, Item.Scale * Factor));
      Ratio : constant Float := Scale / Item.Scale;
   begin
      if Scale /= Item.Scale then
         Item.Across := About_X - (About_X - Item.Across) * Ratio;
         Item.Down := About_Y - (About_Y - Item.Down) * Ratio;
         Item.Scale := Scale;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Zoom_By;

   Link_Width   : constant Float := 1.5;
   --  A line's width, in points.
   End_Size     : constant Float := 5.0;
   --  The side of the square at each end of a line, in points.
   Ghost_Alpha  : constant := 90;
   Halo_Width   : constant Float := 8.0;
   Halo_Alpha   : constant := 110;
   Reach        : constant Float := 6.0;
   --  How far from a line, in points, a press selects it.
   Dash_Length  : constant Float := 5.0;
   Gap_Length   : constant Float := 4.0;
   Dot_Gap      : constant Float := 5.0;
   Head_Length  : constant Float := 12.0;
   Head_Angle   : constant Float := 0.5;
   --  The arrowhead's arms, in points and radians.

   function Same (A, B : Line) return Boolean is (A = B);

   function Screen_X (Item : Canvas; X : Float) return Float is
     (Left_Of (Item) + (Origin_X (Item) + X * Item.Scale) * Density (Item));

   function Screen_Y (Item : Canvas; Y : Float) return Float is
     (Top_Of (Item) + (Origin_Y (Item) + Y * Item.Scale) * Density (Item));
   --  A place on the canvas, in pixels from the top left of the target.

   procedure Damage_Between
     (Item : in out Canvas; X0, Y0, X1, Y1 : Float);
   --  Draw again the box in pixels round the line from X0, Y0 to X1, Y1.

   procedure Damage_Between
     (Item : in out Canvas; X0, Y0, X1, Y1 : Float)
   is
      Room : constant Float := Link_Width * Density (Item) + 2.0;
      Left : constant Float := Float'Min (X0, X1) - Room;
      Top  : constant Float := Float'Min (Y0, Y1) - Room;
   begin
      Invalidate
        (Item,
         (Left   => Integer (Float'Floor (Left)),
          Top    => Integer (Float'Floor (Top)),
          Width  => Integer (Float'Ceiling
                               (Float'Max (X0, X1) + Room - Left)),
          Height => Integer (Float'Ceiling
                               (Float'Max (Y0, Y1) + Room - Top))));
   end Damage_Between;

   procedure Set_Lines (Item : in out Canvas; Lines : Line_Array) is
   begin
      for Number in Lines'Range loop
         declare
            Was : constant Boolean :=
              Number - Lines'First + 1 <= Item.Line_Count;
            Old : constant Line :=
              (if Was then Item.Lines (Number - Lines'First + 1)
               else Lines (Number));
         begin
            if not Was or else not Same (Old, Lines (Number)) then
               if Was and then Is_Attached (Item) then
                  Damage_Between
                    (Item, Screen_X (Item, Old.From_X),
                     Screen_Y (Item, Old.From_Y),
                     Screen_X (Item, Old.To_X), Screen_Y (Item, Old.To_Y));
               end if;
               if Is_Attached (Item) then
                  Damage_Between
                    (Item, Screen_X (Item, Lines (Number).From_X),
                     Screen_Y (Item, Lines (Number).From_Y),
                     Screen_X (Item, Lines (Number).To_X),
                     Screen_Y (Item, Lines (Number).To_Y));
               end if;
            end if;
         end;
      end loop;
      --  Those that are gone.
      for Number in Lines'Length + 1 .. Item.Line_Count loop
         if Is_Attached (Item) then
            Damage_Between
              (Item, Screen_X (Item, Item.Lines (Number).From_X),
               Screen_Y (Item, Item.Lines (Number).From_Y),
               Screen_X (Item, Item.Lines (Number).To_X),
               Screen_Y (Item, Item.Lines (Number).To_Y));
         end if;
      end loop;
      Item.Line_Count := Lines'Length;
      Item.Lines (1 .. Lines'Length) := Lines;
   end Set_Lines;

   function Ghost_End (Item : Canvas) return Line is
     (From_X => Screen_X (Item, Item.Ghost_From.From_X),
      From_Y => Screen_Y (Item, Item.Ghost_From.From_Y),
      To_X   => Item.Ghost_From.To_X * Density (Item),
      To_Y   => Item.Ghost_From.To_Y * Density (Item),
      others => <>);
   --  The ghost, in pixels from the top left of the target.

   procedure Set_Ghost
     (Item : in out Canvas; From_X, From_Y : Float; To_X, To_Y : Float)
   is
      Now : constant Line :=
        (From_X => From_X, From_Y => From_Y, To_X => To_X, To_Y => To_Y,
         others => <>);
   begin
      if not Item.Ghosted or else not Same (Item.Ghost_From, Now) then
         if Item.Ghosted then
            declare
               Was : constant Line := Ghost_End (Item);
            begin
               Damage_Between
                 (Item, Was.From_X, Was.From_Y, Was.To_X, Was.To_Y);
            end;
         end if;
         Item.Ghosted := True;
         Item.Ghost_From := Now;
         declare
            Here : constant Line := Ghost_End (Item);
         begin
            Damage_Between
              (Item, Here.From_X, Here.From_Y, Here.To_X, Here.To_Y);
         end;
      end if;
   end Set_Ghost;

   procedure Clear_Ghost (Item : in out Canvas) is
   begin
      if Item.Ghosted then
         declare
            Was : constant Line := Ghost_End (Item);
         begin
            Item.Ghosted := False;
            Damage_Between (Item, Was.From_X, Was.From_Y, Was.To_X, Was.To_Y);
         end;
      end if;
   end Clear_Ghost;

   function Selected (Item : Canvas) return Natural is (Item.Chosen);

   procedure Set_Selected (Item : in out Canvas; Tag : Natural) is
   begin
      if Tag /= Item.Chosen then
         Item.Chosen := Tag;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Selected;

   procedure Take_Selection
     (Item : in out Canvas; Changed : out Boolean; Tag : out Natural) is
   begin
      Changed := Item.Chosen_Changed;
      Tag := Item.Chosen;
      Item.Chosen_Changed := False;
   end Take_Selection;

   procedure Take_Delete (Item : in out Canvas; Asked : out Boolean) is
   begin
      Asked := Item.Delete_Asked;
      Item.Delete_Asked := False;
   end Take_Delete;

   function Line_At (Item : Canvas; X, Y : Float) return Natural;
   --  The Tag of the line within reach of the pixel X, Y, the nearest, if
   --  any; 0 if none.

   function Line_At (Item : Canvas; X, Y : Float) return Natural is
      Pixels : constant Float := Density (Item);
      Best   : Float := Reach * Pixels;
      Found  : Natural := 0;
   begin
      for Each of Item.Lines (1 .. Item.Line_Count) loop
         declare
            X0 : constant Float := Screen_X (Item, Each.From_X);
            Y0 : constant Float := Screen_Y (Item, Each.From_Y);
            Dx : constant Float := Screen_X (Item, Each.To_X) - X0;
            Dy : constant Float := Screen_Y (Item, Each.To_Y) - Y0;
            Square : constant Float := Dx * Dx + Dy * Dy;
            --  How far along, from 0.0 to 1.0, the nearest point is.
            Along : constant Float :=
              (if Square > 0.0
               then Float'Max (0.0, Float'Min
                      (1.0, ((X - X0) * Dx + (Y - Y0) * Dy) / Square))
               else 0.0);
            Gap : constant Float :=
              Ada.Numerics.Elementary_Functions.Sqrt
                ((X - X0 - Along * Dx) ** 2 + (Y - Y0 - Along * Dy) ** 2);
         begin
            if Each.Tag /= 0 and then Gap <= Best then
               Best := Gap;
               Found := Each.Tag;
            end if;
         end;
      end loop;
      return Found;
   end Line_At;

   function Has_Ghost (Item : Canvas) return Boolean is (Item.Ghosted);

   overriding procedure Placed
     (Item : in out Canvas; Left, Top, Width, Height : Float)
   is
      pragma Unreferenced (Left, Top);
   begin
      --  Hidden, it has no room: wait to be seen.
      if not Item.Centered and then Width > 0.0 and then Height > 0.0 then
         Item.Centered := True;
         Item.Across := Width / Density (Item) / 2.0;
         Item.Down := Height / Density (Item) / 2.0;
      end if;
   end Placed;

   procedure Stroke
     (Target : SDL3.Windows.Renderers.Renderer;
      Style  : Line;
      Colors : Themes.Theme;
      From_X, From_Y, To_X, To_Y : Float;
      Pixels : Float)
   is
      Ink : constant Themes.Color := Themes.Resolve (Colors, Style.Ink);
      Wide   : constant Float := Link_Width * Pixels;
      Dx     : constant Float := To_X - From_X;
      Dy     : constant Float := To_Y - From_Y;
      Length : constant Float :=
        Ada.Numerics.Elementary_Functions.Sqrt (Dx * Dx + Dy * Dy);
      Along_X : constant Float := (if Length > 0.0 then Dx / Length else 1.0);
      Along_Y : constant Float := (if Length > 0.0 then Dy / Length else 0.0);

      procedure Part (From, To : Float) is
      begin
         Draw_Line
           (Target, Ink,
            From_X + Along_X * From, From_Y + Along_Y * From,
            From_X + Along_X * To, From_Y + Along_Y * To, Wide);
      end Part;

      Place : Float := 0.0;
   begin
      if Length < 0.5 then
         return;
      end if;
      case Style.Dash is
         when Solid =>
            Part (0.0, Length);
         when Dashed =>
            while Place < Length loop
               Part (Place, Float'Min (Length, Place + Dash_Length * Pixels));
               Place := Place + (Dash_Length + Gap_Length) * Pixels;
            end loop;
         when Dotted =>
            while Place <= Length loop
               Fill_Circle
                 (Target, Ink,
                  From_X + Along_X * Place, From_Y + Along_Y * Place,
                  Wide * 0.75);
               Place := Place + Dot_Gap * Pixels;
            end loop;
      end case;
      --  A small square where it joins at each end; an arrowhead, if it
      --  has one, in place of the square at the To end.
      declare
         Side : constant Float := Float'Rounding (End_Size * Pixels);
      begin
         Fill_Rect (Target, Ink, Float'Rounding (From_X - Side / 2.0),
                    Float'Rounding (From_Y - Side / 2.0), Side, Side);
         if not Style.Arrow then
            Fill_Rect (Target, Ink, Float'Rounding (To_X - Side / 2.0),
                       Float'Rounding (To_Y - Side / 2.0), Side, Side);
         end if;
      end;
      if Style.Arrow then
         for Arm in 0 .. 1 loop
            declare
               Turn : constant Float := Float (2 * Arm - 1);
               Cos : constant Float :=
                 Ada.Numerics.Elementary_Functions.Cos (Head_Angle);
               Sin : constant Float :=
                 Turn * Ada.Numerics.Elementary_Functions.Sin (Head_Angle);
               --  Back along the line, turned a little to either side.
               Back_X : constant Float := -(Along_X * Cos - Along_Y * Sin);
               Back_Y : constant Float := -(Along_Y * Cos + Along_X * Sin);
            begin
               Draw_Line
                 (Target, Ink, To_X, To_Y,
                  To_X + Back_X * Head_Length * Pixels,
                  To_Y + Back_Y * Head_Length * Pixels, Wide);
            end;
         end loop;
      end if;
   end Stroke;

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels  : constant Float := Density (Item);
      Part    : constant Pixel_Box := Painting_Part (Item);
      Surface : constant Themes.Color := Colors.Background;
      Ink     : constant Themes.Color := Colors.Border;
      Side    : constant Float :=
        Float'Max (1.0, Float'Rounding (Dot * Pixels));
      Step    : Float := Grid;
   begin
      Fill_Rect
        (Target, Surface, Float (Part.Left), Float (Part.Top),
         Float (Part.Width), Float (Part.Height));

      --  Dots at every Step, doubled until they are not crowded.
      while Step * Item.Scale < Closest loop
         Step := Step * 2.0;
      end loop;
      declare
         Gap   : constant Float := Step * Item.Scale * Pixels;
         --  Pixels between dots.
         Zero_X : constant Float := Left_Of (Item) + Origin_X (Item) * Pixels;
         Zero_Y : constant Float := Top_Of (Item) + Origin_Y (Item) * Pixels;
         First_Column : constant Integer :=
           Integer (Float'Ceiling ((Float (Part.Left) - Zero_X) / Gap));
         Last_Column  : constant Integer :=
           Integer (Float'Floor
                      ((Float (Part.Left + Part.Width) - Zero_X) / Gap));
         First_Row    : constant Integer :=
           Integer (Float'Ceiling ((Float (Part.Top) - Zero_Y) / Gap));
         Last_Row     : constant Integer :=
           Integer (Float'Floor
                      ((Float (Part.Top + Part.Height) - Zero_Y) / Gap));
      begin
         for Row in First_Row .. Last_Row loop
            for Column in First_Column .. Last_Column loop
               Fill_Rect
                 (Target, Ink,
                  Float'Rounding (Zero_X + Float (Column) * Gap - Side / 2.0),
                  Float'Rounding (Zero_Y + Float (Row) * Gap - Side / 2.0),
                  Side, Side);
            end loop;
         end loop;
      end;

      --  Lines joining what is on it, under that.
      for Each of Item.Lines (1 .. Item.Line_Count) loop
         declare
            From_X : constant Float := Screen_X (Item, Each.From_X);
            From_Y : constant Float := Screen_Y (Item, Each.From_Y);
            To_X   : constant Float := Screen_X (Item, Each.To_X);
            To_Y   : constant Float := Screen_Y (Item, Each.To_Y);
         begin
            if Each.Tag /= 0 and then Each.Tag = Item.Chosen then
               Draw_Line
                 (Target,
                  (Colors.Accent.Red, Colors.Accent.Green,
                   Colors.Accent.Blue, Halo_Alpha),
                  From_X, From_Y, To_X, To_Y, Halo_Width * Pixels);
            end if;
            Stroke (Target, Each, Colors, From_X, From_Y, To_X, To_Y, Pixels);
         end;
      end loop;
   end Draw;

   overriding procedure Draw_Over
     (Item   : in out Canvas;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme) is
   begin
      if Item.Ghosted then
         declare
            Here : constant Line := Ghost_End (Item);
         begin
            Draw_Line
              (Target,
               (Colors.Foreground.Red, Colors.Foreground.Green,
                Colors.Foreground.Blue, Ghost_Alpha),
               Here.From_X, Here.From_Y, Here.To_X, Here.To_Y,
               Float'Max (1.0, Link_Width * Density (Item)));
         end;
      end if;
   end Draw_Over;

   overriding procedure Handle
     (Item    : in out Canvas;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Pixels : constant Float := Density (Item);
      --  The pointer, in points from the box's top left.
      X : constant Float := Event.Mouse_X - Left_Of (Item) / Pixels;
      Y : constant Float := Event.Mouse_Y - Top_Of (Item) / Pixels;
      Wide : constant Float := Width_Of (Item) / Pixels;
      High : constant Float := Height_Of (Item) / Pixels;
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Wheel =>
            if Event.Command then
               Zoom_By
                 (Item,
                  Ada.Numerics.Elementary_Functions."**"
                    (Zoom_Per_Notch, Event.Wheel_Y), X, Y);
            else
               Pan_By
                 (Item, -Event.Wheel_X * Points_Per_Notch,
                  Event.Wheel_Y * Points_Per_Notch);
            end if;
            Handled := True;

         when SDL3.Events.Pinch =>
            Zoom_By (Item, Event.Scale, X, Y);
            Handled := True;

         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1
              and then Item.Owner /= null
              and then Hit (Item.Owner.all, Event.Mouse_X * Pixels,
                            Event.Mouse_Y * Pixels)
                       = Widget'Class (Item)'Unrestricted_Access
            then
               --  On the canvas itself, not on what is over it.
               declare
                  Tag : constant Natural :=
                    Line_At (Item, Event.Mouse_X * Pixels,
                             Event.Mouse_Y * Pixels);
               begin
                  if Tag /= Item.Chosen then
                     Set_Selected (Item, Tag);
                     Item.Chosen_Changed := True;
                  end if;
                  Handled := Tag /= 0;
               end;
            elsif Event.Button = Middle_Button
              and then Contains
                         (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
            then
               Item.Panning := True;
               Item.Last_X := Event.Mouse_X;
               Item.Last_Y := Event.Mouse_Y;
               Handled := True;
               Invalidate (Item);
            end if;

         when SDL3.Events.Mouse_Move =>
            if Item.Panning then
               Pan_By
                 (Item, Event.Mouse_X - Item.Last_X,
                  Event.Mouse_Y - Item.Last_Y);
               Item.Last_X := Event.Mouse_X;
               Item.Last_Y := Event.Mouse_Y;
               Handled := True;
            end if;

         when SDL3.Events.Mouse_Up =>
            if Item.Panning and then Event.Button = Middle_Button then
               Item.Panning := False;
               Handled := True;
            end if;

         when SDL3.Events.Key_Down =>
            if not Event.Command and then Item.Chosen /= 0
              and then (Event.Key = SDL3.Events.Key_Backspace
                        or else Event.Key = SDL3.Events.Key_Delete)
            then
               Item.Delete_Asked := True;
               Handled := True;
            elsif not Event.Command and then Item.Chosen /= 0
              and then Event.Key = SDL3.Events.Key_Escape
            then
               Set_Selected (Item, 0);
               Item.Chosen_Changed := True;
               Handled := True;
            elsif Event.Command then
               Handled := True;
               if Event.Key = SDL3.Events.Key_Equals then
                  Zoom_By (Item, Zoom_Per_Notch, Wide / 2.0, High / 2.0);
               elsif Event.Key = SDL3.Events.Key_Minus then
                  Zoom_By (Item, 1.0 / Zoom_Per_Notch, Wide / 2.0, High / 2.0);
               elsif Event.Key = SDL3.Events.Key_0 then
                  Zoom_By (Item, 1.0 / Item.Scale, Wide / 2.0, High / 2.0);
               else
                  Handled := False;
               end if;
            end if;

         when others =>
            null;
      end case;
   end Handle;

   overriding function Cursor (Item : Canvas) return SDL3.Cursors.Kind is
     (if Item.Panning then SDL3.Cursors.Move else SDL3.Cursors.Default);

end UI.Widgets.Canvases;
