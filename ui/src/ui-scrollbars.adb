package body UI.Scrollbars is

   use type SDL3.Events.Event_Kind;

   type Parts is record
      Present : Boolean := False;
      Offset  : Float := 0.0;  --  of the thumb from the box's start
      Length  : Float := 0.0;  --  of the thumb
      Free    : Float := 0.0;  --  how far it can go
   end record;

   function Along (Within : Metrics) return Float is
     (if Within.Horizontal then Within.Width else Within.Height);

   function Parts_Of (Within : Metrics) return Parts is
      Edge  : constant Float := Margin * Within.Density;
      Track : constant Float := Along (Within) - 2.0 * Edge;
      Least : constant Float := Shortest * Within.Density;
   begin
      if Within.Total <= Within.Shown or else Within.Total <= 0.0
        or else Track < Least
      then
         return (others => <>);
      end if;
      declare
         Length : constant Float :=
           Float'Max (Least, Track * Within.Shown / Within.Total);
         Free   : constant Float := Track - Length;
         Moved  : constant Float :=
           Float'Min
             (1.0,
              Float'Max (0.0, Within.Start / (Within.Total - Within.Shown)));
      begin
         return (Present => True, Offset => Edge + Free * Moved,
                 Length => Length, Free => Free);
      end;
   end Parts_Of;

   procedure Set_Pane (Item : in out Bar; Over : Boolean) is
   begin
      Item.Pane := Over;
      if not Over then
         Item.Near := False;
      end if;
   end Set_Pane;

   function Is_Shown (Item : Bar) return Boolean is
     (Item.Pane or else Item.Grabbing);

   function Is_Held (Item : Bar) return Boolean is (Item.Grabbing);

   procedure Draw
     (Item   : Bar;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme;
      Within : Metrics)
   is
      Place : constant Parts := Parts_Of (Within);
      Thick : constant Float :=
        (if Item.Near or else Item.Grabbing then Near_Thickness
         else Thickness) * Within.Density;
      Edge  : constant Float := Margin * Within.Density;
      Face  : constant SDL3.Windows.Renderers.Color :=
        Themes.Mix
          (Colors.Background, Colors.Foreground,
           (if Item.Near or else Item.Grabbing then 0.6 else 0.45));
   begin
      if not Is_Shown (Item) or else not Place.Present then
         return;
      end if;
      if Within.Horizontal then
         SDL3.Windows.Renderers.Fill_Rect
           (Target, Face,
            Within.Left + Place.Offset,
            Within.Top + Within.Height - Edge - Thick,
            Place.Length, Thick);
      else
         SDL3.Windows.Renderers.Fill_Rect
           (Target, Face,
            Within.Left + Within.Width - Edge - Thick,
            Within.Top + Place.Offset,
            Thick, Place.Length);
      end if;
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
      Zone  : constant Float :=
        (Near_Thickness + 2.0 * Margin) * Within.Density;
      --  Where the pointer is taken to be at the bar.
      Is_Near : constant Boolean :=
        Place.Present
        and then Cross in Far - Zone .. Far
        and then Point in First .. First + Along (Within);
      Before : constant Bar := Item;

      function Start_For return Float is
        (if Place.Free <= 0.0 then 0.0
         else Float'Min
                (1.0,
                 Float'Max
                   (0.0,
                    (Point - First - Margin * Within.Density - Item.Grab)
                    / Place.Free))
              * (Within.Total - Within.Shown));
   begin
      Taken := False;
      Moved := False;
      To := 0.0;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Is_Near then
               declare
                  On_Thumb : constant Boolean :=
                    Point in First + Place.Offset
                             .. First + Place.Offset + Place.Length;
               begin
                  Item.Pane := True;
                  Item.Near := True;
                  Item.Grabbing := True;
                  Item.Grab :=
                    (if On_Thumb then Point - First - Place.Offset
                     else Place.Length / 2.0);
                  Taken := True;
                  if not On_Thumb then
                     Moved := True;
                     To := Start_For;
                  end if;
               end;
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
            else
               Item.Near := Item.Pane and then Is_Near;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Grabbing then
               Item.Grabbing := False;
               Taken := True;
            end if;
         when others =>
            null;
      end case;
      Changed := Item /= Before;
   end Handle;

end UI.Scrollbars;
