package body UI.Widgets.Buttons is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Bevel : constant := 2.0;  --  in points: how wide the edges are
   Icon_Size : constant := 20.0;  --  in points, a side
   Caption_Gap : constant := 6.0;  --  between an icon and its label
   White : constant Themes.Color := (255, 255, 255, 255);
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

   procedure Set_Swatch (Item : in out Button; To : Themes.Color) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Swatch;

   function Has_Icon (Item : Button) return Boolean is (Item.Picture);

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
      Edge  : constant Float := Bevel * Density (Item);
      Sunk  : constant Boolean := Is_Pressed (Item) or else Item.Selected;
      Face  : constant Themes.Color :=
        (if Item.Style /= Normal
         then Themes.Mix
                ((if Item.Style = Danger then Colors.Danger
                  else Colors.Primary),
                 Colors.Foreground,
                 (if Is_Pressed (Item) then 0.35
                  elsif Is_Hovered (Item) then 0.15 else 0.0))
         elsif Sunk
         then Themes.Mix (Colors.Background, Colors.Accent, 0.5)
         else Themes.Mix
                (Colors.Background, Colors.Foreground,
                 (if Is_Hovered (Item) then 0.25 else 0.12)));
      Ink   : constant Themes.Color :=
        (if Item.Style /= Normal then Colors.Background
         else Colors.Foreground);
      Lit   : constant Themes.Color :=
        (if Sunk then Themes.Shade (Face)
         else Themes.Highlight (Face));
      Dim   : constant Themes.Color :=
        (if Sunk then Themes.Highlight (Face)
         else Themes.Shade (Face));
      Shift : constant Float :=
        (if Sunk then Density (Item) else 0.0);
      Icon_Drawn : Boolean := False;
      Text_Left  : Float := 0.0;
      Scale : constant Positive :=
        Positive (Float'Max (1.0, Float'Rounding (Density (Item))));
      Wide  : constant Float :=
        Float (Item.Length * Debug_Text_Size * Scale);
      High  : constant Float := Float (Debug_Text_Size * Scale);
      Span  : constant Float := Label_Span (Item, Wide);
      Together : constant Boolean :=
        Item.Picture and then Item.Captioned and then Item.Length > 0;
   begin
      --  A face with a bevel and no outline: light on its top and left,
      --  shade on its bottom and right, as if it stood out; the other
      --  way round, pressed in, with the label moved with it.
      Fill_Rect
        (Target, Face,
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      Fill_Rect (Target, Lit, Left_Of (Item), Top_Of (Item),
                 Width_Of (Item), Edge);
      Fill_Rect (Target, Lit, Left_Of (Item), Top_Of (Item),
                 Edge, Height_Of (Item));
      Fill_Rect (Target, Dim, Left_Of (Item),
                 Top_Of (Item) + Height_Of (Item) - Edge,
                 Width_Of (Item), Edge);
      Fill_Rect (Target, Dim, Left_Of (Item) + Width_Of (Item) - Edge,
                 Top_Of (Item), Edge, Height_Of (Item));
      --  The icon, if there is one, and the label, in the middle of the
      --  button: together, icon first, if it is captioned; otherwise the
      --  label only where the icon cannot be drawn.
      if Item.Swatched then
         declare
            Side : constant Float := Icon_Size * 0.5 * Density (Item);
         begin
            Fill_Rect
              (Target, Item.Swatch,
               Float'Rounding
                 (Left_Of (Item) + (Width_Of (Item) - Side) / 2.0 + Shift),
               Float'Rounding
                 (Top_Of (Item) + (Height_Of (Item) - Side) / 2.0 + Shift),
               Side, Side);
            Icon_Drawn := True;
         end;
      elsif Item.Picture and then Icon_Library (Item) /= null then
         declare
            Size : constant Positive :=
              Positive (Float'Rounding (Icon_Size * Density (Item)));
            Group_Left : constant Float :=
              Left_Of (Item)
              + (Width_Of (Item)
                 - (if Together
                    then (Icon_Size + Caption_Gap) * Density (Item) + Span
                    else Float (Size))) / 2.0;
            Drawn : Boolean;
         begin
            Icons.Draw
              (Icon_Library (Item).all, Target,
               Item.Which,
               (if Item.Style /= Normal then White else Colors.Foreground),
               Float'Rounding (Group_Left + Shift),
               Float'Rounding
                 (Top_Of (Item) + (Height_Of (Item) - Float (Size)) / 2.0
                  + Shift),
               Size, Drawn);
            Icon_Drawn := Drawn;
            Text_Left := Group_Left + (Icon_Size + Caption_Gap)
                                      * Density (Item);
         end;
      end if;
      if Item.Length > 0 and then (Together or else not Icon_Drawn) then
         if not (Together and then Icon_Drawn) then
            Text_Left :=
              Left_Of (Item) + (Width_Of (Item) - Span) / 2.0;
         end if;
         if Text_Lines (Item) /= null then
            UI.Line_Texts.Draw
              (Text_Lines (Item).all, Target, Ink, Label (Item),
               Text_Left + Shift,
               Top_Of (Item) + Height_Of (Item) / 2.0 + Shift,
               Density (Item), UI.Line_Texts.Strong);
         else
            Draw_Text
              (Target, Ink, Float'Rounding (Text_Left + Shift),
               Float'Rounding
                 (Top_Of (Item) + (Height_Of (Item) - High) / 2.0 + Shift),
               Label (Item), Scale);
         end if;
      end if;
   end Draw;

end UI.Widgets.Buttons;
