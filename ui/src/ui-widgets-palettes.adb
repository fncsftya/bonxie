with Yoga.Nodes;

package body UI.Widgets.Palettes is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Dots_Across : constant := 5;
   Dot         : constant Float := 2.0;  --  in points, a side
   Dot_Gap     : constant Float := 4.0;  --  between dots

   function Is_Dragging (Item : Palette) return Boolean is (Item.Dragging);

   overriding procedure Draw
     (Item   : in out Palette;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Float'Max (1.0, Pixels);
      Face   : constant Themes.Color :=
        Themes.Mix (Colors.Background, (255, 255, 255, 255), 0.25);
      Line   : constant Themes.Color :=
        Themes.Mix (Colors.Background, Colors.Foreground, 0.55);
      Ink    : constant Themes.Color :=
        Themes.Mix (Face, Colors.Foreground, 0.4);
      Side   : constant Float :=
        Float'Max (1.0, Float'Rounding (Dot * Pixels));
      Pitch  : constant Float := (Dot + Dot_Gap) * Pixels;
      Row_Width : constant Float := Float (Dots_Across - 1) * Pitch + Side;
   begin
      Fill_Rect
        (Target, Line,
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      Fill_Rect
        (Target, Face,
         Left_Of (Item) + Edge, Top_Of (Item) + Edge,
         Width_Of (Item) - 2.0 * Edge, Height_Of (Item) - 2.0 * Edge);
      --  The grip: a row of dots, in the middle of the top.
      for Dot_Number in 0 .. Dots_Across - 1 loop
         Fill_Rect
           (Target, Ink,
            Float'Rounding
              (Left_Of (Item) + (Width_Of (Item) - Row_Width) / 2.0
               + Float (Dot_Number) * Pitch),
            Float'Rounding
              (Top_Of (Item) + (Grip_Height * Pixels - Side) / 2.0 + Edge),
            Side, Side);
      end loop;
   end Draw;

   overriding procedure Handle
     (Item    : in out Palette;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Density (Item);
      Mouse_X : constant Float := Event.Mouse_X * Pixels;
      Mouse_Y : constant Float := Event.Mouse_Y * Pixels;
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, Mouse_X, Mouse_Y)
            then
               Item.Dragging := True;
               Item.Grab_X := Mouse_X - Left_Of (Item);
               Item.Grab_Y := Mouse_Y - Top_Of (Item);
               Handled := True;
            end if;

         when SDL3.Events.Mouse_Move =>
            Item.Pointer_Y := Mouse_Y;
            if Item.Dragging then
               declare
                  Container : constant Widget_Access := Parent_Of (Item);
                  Room_X : constant Float :=
                    Float'Max
                      (0.0, Width_Of (Container.all) - Width_Of (Item));
                  Room_Y : constant Float :=
                    Float'Max
                      (0.0, Height_Of (Container.all) - Height_Of (Item));
               begin
                  Set_Position
                    (Node (Item), Yoga.Left,
                     Float'Min
                       (Room_X,
                        Float'Max
                          (0.0, Mouse_X - Item.Grab_X
                                - Left_Of (Container.all))));
                  Set_Position
                    (Node (Item), Yoga.Top,
                     Float'Min
                       (Room_Y,
                        Float'Max
                          (0.0, Mouse_Y - Item.Grab_Y
                                - Top_Of (Container.all))));
                  Request_Layout (Item);
               end;
               Handled := True;
            end if;

         when SDL3.Events.Mouse_Up =>
            if Item.Dragging and then Event.Button = 1 then
               Item.Dragging := False;
               Handled := True;
            end if;

         when others =>
            null;
      end case;
   end Handle;

   overriding function Cursor (Item : Palette) return SDL3.Cursors.Kind is
     (if Item.Dragging
        or else (Is_Hovered (Item)
                 and then Item.Pointer_Y < Top_Of (Item)
                                           + Grip_Height * Density (Item))
      then SDL3.Cursors.Move else SDL3.Cursors.Default);

end UI.Widgets.Palettes;
