with UI.Boxes;
with Yoga.Nodes;

package body UI.Widgets.Menus is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   --  In points

   Pad         : constant Float := 3.0;   --  above the first row, and below
   Inset       : constant Float := 10.0;  --  before what is in a row
   Gap         : constant Float := 8.0;   --  between the parts of a row
   Box_Size    : constant Float := 12.0;
   Tick_Size   : constant Float := 10.0;
   Icon_Size   : constant Float := 12.0;
   Swatch_Size : constant Float := 8.0;

   function Row_Height (Kind : Row_Kind) return Float is
     (case Kind is
         when Heading   => 24.0,
         when Separator => 9.0,
         when Action | Check | Note => 26.0);

   function Can_Click (Kind : Row_Kind) return Boolean is
     (Kind in Action | Check);

   procedure Fit (Item : in out Menu);
   --  Make it as tall as its rows, and draw it again.

   procedure Fit (Item : in out Menu) is
   begin
      if Is_Attached (Item) then
         Yoga.Nodes.Set_Height
           (Node (Item), Float'Rounding (Height_For (Item) * Density (Item)));
         Request_Layout (Item);
         Invalidate (Item);
      end if;
   end Fit;

   procedure Clear (Item : in out Menu) is
   begin
      Item.Used := 0;
      Item.Over := 0;
      Item.Pressed := 0;
      Item.Chosen := 0;
      Fit (Item);
   end Clear;

   procedure Add
     (Item    : in out Menu;
      Kind    : Row_Kind;
      Text    : String := "";
      Shade   : Tone := Plain;
      Checked : Boolean := False)
   is
      Made : Line;
   begin
      Made.Kind := Kind;
      Made.Length := Text'Length;
      Made.Text (1 .. Text'Length) := Text;
      Made.Shade := Shade;
      Made.Checked := Checked;
      Item.Used := Item.Used + 1;
      Item.Rows (Item.Used) := Made;
      Fit (Item);
   end Add;

   function Row_Count (Item : Menu) return Natural is (Item.Used);

   procedure Changed_Look (Item : in out Menu);

   procedure Changed_Look (Item : in out Menu) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Icon (Item : in out Menu; Row : Positive; To : UI.Icons.Icon)
   is
   begin
      Item.Rows (Row).Iconed := True;
      Item.Rows (Row).Which := To;
      Changed_Look (Item);
   end Set_Icon;

   procedure Set_Swatch
     (Item : in out Menu; Row : Positive; To : Themes.Color) is
   begin
      Item.Rows (Row).Swatched := True;
      Item.Rows (Row).Swatch := To;
      Changed_Look (Item);
   end Set_Swatch;

   procedure Set_Checked (Item : in out Menu; Row : Positive; To : Boolean)
   is
   begin
      if Item.Rows (Row).Checked /= To then
         Item.Rows (Row).Checked := To;
         Changed_Look (Item);
      end if;
   end Set_Checked;

   function Kind_Of (Item : Menu; Row : Positive) return Row_Kind is
     (Item.Rows (Row).Kind);

   function Text_Of (Item : Menu; Row : Positive) return String is
     (Item.Rows (Row).Text (1 .. Item.Rows (Row).Length));

   function Is_Checked (Item : Menu; Row : Positive) return Boolean is
     (Item.Rows (Row).Checked);

   function Height_For (Item : Menu) return Float is
      Total : Float := 2.0 * Pad + 2.0 + Themes.Shadow_Offset;
      --  The outline, a point each side, and the shadow.
   begin
      for Index in 1 .. Item.Used loop
         Total := Total + Row_Height (Item.Rows (Index).Kind);
      end loop;
      return Total;
   end Height_For;

   function Hovered_Row (Item : Menu) return Natural is (Item.Over);

   procedure Take_Choice (Item : in out Menu; Chosen : out Natural) is
   begin
      Chosen := Item.Chosen;
      Item.Chosen := 0;
   end Take_Choice;

   function First_Top (Item : Menu) return Float is
     (Top_Of (Item) + UI.Boxes.Edge (Density (Item))
      + Float'Rounding (Pad * Density (Item)));
   --  Of the first row, in pixels.

   function Row_At (Item : Menu; X, Y : Float) return Natural;
   --  The row that can be clicked at pixel X, Y; 0 if none.

   function Row_At (Item : Menu; X, Y : Float) return Natural is
      Pixels : constant Float := Density (Item);
      Top    : Float := First_Top (Item);
      Right  : constant Float :=
        Left_Of (Item) + Width_Of (Item) - UI.Boxes.Offset (Pixels);
   begin
      if X < Left_Of (Item) or else X >= Right then
         return 0;
      end if;
      for Index in 1 .. Item.Used loop
         declare
            High : constant Float :=
              Float'Rounding (Row_Height (Item.Rows (Index).Kind) * Pixels);
         begin
            if Y >= Top and then Y < Top + High then
               return (if Can_Click (Item.Rows (Index).Kind) then Index
                       else 0);
            end if;
            Top := Top + High;
         end;
      end loop;
      return 0;
   end Row_At;

   overriding procedure Handle
     (Item    : in out Menu;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Under : constant Natural :=
        Row_At (Item, Event.Mouse_X * Density (Item),
                Event.Mouse_Y * Density (Item));
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Move =>
            if Under /= Item.Over then
               Item.Over := Under;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1
              and then Contains (Item, Event.Mouse_X * Density (Item),
                                 Event.Mouse_Y * Density (Item))
            then
               --  Taken, so that a press on it is not on what is under it.
               Item.Pressed := Under;
               Item.Over := Under;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 then
               if Item.Pressed /= 0 and then Under = Item.Pressed then
                  Item.Chosen := Under;
               end if;
               Handled := Item.Pressed /= 0;
               Item.Pressed := 0;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Menu; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over /= 0 then
         Item.Over := 0;
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding function Cursor (Item : Menu) return SDL3.Cursors.Kind is
     (if Item.Over /= 0 then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Menu;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := UI.Boxes.Edge (Pixels);
      Look   : constant UI.Boxes.Look :=
        (Filled   => True,
         Fill     => Themes.White,
         Bordered => True,
         Border   => Colors.Border,
         Dashed   => False,
         Shadowed => True,
         Shadow   => Themes.Drop (Colors));
      Inner_Left  : constant Float := Left_Of (Item) + Edge;
      Inner_Width : constant Float :=
        Width_Of (Item) - UI.Boxes.Inset (Look, Pixels) - 2.0 * Edge;
      Top    : Float := First_Top (Item);
   begin
      UI.Boxes.Draw
        (Target, Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item), Pixels);
      for Index in 1 .. Item.Used loop
         declare
            Each   : Line renames Item.Rows (Index);
            High   : constant Float :=
              Float'Rounding (Row_Height (Each.Kind) * Pixels);
            Middle : constant Float := Top + High / 2.0;
            Ink    : constant Themes.Color :=
              (case Each.Kind is
                  when Heading | Note => Themes.Quiet (Colors),
                  when others =>
                    (case Each.Shade is
                        when Plain   => Colors.Foreground,
                        when Primary => Colors.Primary,
                        when Danger  => Colors.Danger));
            Using  : constant UI.Line_Texts.Style :=
              (case Each.Kind is
                  when Heading => UI.Line_Texts.Caption,
                  when others  =>
                    (if Each.Shade = Plain then UI.Line_Texts.Regular
                     else UI.Line_Texts.Strong));
            After  : Float := Inner_Left + Inset * Pixels;

            procedure Square (Side : Float; Value : Themes.Color) is
               Size : constant Float := Float'Rounding (Side * Pixels);
            begin
               Fill_Rect
                 (Target, Value, Float'Rounding (After),
                  Float'Rounding (Middle - Size / 2.0), Size, Size);
            end Square;

            procedure Picture (Which : UI.Icons.Icon; Side : Float;
                               Left : Float) is
               Size  : constant Positive :=
                 Positive (Float'Rounding (Side * Pixels));
               Drawn : Boolean;
            begin
               if Icon_Library (Item) /= null then
                  UI.Icons.Draw
                    (Icon_Library (Item).all, Target, Which, Ink,
                     Float'Rounding (Left),
                     Float'Rounding (Middle - Float (Size) / 2.0),
                     Size, Drawn);
               end if;
            end Picture;
         begin
            if Can_Click (Each.Kind) and then Index = Item.Over then
               Fill_Rect
                 (Target,
                  (if Index = Item.Pressed then Colors.Face
                   else Colors.Background),
                  Inner_Left, Top, Inner_Width, High);
            end if;
            case Each.Kind is
               when Separator =>
                  Fill_Rect
                    (Target, Themes.Mix (Colors.Border, Themes.White, 0.4),
                     Inner_Left, Float'Rounding (Middle), Inner_Width, Edge);
               when Check =>
                  declare
                     Side : constant Float :=
                       Float'Rounding (Box_Size * Pixels);
                     Box_Top : constant Float :=
                       Float'Rounding (Middle - Side / 2.0);
                  begin
                     Fill_Rect
                       (Target, Themes.White, Float'Rounding (After), Box_Top,
                        Side, Side);
                     UI.Boxes.Outline
                       (Target,
                        Themes.Mix (Colors.Border, Colors.Foreground, 0.35),
                        Float'Rounding (After), Box_Top, Side, Side, Edge);
                     if Each.Checked then
                        Picture
                          (UI.Icons.Check, Tick_Size,
                           After + (Side - Tick_Size * Pixels) / 2.0);
                     end if;
                     After := After + Side + Gap * Pixels;
                  end;
               when Action =>
                  if Each.Iconed then
                     Picture (Each.Which, Icon_Size, After);
                     After := After + (Icon_Size + Gap) * Pixels;
                  end if;
               when Heading | Note =>
                  null;
            end case;
            if Each.Swatched and then Each.Kind /= Separator then
               Square (Swatch_Size, Each.Swatch);
               After := After + (Swatch_Size + Gap) * Pixels;
            end if;
            if Each.Length > 0 and then Text_Lines (Item) /= null then
               UI.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, Ink,
                  Each.Text (1 .. Each.Length), After, Middle, Pixels,
                  Using);
            end if;
            Top := Top + High;
         end;
      end loop;
   end Draw;

end UI.Widgets.Menus;
