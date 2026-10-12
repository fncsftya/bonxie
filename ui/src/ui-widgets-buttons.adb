package body UI.Widgets.Buttons is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Outline : constant := 1.0;  --  in points

   procedure Set_Label (Item : in out Button; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Label;

   function Label (Item : Button) return String is
     (Item.Text (1 .. Item.Length));

   procedure Take_Click (Item : in out Button; Clicked : out Boolean) is
   begin
      Clicked := Item.Clicked;
      Item.Clicked := False;
   end Take_Click;

   function Is_Pressed (Item : Button) return Boolean is
     (Item.Down and then Is_Hovered (Item));

   overriding procedure Handle
     (Item    : in out Button;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Over : constant Boolean :=
        Contains (Item, Event.Mouse_X * Density (Item),
                  Event.Mouse_Y * Density (Item));
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               Item.Clicked := Over;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Button; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding procedure Draw
     (Item   : in out Button;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Edge  : constant Float := Outline * Density (Item);
      Face  : constant Themes.Color :=
        (if Is_Pressed (Item)
         then Themes.Mix (Colors.Background, Colors.Accent, 0.5)
         else Themes.Mix
                (Colors.Background, Colors.Foreground,
                 (if Is_Hovered (Item) then 0.25 else 0.12)));
      Scale : constant Positive :=
        Positive (Float'Max (1.0, Float'Rounding (Density (Item))));
      Wide  : constant Float :=
        Float (Item.Length * Debug_Text_Size * Scale);
      High  : constant Float := Float (Debug_Text_Size * Scale);
   begin
      Fill_Rect
        (Target, Colors.Foreground,
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      Fill_Rect
        (Target, Face,
         Left_Of (Item) + Edge, Top_Of (Item) + Edge,
         Float'Max (0.0, Width_Of (Item) - 2.0 * Edge),
         Float'Max (0.0, Height_Of (Item) - 2.0 * Edge));
      if Item.Length > 0 then
         Draw_Text
           (Target, Colors.Foreground,
            Float'Rounding (Left_Of (Item) + (Width_Of (Item) - Wide) / 2.0),
            Float'Rounding (Top_Of (Item) + (Height_Of (Item) - High) / 2.0),
            Label (Item), Scale);
      end if;
   end Draw;

end UI.Widgets.Buttons;
