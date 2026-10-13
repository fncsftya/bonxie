with Ada.Strings.Fixed;
with UI.Boxes;

package body UI.Widgets.Buttons is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Icon_Size : constant := 16.0;  --  in points, a side
   Caption_Gap : constant := 7.0;  --  between an icon and its label
   Badge_Size : constant := 16.0;  --  in points, a side
   Badge_Gap  : constant := 6.0;   --  between the label and the badge
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

   procedure Set_Swatch (Item : in out Button; To : Themes.Color) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Swatch;

   function Has_Icon (Item : Button) return Boolean is (Item.Picture);

   procedure Set_Raised (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Raised then
         Item.Raised := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Raised;

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
      Pixels : constant Float := Density (Item);
      Pressed : constant Boolean := Is_Pressed (Item);
      Hovered : constant Boolean := Is_Hovered (Item);
      Base  : constant Themes.Color :=
        (case Item.Style is
            when Primary => Colors.Primary,
            when Danger  => Colors.Danger,
            when Normal | Quiet =>
              (if Item.Selected then Colors.Accent else Colors.Face));
      Face  : constant Themes.Color :=
        (if Pressed then Themes.Mix (Base, Colors.Foreground, 0.18)
         elsif not Hovered then Base
         elsif Item.Style in Primary | Danger
         then Themes.Mix (Base, Colors.Foreground, 0.12)
         else Themes.Mix (Base, White, 0.22));
      Ink   : constant Themes.Color :=
        (case Item.Style is
            when Primary | Danger => White,
            when Quiet =>
              (if Hovered or else Item.Selected then White
               else Themes.Mix (Colors.Face, White, 0.35)),
            when Normal => Colors.Foreground);
      Look  : constant UI.Boxes.Look :=
        (Filled   => Item.Style /= Quiet,
         Fill     => Face,
         Bordered => Item.Style /= Quiet,
         Border   =>
           (if Item.Style = Normal and then not Item.Selected
            then Colors.Border
            else Themes.Mix (Base, Colors.Foreground, 0.3)),
         Dashed   => False,
         Shadowed => Item.Raised,
         Shadow   => Colors.Shadow);
      Off   : constant Float := UI.Boxes.Inset (Look, Pixels);
      Wide_Box : constant Float := Width_Of (Item) - Off;
      High_Box : constant Float := Height_Of (Item) - Off;
      Shift : constant Float :=
        (if Pressed then Float'Rounding (Pixels) else 0.0);
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
      UI.Boxes.Draw
        (Target, Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item), Pixels);
      --  The icon, if there is one, and the label, in the middle of the
      --  face: together, icon first, if it is captioned; otherwise the
      --  label only where the icon cannot be drawn.
      if Item.Swatched then
         declare
            Side : constant Float := 10.0 * Pixels;
         begin
            Fill_Rect
              (Target, Item.Swatch,
               Float'Rounding
                 (Left_Of (Item) + (Wide_Box - Side) / 2.0 + Shift),
               Float'Rounding
                 (Top_Of (Item) + (High_Box - Side) / 2.0 + Shift),
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
              Left_Of (Item)
              + (Wide_Box
                 - (if Together
                    then (Points + Caption_Gap) * Pixels + Span + Badge_Room
                    else Float (Size))) / 2.0;
            Drawn : Boolean;
         begin
            Icons.Draw
              (Icon_Library (Item).all, Target,
               Item.Which, Ink,
               Float'Rounding (Group_Left + Shift),
               Float'Rounding
                 (Top_Of (Item) + (High_Box - Float (Size)) / 2.0 + Shift),
               Size, Drawn);
            Icon_Drawn := Drawn;
            Text_Left := Group_Left + (Points + Caption_Gap) * Pixels;
         end;
      end if;
      if Item.Length > 0 and then (Together or else not Icon_Drawn) then
         if not (Together and then Icon_Drawn) then
            Text_Left :=
              Left_Of (Item) + (Wide_Box - Span - Badge_Room) / 2.0;
         end if;
         if Text_Lines (Item) /= null then
            UI.Line_Texts.Draw
              (Text_Lines (Item).all, Target, Ink, Label (Item),
               Text_Left + Shift,
               Top_Of (Item) + High_Box / 2.0 + Shift,
               Pixels, UI.Line_Texts.Strong);
         else
            Draw_Text
              (Target, Ink, Float'Rounding (Text_Left + Shift),
               Float'Rounding
                 (Top_Of (Item) + (High_Box - High) / 2.0 + Shift),
               Label (Item), Scale);
         end if;
         --  The count, white in a dark square, after the label.
         if Badged then
            declare
               Count : constant String :=
                 Ada.Strings.Fixed.Trim (Item.Badge'Image, Ada.Strings.Both);
               Side  : constant Float := Float'Rounding (Badge_Size * Pixels);
               Left  : constant Float :=
                 Float'Rounding
                   (Text_Left + Span + Badge_Gap * Pixels + Shift);
               Top   : constant Float :=
                 Float'Rounding
                   (Top_Of (Item) + (High_Box - Side) / 2.0 + Shift);
            begin
               Fill_Rect (Target, Colors.Bar, Left, Top, Side, Side);
               UI.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, White, Count,
                  Left + (Side - UI.Line_Texts.Width
                                   (Text_Lines (Item).all, Count, Pixels,
                                    UI.Line_Texts.Strong)) / 2.0,
                  Top + Side / 2.0, Pixels, UI.Line_Texts.Strong);
            end;
         end if;
      end if;
   end Draw;

end UI.Widgets.Buttons;
