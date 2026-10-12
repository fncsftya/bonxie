with Ada.Numerics.Elementary_Functions;

package body UI.Widgets.Canvases is

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use SDL3.Windows.Renderers;

   Points_Per_Notch : constant Float := 24.0;
   --  How far a notch of the wheel pans.
   Zoom_Per_Notch   : constant Float := 1.1;
   Grid             : constant Float := 32.0;
   --  Between dots, in canvas units, at least; more as it zooms out.
   Closest          : constant Float := 14.0;
   --  The nearest the dots are drawn, in points.
   Dot              : constant Float := 1.5;
   --  A dot's side, in points.
   Middle_Button    : constant := 2;

   function Zoom (Item : Canvas) return Float is (Item.Scale);

   function Origin_X (Item : Canvas) return Float is (Item.Across);

   function Origin_Y (Item : Canvas) return Float is (Item.Down);

   function Is_Panning (Item : Canvas) return Boolean is (Item.Panning);

   function To_Canvas_X (Item : Canvas; Point : Float) return Float is
     ((Point - Item.Across) / Item.Scale);

   function To_Canvas_Y (Item : Canvas; Point : Float) return Float is
     ((Point - Item.Down) / Item.Scale);

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

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels  : constant Float := Density (Item);
      Part    : constant Pixel_Box := Painting_Part (Item);
      Surface : constant Themes.Color :=
        Themes.Mix (Colors.Background, (255, 255, 255, 255), 0.4);
      Ink     : constant Themes.Color :=
        Themes.Mix (Surface, Colors.Foreground, 0.3);
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
         Zero_X : constant Float := Left_Of (Item) + Item.Across * Pixels;
         Zero_Y : constant Float := Top_Of (Item) + Item.Down * Pixels;
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
   end Draw;

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
            if Event.Button = Middle_Button
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
            if Event.Command then
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
