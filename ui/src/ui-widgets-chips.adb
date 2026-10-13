with UI.Boxes;
with UI.Icons;

package body UI.Widgets.Chips is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   --  In points
   Pad         : constant Float := 6.0;
   Gap         : constant Float := 6.0;
   Swatch_Size : constant Float := 8.0;
   Cross_Size  : constant Float := 14.0;
   Cross_Icon  : constant Float := 8.0;
   Cross_Inset : constant Float := 3.0;  --  from the right and the top

   procedure Changed_Look (Item : in out Chip);

   procedure Changed_Look (Item : in out Chip) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Label (Item : in out Chip; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         Changed_Look (Item);
      end if;
   end Set_Label;

   function Label (Item : Chip) return String is
     (Item.Text (1 .. Item.Length));

   procedure Set_Swatch (Item : in out Chip; To : Themes.Slot) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      Changed_Look (Item);
   end Set_Swatch;

   procedure Take_Close (Item : in out Chip; Closed : out Boolean) is
   begin
      Closed := Item.Closed;
      Item.Closed := False;
   end Take_Close;

   procedure Cross_Box (Item : Chip; Left, Top, Side : out Float);
   --  Where the cross's button is, in pixels, with its shadow.

   procedure Cross_Box (Item : Chip; Left, Top, Side : out Float) is
      Pixels : constant Float := Density (Item);
   begin
      Side := Float'Rounding (Cross_Size * Pixels);
      Left := Float'Rounding
        (Left_Of (Item) + Width_Of (Item) - Cross_Inset * Pixels - Side);
      Top := Float'Rounding (Top_Of (Item) + (Height_Of (Item) - Side) / 2.0);
   end Cross_Box;

   function On_Cross (Item : Chip; X, Y : Float) return Boolean is
      Left, Top, Side : Float;
   begin
      Cross_Box (Item, Left, Top, Side);
      return X in Left .. Left + Side and then Y in Top .. Top + Side;
   end On_Cross;

   overriding procedure Handle
     (Item    : in out Chip;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Density (Item);
      Y : constant Float := Event.Mouse_Y * Density (Item);
      Over : constant Boolean := On_Cross (Item, X, Y);
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Move =>
            if Over /= Item.Over then
               Item.Over := Over;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               Item.Closed := Over;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Chip; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over then
         Item.Over := False;
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding procedure Draw
     (Item   : in out Chip;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := UI.Boxes.Edge (Pixels);
      Middle : constant Float := Top_Of (Item) + Height_Of (Item) / 2.0;
      After  : Float := Left_Of (Item) + Pad * Pixels;
      Left, Top, Side : Float;
      Look   : UI.Boxes.Raised_Look;
      X, Y, W, H : Float;
   begin
      Fill_Rect
        (Target, Colors.Page, Left_Of (Item), Top_Of (Item),
         Width_Of (Item), Height_Of (Item));
      UI.Boxes.Outline
        (Target, Colors.Border, Left_Of (Item), Top_Of (Item),
         Width_Of (Item), Height_Of (Item), Edge);
      if Item.Swatched then
         declare
            Size : constant Float := Float'Rounding (Swatch_Size * Pixels);
         begin
            Fill_Rect
              (Target, Themes.Resolve (Colors, Item.Swatch),
               Float'Rounding (After),
               Float'Rounding (Middle - Size / 2.0), Size, Size);
            After := After + Size + Gap * Pixels;
         end;
      end if;
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         UI.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Colors.Foreground, Label (Item),
            After, Middle, Pixels);
      end if;
      Cross_Box (Item, Left, Top, Side);
      Look :=
        (Face    =>
           (if Item.Over and then not Item.Down
            then Themes.Mix (Colors.Face, Themes.White, 0.22)
            else Colors.Face),
         Border  => Colors.Border,
         Edges_Given => False,
         Lit => (0, 0, 0, 255),
         Shaded => (0, 0, 0, 255),
         Drop    => Colors.Drop_Shadow,
         Pressed => Item.Down and then Item.Over,
         Flat    => False);
      UI.Boxes.Draw_Raised (Target, Look, Left, Top, Side, Side, Pixels);
      UI.Boxes.Raised_Face (Look, Left, Top, Side, Side, Pixels, X, Y, W, H);
      if Icon_Library (Item) /= null then
         declare
            Size  : constant Positive :=
              Positive (Float'Rounding (Cross_Icon * Pixels));
            Drawn : Boolean;
         begin
            UI.Icons.Draw
              (Icon_Library (Item).all, Target, UI.Icons.Close,
               Colors.Foreground,
               Float'Rounding (X + (W - Float (Size)) / 2.0),
               Float'Rounding (Y + (H - Float (Size)) / 2.0), Size, Drawn);
         end;
      end if;
   end Draw;

end UI.Widgets.Chips;
