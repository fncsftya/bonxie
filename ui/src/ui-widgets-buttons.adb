with Ada.Strings.Fixed;
with UI.Boxes;

package body UI.Widgets.Buttons is

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use SDL3.Windows.Renderers;

   Icon_Size : constant := 16.0;  --  in points, a side
   Caption_Gap : constant := 7.0;  --  between an icon and its label
   Badge_Size : constant := 16.0;  --  in points, a side
   Badge_Gap  : constant := 6.0;   --  between the label and the badge
   Caret_Size : constant := 10.0;  --  in points, a side, of a dropdown's
   Ring_Width : constant := 2.0;   --  in points, of the ring of the focus
   White : constant Themes.Color := Themes.White;
   --  For an icon on a button of a colour of its own.

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

   procedure Set_Kind (Item : in out Button; To : Kind) is
   begin
      if To /= Item.Style then
         Item.Style := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Kind;

   procedure Set_Icon (Item : in out Button; To : UI.Icons.Icon) is
      use type UI.Icons.Icon;
   begin
      if not Item.Picture or else Item.Which /= To then
         Item.Picture := True;
         Item.Which := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Icon;

   procedure Set_Icon_Size (Item : in out Button; Points : Float) is
   begin
      if Item.Icon_Points /= Points then
         Item.Icon_Points := Points;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Icon_Size;

   procedure Set_Swatch (Item : in out Button; To : Themes.Slot) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Swatch;

   function Has_Icon (Item : Button) return Boolean is (Item.Picture);

   procedure Set_Badge (Item : in out Button; Count : Natural) is
   begin
      if Count /= Item.Badge then
         Item.Badge := Count;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Badge;

   procedure Set_Captioned (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Captioned then
         Item.Captioned := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Captioned;

   procedure Set_Selected (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Selected then
         Item.Selected := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Selected;

   function Is_Selected (Item : Button) return Boolean is (Item.Selected);

   procedure Set_Dropdown (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Dropdown then
         Item.Dropdown := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Dropdown;

   function Is_Dropdown (Item : Button) return Boolean is (Item.Dropdown);

   procedure Set_Enabled (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         if not To then
            Item.Down := False;
            Item.Clicked := False;
            if Is_Attached (Item) and then Has_Focus (Item) then
               Release_Focus (Item);
            end if;
         end if;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Button) return Boolean is (Item.Enabled);

   procedure Set_Focusable (Item : in out Button; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding function Accepts_Focus (Item : Button) return Boolean is
     (Item.Focusable and then Item.Enabled);

   overriding procedure Focus_Changed
     (Item : in out Button; Focused : Boolean)
   is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   function Kind_Of (Item : Button) return Kind is (Item.Style);

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
      if not Item.Enabled then
         return;
      end if;
      case Event.Kind is
         when SDL3.Events.Key_Down =>
            --  Only with the focus: keys come to others as shortcuts.
            if Has_Focus (Item)
              and then (Event.Key = SDL3.Events.Key_Return
                        or else Event.Key = SDL3.Events.Key_Space)
              and then not Event.Command
            then
               Item.Clicked := True;
               Handled := True;
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

   function Label_Span (Item : Button; Wide : Float) return Float;
   --  Of the label, in pixels, as it is drawn: in the one style every
   --  button's label has, whatever else is on the button.

   function Label_Span (Item : Button; Wide : Float) return Float is
     (if Item.Length = 0 then 0.0
      elsif Text_Lines (Item) /= null
      then UI.Line_Texts.Width
             (Text_Lines (Item).all, Label (Item), Density (Item),
              UI.Line_Texts.Strong)
      else Wide);

   overriding procedure Draw
     (Item   : in out Button;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels  : constant Float := Density (Item);
      Edge    : constant Float := UI.Boxes.Edge (Pixels);
      Pressed : constant Boolean := Item.Enabled and then Is_Pressed (Item);
      Hovered : constant Boolean := Item.Enabled and then Is_Hovered (Item);
      Toggled : constant Boolean := Item.Selected and then not Item.Dropdown;
      --  Pressed in, in the accent; an open dropdown is in its own face.
      --  A plain face, not toggled, has the theme's own tones for its
      --  states; the others are made from their base.
      Plain : constant Boolean :=
        Item.Style in Normal | Quiet and then not Toggled;
      Base  : constant Themes.Color :=
        (case Item.Style is
            when Primary => Colors.Primary,
            when Danger  => Colors.Danger,
            when Normal | Quiet =>
              (if Toggled then Colors.Accent else Colors.Face));
      Face  : constant Themes.Color :=
        (if not Item.Enabled then Themes.Dull (Colors, Base)
         elsif Pressed then
           (if Plain then Colors.Face_Pressed
            else Themes.Mix (Base, Colors.Foreground, 0.12))
         elsif not Hovered then Base
         elsif Plain then Colors.Face_Hover
         elsif Item.Style in Primary | Danger
         then Themes.Mix (Base, White, 0.12)
         else Themes.Mix (Base, White, 0.22));
      --  At rest, the bevel is the theme's own; a face that is pressed or
      --  under the pointer has its bevel made from the face it shows.
      Resting : constant Boolean := not Pressed and then not Hovered;
      Lit    : constant Themes.Color :=
        (if Resting and then Plain then Colors.Face_Light
         elsif Resting and then Item.Style = Primary then Colors.Primary_Light
         elsif Resting and then Item.Style = Danger then Colors.Danger_Light
         else Themes.Highlight (Face));
      Shaded : constant Themes.Color :=
        (if Resting and then Plain then Colors.Face_Shade
         elsif Resting and then Item.Style = Primary then Colors.Primary_Shade
         elsif Resting and then Item.Style = Danger then Colors.Danger_Shade
         else Themes.Shade (Face));
      Ink   : constant Themes.Color :=
        (case Item.Style is
            when Primary | Danger =>
              (if Item.Enabled then White else Themes.Mix (White, Face, 0.3)),
            when Quiet =>
              (if Hovered or else Item.Selected then White
               else Themes.Mix (Colors.Face, White, 0.35)),
            when Normal =>
              (if Item.Enabled then
                 (if Toggled then Colors.On_Accent else Colors.Foreground)
               else Themes.Mix (Colors.Foreground, Face, 0.6)));
      Border : constant Themes.Color :=
        (if Item.Style = Normal and then not Toggled then Colors.Face_Edge
         else Themes.Mix (Base, Colors.Foreground, 0.3));
      Look  : constant UI.Boxes.Raised_Look :=
        (Face    => Face,
         Edges_Given => True,
         Lit     => Lit,
         Shaded  => Shaded,
         Border  =>
           (if Item.Enabled then Border else Themes.Dull (Colors, Border)),
         Drop    => Colors.Drop_Shadow,
         Pressed => Pressed or else Item.Selected,
         Flat    => not Item.Enabled);
      Left, Top, Wide_Box, High_Box : Float;
      --  The face, which what is on it goes with.
      Caret_Room : Float := 0.0;
      Icon_Drawn : Boolean := False;
      Text_Left  : Float := 0.0;
      Scale : constant Positive :=
        Positive (Float'Max (1.0, Float'Rounding (Pixels)));
      Wide  : constant Float :=
        Float (Item.Length * Debug_Text_Size * Scale);
      High  : constant Float := Float (Debug_Text_Size * Scale);
      Span  : constant Float := Label_Span (Item, Wide);
      Together : constant Boolean :=
        Item.Picture and then Item.Captioned and then Item.Length > 0;
      Badged : constant Boolean :=
        Item.Badge > 0 and then Item.Length > 0
        and then Text_Lines (Item) /= null;
      Badge_Room : constant Float :=
        (if Badged then (Badge_Gap + Badge_Size) * Pixels else 0.0);
   begin
      if Item.Style = Quiet then
         --  No face: what is on it goes down and right as it is pressed.
         declare
            Moved : constant Float :=
              (if Pressed then UI.Boxes.Shift (Pixels) else 0.0);
         begin
            Left := Left_Of (Item) + Moved;
            Top := Top_Of (Item) + Moved;
            Wide_Box := Width_Of (Item);
            High_Box := Height_Of (Item);
         end;
      else
         UI.Boxes.Draw_Raised
           (Target, Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
            Height_Of (Item), Pixels);
         UI.Boxes.Raised_Face
           (Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
            Height_Of (Item), Pixels, Left, Top, Wide_Box, High_Box);
         if Item.Focusable and then Has_Focus (Item) then
            UI.Boxes.Outline
              (Target, Colors.Focus, Left, Top, Wide_Box, High_Box,
               Float'Max (1.0, Float'Rounding (Ring_Width * Pixels)));
         end if;
      end if;

      --  A dropdown's caret, in a square of its own at the right, a groove
      --  between it and the rest; up while it is open.
      if Item.Dropdown and then Item.Style /= Quiet then
         Caret_Room := Float'Rounding (High_Box);
         declare
            Line : constant Float := Left + Wide_Box - Caret_Room;
            Size : constant Positive :=
              Positive (Float'Rounding (Caret_Size * Pixels));
            Drawn : Boolean;
         begin
            Fill_Rect
              (Target, Themes.Shade (Face), Line, Top + 2.0 * Edge, Edge,
               High_Box - 4.0 * Edge);
            Fill_Rect
              (Target, Themes.Highlight (Face), Line + Edge, Top + 2.0 * Edge,
               Edge, High_Box - 4.0 * Edge);
            if Icon_Library (Item) /= null then
               Icons.Draw
                 (Icon_Library (Item).all, Target,
                  (if Item.Selected then UI.Icons.Chevron_Up
                   else UI.Icons.Chevron_Down),
                  Ink,
                  Float'Rounding
                    (Line + Edge + (Caret_Room - Edge - Float (Size)) / 2.0),
                  Float'Rounding (Top + (High_Box - Float (Size)) / 2.0),
                  Size, Drawn);
            end if;
         end;
         Wide_Box := Wide_Box - Caret_Room;
      end if;

      --  The icon, if there is one, and the label, in the middle of the
      --  face: together, icon first, if it is captioned; otherwise the
      --  label only where the icon cannot be drawn.
      if Item.Swatched then
         declare
            Side : constant Float := 10.0 * Pixels;
         begin
            Fill_Rect
              (Target, Themes.Resolve (Colors, Item.Swatch),
               Float'Rounding (Left + (Wide_Box - Side) / 2.0),
               Float'Rounding (Top + (High_Box - Side) / 2.0),
               Side, Side);
            Icon_Drawn := True;
         end;
      elsif Item.Picture and then Icon_Library (Item) /= null then
         declare
            Points : constant Float :=
              (if Item.Icon_Points > 0.0 then Item.Icon_Points else Icon_Size);
            Size : constant Positive :=
              Positive (Float'Rounding (Points * Pixels));
            Group_Left : constant Float :=
              Left
              + (Wide_Box
                 - (if Together
                    then (Points + Caption_Gap) * Pixels + Span + Badge_Room
                    else Float (Size))) / 2.0;
            Drawn : Boolean;
         begin
            Icons.Draw
              (Icon_Library (Item).all, Target,
               Item.Which, Ink,
               Float'Rounding (Group_Left),
               Float'Rounding (Top + (High_Box - Float (Size)) / 2.0),
               Size, Drawn);
            Icon_Drawn := Drawn;
            Text_Left := Group_Left + (Points + Caption_Gap) * Pixels;
         end;
      end if;
      if Item.Length > 0 and then (Together or else not Icon_Drawn) then
         if not (Together and then Icon_Drawn) then
            Text_Left := Left + (Wide_Box - Span - Badge_Room) / 2.0;
         end if;
         if Text_Lines (Item) /= null then
            UI.Line_Texts.Draw
              (Text_Lines (Item).all, Target, Ink, Label (Item),
               Text_Left, Top + High_Box / 2.0,
               Pixels, UI.Line_Texts.Strong);
         else
            Draw_Text
              (Target, Ink, Float'Rounding (Text_Left),
               Float'Rounding (Top + (High_Box - High) / 2.0),
               Label (Item), Scale);
         end if;
         --  The count, white in a dark square, after the label.
         if Badged then
            declare
               Count : constant String :=
                 Ada.Strings.Fixed.Trim (Item.Badge'Image, Ada.Strings.Both);
               Side  : constant Float := Float'Rounding (Badge_Size * Pixels);
               Left_Edge : constant Float :=
                 Float'Rounding (Text_Left + Span + Badge_Gap * Pixels);
               Top_Edge  : constant Float :=
                 Float'Rounding (Top + (High_Box - Side) / 2.0);
            begin
               Fill_Rect
                 (Target,
                  (if Item.Enabled then Colors.Bar
                   else Themes.Dull (Colors, Colors.Bar)),
                  Left_Edge, Top_Edge, Side, Side);
               UI.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, White, Count,
                  Left_Edge + (Side - UI.Line_Texts.Width
                                        (Text_Lines (Item).all, Count, Pixels,
                                         UI.Line_Texts.Strong)) / 2.0,
                  Top_Edge + Side / 2.0, Pixels, UI.Line_Texts.Strong);
            end;
         end if;
      end if;
   end Draw;

end UI.Widgets.Buttons;
