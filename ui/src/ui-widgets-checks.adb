with UI.Boxes;
with UI.Icons;

package body UI.Widgets.Checks is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Gap         : constant Float := 7.0;
   Swatch_Size : constant Float := 9.0;
   Dot_Inset   : constant Float := 3.5;
   Tick_Size   : constant Float := 11.0;
   --  In points: after the box, and after the swatch; the side of the
   --  swatch; of a chosen radio's square from the box's edge; of the tick.

   procedure Changed_Look (Item : in out Check);
   --  Draw it again, if it is in a tree.

   procedure Changed_Look (Item : in out Check) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Kind (Item : in out Check; To : Kind) is
   begin
      if To /= Item.Form then
         Item.Form := To;
         Changed_Look (Item);
      end if;
   end Set_Kind;

   function Kind_Of (Item : Check) return Kind is (Item.Form);

   procedure Set_Label (Item : in out Check; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         Changed_Look (Item);
      end if;
   end Set_Label;

   function Label (Item : Check) return String is
     (Item.Text (1 .. Item.Length));

   procedure Set_Checked (Item : in out Check; To : Boolean) is
   begin
      if To /= Item.Checked then
         Item.Checked := To;
         Changed_Look (Item);
      end if;
   end Set_Checked;

   function Is_Checked (Item : Check) return Boolean is (Item.Checked);

   procedure Set_Swatch (Item : in out Check; To : Themes.Color) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      Changed_Look (Item);
   end Set_Swatch;

   procedure Set_Enabled (Item : in out Check; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         Item.Down := False;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Check) return Boolean is (Item.Enabled);

   procedure Take_Change (Item : in out Check; Changed : out Boolean) is
   begin
      Changed := Item.Changed;
      Item.Changed := False;
   end Take_Change;

   overriding procedure Handle
     (Item    : in out Check;
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
               --  A radio that is chosen stays so.
               if Over and then not (Item.Form = Radio and then Item.Checked)
               then
                  Item.Checked := not Item.Checked;
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
     (Item : in out Check; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor (Item : Check) return SDL3.Cursors.Kind is
     (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Check;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := UI.Boxes.Edge (Pixels);
      Side   : constant Float := Float'Rounding (Box_Size * Pixels);
      Left   : constant Float := Float'Rounding (Left_Of (Item));
      Top    : constant Float :=
        Float'Rounding (Top_Of (Item) + (Height_Of (Item) - Side) / 2.0);
      Paper  : constant Themes.Color :=
        (if not Item.Enabled then Colors.Tint
         elsif Item.Down and then Is_Hovered (Item) then Colors.Background
         else Themes.White);
      Ink    : constant Themes.Color :=
        (if Item.Enabled then Colors.Foreground else Themes.Quiet (Colors));
      Ring   : constant Themes.Color :=
        (if not Item.Enabled then Themes.Dull (Colors, Colors.Border)
         elsif Is_Hovered (Item) then Colors.Foreground
         else Themes.Mix (Colors.Border, Colors.Foreground, 0.35));
      After  : Float := Left + Side + Gap * Pixels;
   begin
      --  The box, sunk: the shade inside its top and left.
      Fill_Rect (Target, Paper, Left, Top, Side, Side);
      UI.Boxes.Outline (Target, Ring, Left, Top, Side, Side, Edge);
      if Item.Enabled then
         Fill_Rect
           (Target, Themes.Shade (Colors.Background), Left + Edge, Top + Edge,
            Side - 2.0 * Edge, Edge);
         Fill_Rect
           (Target, Themes.Shade (Colors.Background), Left + Edge, Top + Edge,
            Edge, Side - 2.0 * Edge);
      end if;
      if Item.Checked then
         case Item.Form is
            when Radio =>
               declare
                  In_By : constant Float :=
                    Float'Rounding (Dot_Inset * Pixels);
               begin
                  Fill_Rect
                    (Target, Ink, Left + In_By, Top + In_By,
                     Side - 2.0 * In_By, Side - 2.0 * In_By);
               end;
            when Box =>
               if Icon_Library (Item) /= null then
                  declare
                     Size  : constant Positive :=
                       Positive (Float'Rounding (Tick_Size * Pixels));
                     Drawn : Boolean;
                  begin
                     UI.Icons.Draw
                       (Icon_Library (Item).all, Target, UI.Icons.Check, Ink,
                        Float'Rounding (Left + (Side - Float (Size)) / 2.0),
                        Float'Rounding (Top + (Side - Float (Size)) / 2.0),
                        Size, Drawn);
                  end;
               end if;
         end case;
      end if;
      if Item.Swatched then
         declare
            Square : constant Float := Float'Rounding (Swatch_Size * Pixels);
         begin
            Fill_Rect
              (Target,
               (if Item.Enabled then Item.Swatch
                else Themes.Dull (Colors, Item.Swatch)),
               After, Float'Rounding (Top + (Side - Square) / 2.0),
               Square, Square);
            After := After + Square + Gap * Pixels;
         end;
      end if;
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         UI.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Ink, Label (Item), After,
            Top_Of (Item) + Height_Of (Item) / 2.0, Pixels);
      end if;
   end Draw;

end UI.Widgets.Checks;
