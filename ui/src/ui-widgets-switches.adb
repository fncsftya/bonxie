with UI.Boxes;

package body UI.Widgets.Switches is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Gap  : constant Float := 8.0;  --  in points, before the label
   Room : constant Float := 2.0;  --  in points, round the knob in the track

   procedure Changed_Look (Item : in out Switch);
   --  Draw it again, if it is in a tree.

   procedure Changed_Look (Item : in out Switch) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Label (Item : in out Switch; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         Changed_Look (Item);
      end if;
   end Set_Label;

   function Label (Item : Switch) return String is
     (Item.Text (1 .. Item.Length));

   procedure Set_On (Item : in out Switch; To : Boolean) is
   begin
      if To /= Item.On then
         Item.On := To;
         Changed_Look (Item);
      end if;
   end Set_On;

   function Is_On (Item : Switch) return Boolean is (Item.On);

   procedure Set_Enabled (Item : in out Switch; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         Item.Down := False;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Switch) return Boolean is (Item.Enabled);

   procedure Take_Change (Item : in out Switch; Changed : out Boolean) is
   begin
      Changed := Item.Changed;
      Item.Changed := False;
   end Take_Change;

   overriding procedure Handle
     (Item    : in out Switch;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Over : constant Boolean :=
        Contains (Item, Event.Mouse_X * Density (Item),
                  Event.Mouse_Y * Density (Item));
   begin
      Handled := False;
      if not Item.Enabled then
         return;
      end if;
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
               if Over then
                  Item.On := not Item.On;
                  Item.Changed := True;
               end if;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Switch; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor (Item : Switch) return SDL3.Cursors.Kind is
     (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Switch;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := UI.Boxes.Edge (Pixels);
      Wide   : constant Float := Float'Rounding (Track_Width * Pixels);
      High   : constant Float := Float'Rounding (Track_Height * Pixels);
      Left   : constant Float := Float'Rounding (Left_Of (Item));
      Top    : constant Float :=
        Float'Rounding (Top_Of (Item) + (Height_Of (Item) - High) / 2.0);
      Track  : constant Themes.Color :=
        (if Item.On then Colors.Primary else Colors.Face);
      Inner  : constant Float := Float'Rounding (Room * Pixels) + Edge;
      Knob_High : constant Float := High - 2.0 * Inner;
      Knob_Wide : constant Float := Float'Rounding (Wide / 2.0) - Inner;
      Pressed : constant Boolean := Item.Down and then Is_Hovered (Item);
   begin
      --  The track, sunk.
      Fill_Rect
        (Target,
         (if Item.Enabled then Track else Themes.Dull (Colors, Track)),
         Left, Top, Wide, High);
      UI.Boxes.Outline
        (Target,
         (if Item.Enabled then Themes.Mix (Track, Colors.Foreground, 0.35)
          else Themes.Dull (Colors, Colors.Border)),
         Left, Top, Wide, High, Edge);
      if Item.Enabled then
         UI.Boxes.Bevel
           (Target, Track, Left + Edge, Top + Edge, Wide - 2.0 * Edge,
            High - 2.0 * Edge, Pixels, Sunken => True);
      end if;
      --  The knob, standing up in it, at the end it is turned to.
      declare
         Face : constant Themes.Color :=
           (if not Item.Enabled then Themes.Dull (Colors, Colors.Face)
            elsif Is_Hovered (Item) and then not Pressed
            then Themes.Mix (Colors.Face, Themes.White, 0.22)
            else Colors.Face);
         X : constant Float :=
           (if Item.On then Left + Wide - Inner - Knob_Wide else Left + Inner);
      begin
         Fill_Rect (Target, Face, X, Top + Inner, Knob_Wide, Knob_High);
         UI.Boxes.Outline
           (Target,
            (if Item.Enabled then Colors.Border
             else Themes.Dull (Colors, Colors.Border)),
            X, Top + Inner, Knob_Wide, Knob_High, Edge);
         if Item.Enabled then
            UI.Boxes.Bevel
              (Target, Face, X + Edge, Top + Inner + Edge,
               Knob_Wide - 2.0 * Edge, Knob_High - 2.0 * Edge, Pixels,
               Sunken => Pressed);
         end if;
      end;
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         UI.Line_Texts.Draw
           (Text_Lines (Item).all, Target,
            (if Item.Enabled then Colors.Foreground
             else Themes.Quiet (Colors)),
            Label (Item), Left + Wide + Gap * Pixels,
            Top_Of (Item) + Height_Of (Item) / 2.0, Pixels);
      end if;
   end Draw;

end UI.Widgets.Switches;
