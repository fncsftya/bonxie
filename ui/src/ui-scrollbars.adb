with UI.Boxes;

package body UI.Scrollbars is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   type Parts is record
      Present : Boolean := False;
      Button  : Float := 0.0;  --  the length of each button at the ends
      Offset  : Float := 0.0;  --  of the thumb from the box's start
      Length  : Float := 0.0;  --  of the thumb
      Free    : Float := 0.0;  --  how far it can go
   end record;

   function Along (Within : Metrics) return Float is
     (if Within.Horizontal then Within.Width else Within.Height);

   function Across (Within : Metrics) return Float is
     (if Within.Horizontal then Within.Height else Within.Width);

   function Thick (Within : Metrics) return Float is
     (Float'Min (Across (Within),
                 Float'Rounding (Thickness * Within.Density)));

   function Parts_Of (Within : Metrics) return Parts is
      Button : constant Float := Thick (Within);
      Track  : constant Float := Along (Within) - 2.0 * Button;
      Least  : constant Float := Shortest * Within.Density;
   begin
      if Within.Total <= Within.Shown or else Within.Total <= 0.0
        or else Track < Least
      then
         return (others => <>);
      end if;
      declare
         Length : constant Float :=
           Float'Rounding
             (Float'Max (Least, Track * Within.Shown / Within.Total));
         Free   : constant Float := Track - Length;
         Moved  : constant Float :=
           Float'Min
             (1.0,
              Float'Max (0.0, Within.Start / (Within.Total - Within.Shown)));
      begin
         return (Present => True, Button => Button,
                 Offset => Button + Float'Rounding (Free * Moved),
                 Length => Length, Free => Free);
      end;
   end Parts_Of;

   procedure Set_Pane (Item : in out Bar; Over : Boolean) is
   begin
      Item.Pane := Over;
   end Set_Pane;

   function Is_Shown (Item : Bar) return Boolean is
     (Item.Pane or else Item.Grabbing or else Item.Pressing /= None);

   function Is_Held (Item : Bar) return Boolean is
     (Item.Grabbing or else Item.Pressing /= None);

   procedure Draw
     (Item   : Bar;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme;
      Within : Metrics)
   is
      Place : constant Parts := Parts_Of (Within);
      Wide  : constant Float := Thick (Within);
      Edge  : constant Float := UI.Boxes.Edge (Within.Density);
      Left  : constant Float :=
        (if Within.Horizontal then Within.Left
         else Within.Left + Within.Width - Wide);
      Top   : constant Float :=
        (if Within.Horizontal then Within.Top + Within.Height - Wide
         else Within.Top);

      procedure Box (From, Length : Float; X, Y, W, H : out Float);
      --  The part From along the bar, Length long, across all of it.

      procedure Box (From, Length : Float; X, Y, W, H : out Float) is
      begin
         if Within.Horizontal then
            X := Left + From;
            Y := Top;
            W := Length;
            H := Wide;
         else
            X := Left;
            Y := Top + From;
            W := Wide;
            H := Length;
         end if;
      end Box;

      procedure Raised (From, Length : Float; Pressed : Boolean) is
         X, Y, W, H : Float;
      begin
         Box (From, Length, X, Y, W, H);
         Fill_Rect (Target, Colors.Face, X, Y, W, H);
         UI.Boxes.Outline (Target, Colors.Border, X, Y, W, H, Edge);
         UI.Boxes.Bevel
           (Target, Themes.Highlight (Colors.Face), Themes.Shade (Colors.Face),
            X + Edge, Y + Edge, W - 2.0 * Edge, H - 2.0 * Edge,
            Within.Density, Sunken => Pressed);
      end Raised;

      procedure Arrow_On (From : Float; Which : Arrow) is
         --  A triangle of rows of pixels, pointing the way it scrolls.
         Rows  : constant Natural :=
           Natural (Float'Rounding (2.5 * Within.Density));
         Shift : constant Float :=
           (if Item.Pressing = Which then UI.Boxes.Shift (Within.Density)
            else 0.0);
         X, Y, W, H : Float;
      begin
         Raised (From, Place.Button, Item.Pressing = Which);
         Box (From, Place.Button, X, Y, W, H);
         for Row in 0 .. Rows - 1 loop
            declare
               Span : constant Float := Float (2 * Row + 1);
               Step : constant Float :=
                 (if Which = Back then Float (Row)
                  else Float (Rows - 1 - Row));
               --  From the point of the arrow, at the end it points to.
            begin
               if Within.Horizontal then
                  Fill_Rect
                    (Target, Colors.Foreground,
                     Float'Rounding (X + (W - Float (Rows)) / 2.0) + Step
                     + Shift,
                     Float'Rounding (Y + (H - Span) / 2.0) + Shift,
                     1.0, Span);
               else
                  Fill_Rect
                    (Target, Colors.Foreground,
                     Float'Rounding (X + (W - Span) / 2.0) + Shift,
                     Float'Rounding (Y + (H - Float (Rows)) / 2.0) + Step
                     + Shift,
                     Span, 1.0);
               end if;
            end;
         end loop;
      end Arrow_On;

      X, Y, W, H : Float;
   begin
      if not Is_Shown (Item) or else not Place.Present then
         return;
      end if;
      --  The trough, a line along its inner side.
      Box (0.0, Along (Within), X, Y, W, H);
      Fill_Rect (Target, Colors.Tint, X, Y, W, H);
      if Within.Horizontal then
         Fill_Rect (Target, Colors.Border, X, Y, W, Edge);
      else
         Fill_Rect (Target, Colors.Border, X, Y, Edge, H);
      end if;
      Arrow_On (0.0, Back);
      Arrow_On (Along (Within) - Place.Button, Ahead);
      Raised (Place.Offset, Place.Length, Pressed => False);
   end Draw;

   procedure Handle
     (Item    : in out Bar;
      Event   : SDL3.Events.Event;
      Within  : Metrics;
      Taken   : out Boolean;
      Moved   : out Boolean;
      To      : out Float;
      Changed : out Boolean)
   is
      Place : constant Parts := Parts_Of (Within);
      X     : constant Float := Event.Mouse_X * Within.Density;
      Y     : constant Float := Event.Mouse_Y * Within.Density;
      Point : constant Float := (if Within.Horizontal then X else Y);
      Cross : constant Float := (if Within.Horizontal then Y else X);
      First : constant Float :=
        (if Within.Horizontal then Within.Left else Within.Top);
      Far   : constant Float :=
        (if Within.Horizontal then Within.Top + Within.Height
         else Within.Left + Within.Width);
      Is_Over : constant Boolean :=
        Place.Present
        and then Cross in Far - Thick (Within) .. Far
        and then Point in First .. First + Along (Within);
      Before : constant Bar := Item;
      Most   : constant Float := Within.Total - Within.Shown;

      function Start_For return Float is
        (if Place.Free <= 0.0 then 0.0
         else Float'Min
                (1.0,
                 Float'Max
                   (0.0,
                    (Point - First - Place.Button - Item.Grab)
                    / Place.Free))
              * Most);

      function Stepped (By : Float) return Float is
        (Float'Min (Most, Float'Max (0.0, Within.Start + By)));
   begin
      Taken := False;
      Moved := False;
      To := 0.0;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Is_Over then
               Item.Pane := True;
               Taken := True;
               if Point < First + Place.Button then
                  Item.Pressing := Back;
                  Moved := True;
                  To := Stepped (-Step_Fraction * Within.Shown);
               elsif Point >= First + Along (Within) - Place.Button then
                  Item.Pressing := Ahead;
                  Moved := True;
                  To := Stepped (Step_Fraction * Within.Shown);
               else
                  declare
                     On_Thumb : constant Boolean :=
                       Point in First + Place.Offset
                                .. First + Place.Offset + Place.Length;
                  begin
                     Item.Grabbing := True;
                     Item.Grab :=
                       (if On_Thumb then Point - First - Place.Offset
                        else Place.Length / 2.0);
                     if not On_Thumb then
                        Moved := True;
                        To := Start_For;
                     end if;
                  end;
               end if;
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Grabbing then
               if Event.Left_Held then
                  Taken := True;
                  Moved := True;
                  To := Start_For;
               else
                  Item.Grabbing := False;  --  let go where it was not seen
               end if;
            elsif Item.Pressing /= None then
               if Event.Left_Held then
                  Taken := True;
               else
                  Item.Pressing := None;
               end if;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Is_Held (Item) then
               Item.Grabbing := False;
               Item.Pressing := None;
               Taken := True;
            end if;
         when others =>
            null;
      end case;
      Changed := Item /= Before;
   end Handle;

end UI.Scrollbars;
