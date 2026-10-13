with UI.Boxes;

package body UI.Widgets.Toasts is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   --  In points
   Bar_Width    : constant Float := 4.0;
   Pad          : constant Float := 12.0;
   Button_High  : constant Float := 22.0;
   Button_Pad   : constant Float := 10.0;  --  at each side of its label
   Button_Inset : constant Float := 6.0;   --  from the face's right

   procedure Changed_Look (Item : in out Toast);

   procedure Changed_Look (Item : in out Toast) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Message (Item : in out Toast; Text : String) is
   begin
      if Text /= Message (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         Changed_Look (Item);
      end if;
   end Set_Message;

   function Message (Item : Toast) return String is
     (Item.Text (1 .. Item.Length));

   procedure Set_Action (Item : in out Toast; Label : String) is
   begin
      if Label /= Action (Item) then
         Item.Label_Length := Label'Length;
         Item.Label (1 .. Label'Length) := Label;
         Changed_Look (Item);
      end if;
   end Set_Action;

   function Action (Item : Toast) return String is
     (Item.Label (1 .. Item.Label_Length));

   procedure Take_Action (Item : in out Toast; Clicked : out Boolean) is
   begin
      Clicked := Item.Clicked;
      Item.Clicked := False;
   end Take_Action;

   function Face_Width (Item : Toast) return Float is
     (Width_Of (Item) - UI.Boxes.Offset (Density (Item)));

   function Face_Height (Item : Toast) return Float is
     (Height_Of (Item) - UI.Boxes.Offset (Density (Item)));

   procedure Button_Box (Item : Toast; Left, Top, Wide, High : out Float);
   --  Where the button is, with its shadow, in pixels: none if it has no
   --  label.

   procedure Button_Box (Item : Toast; Left, Top, Wide, High : out Float) is
      Pixels : constant Float := Density (Item);
   begin
      Wide := 0.0;
      High := Float'Rounding (Button_High * Pixels);
      if Item.Label_Length > 0 and then Text_Lines (Item) /= null then
         Wide := Float'Rounding
           (UI.Line_Texts.Width
              (Text_Lines (Item).all, Action (Item), Pixels,
               UI.Line_Texts.Strong)
            + (2.0 * Button_Pad + Themes.Raise_Offset) * Pixels);
      end if;
      Left := Float'Rounding
        (Left_Of (Item) + Face_Width (Item) - Button_Inset * Pixels - Wide);
      Top := Float'Rounding
        (Top_Of (Item) + (Face_Height (Item) - High) / 2.0);
   end Button_Box;

   function On_Button (Item : Toast; X, Y : Float) return Boolean is
      Left, Top, Wide, High : Float;
   begin
      Button_Box (Item, Left, Top, Wide, High);
      return Wide > 0.0
        and then X in Left .. Left + Wide and then Y in Top .. Top + High;
   end On_Button;

   overriding procedure Handle
     (Item    : in out Toast;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Over : constant Boolean :=
        On_Button (Item, Event.Mouse_X * Density (Item),
                   Event.Mouse_Y * Density (Item));
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
               Item.Clicked := Over;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Toast; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over then
         Item.Over := False;
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding procedure Draw
     (Item   : in out Toast;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Middle : constant Float := Top_Of (Item) + Face_Height (Item) / 2.0;
      Left, Top, Wide, High : Float;
   begin
      UI.Boxes.Draw
        (Target,
         (Filled   => True,
          Fill     => Themes.White,
          Bordered => True,
          Border   => Colors.Border,
          Dashed   => False,
          Shadowed => True,
          Shadow   => Colors.Drop_Shadow),
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item),
         Pixels);
      Fill_Rect
        (Target, Colors.Primary, Left_Of (Item), Top_Of (Item),
         Float'Rounding (Bar_Width * Pixels), Face_Height (Item));
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         UI.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Colors.Foreground, Message (Item),
            Left_Of (Item) + (Bar_Width + Pad) * Pixels, Middle, Pixels);
      end if;
      Button_Box (Item, Left, Top, Wide, High);
      if Wide > 0.0 then
         declare
            Look : constant UI.Boxes.Raised_Look :=
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
            X, Y, W, H : Float;
         begin
            UI.Boxes.Draw_Raised (Target, Look, Left, Top, Wide, High, Pixels);
            UI.Boxes.Raised_Face
              (Look, Left, Top, Wide, High, Pixels, X, Y, W, H);
            UI.Line_Texts.Draw
              (Text_Lines (Item).all, Target, Colors.Foreground,
               Action (Item), X + Button_Pad * Pixels, Y + H / 2.0, Pixels,
               UI.Line_Texts.Strong);
         end;
      end if;
   end Draw;

end UI.Widgets.Toasts;
