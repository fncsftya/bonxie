with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with SDL3.Events;
with SDL3.Windows.Renderers;
with SDL3.Windows;
with SDL3;
with UI.Text_Areas;
with Texts.Documents;
with Goldens;
with UI.Clipboards;
with UI.Themes;
with UI.Widgets.Buttons;
with UI.Widgets.Editors;
with UI.Widgets.Panels;
with Yoga.Nodes;

package body Widget_Tests is

   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames UI.Widgets;
   package Panels renames UI.Widgets.Panels;
   package Docs renames Texts.Documents;
   package Nodes renames Yoga.Nodes;

   use type Widgets.Widget_Access;

   Colors : constant UI.Themes.Theme := UI.Themes.Light;

   --  A window of a bar of three buttons above a text area, drawn in
   --  software:
   --
   --     Root ─┬─ Bar ─┬─ First, Second, Third
   --           └─ Page

   Density : constant Float := 2.0;
   Width   : constant := 360;
   Height  : constant := 200;
   --  In points.

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Doc    : aliased Docs.Document;
      Board  : UI.Clipboards.Memory_Clipboard;
      Root   : aliased Panels.Panel;
      Bar    : aliased Panels.Panel;
      First  : aliased UI.Widgets.Buttons.Button;
      Second : aliased UI.Widgets.Buttons.Button;
      Third  : aliased UI.Widgets.Buttons.Button;
      Page   : aliased UI.Widgets.Editors.Editor;
      --  after Target and Doc
   end record;

   procedure Open (Item : in out Fixture; Content : String := "Great skua") is
   begin
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Width) * Density),
         Positive (Float (Height) * Density));
      Docs.Load (Item.Doc, Content);
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Clipboard (Item.Tree, Item.Board);

      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Bar);
      Widgets.Add (Item.Bar, Item.First);
      Widgets.Add (Item.Bar, Item.Second);
      Widgets.Add (Item.Bar, Item.Third);
      Widgets.Add (Item.Root, Item.Page);

      Panels.Set_Fill (Item.Bar, (52, 54, 66, 255));
      UI.Widgets.Buttons.Set_Label (Item.First, "One");
      UI.Widgets.Buttons.Set_Label (Item.Second, "Two");
      UI.Widgets.Buttons.Set_Label (Item.Third, "Three");
      UI.Widgets.Editors.Configure
        (Item.Page, "Georgia", Size => 18.0, Measure => 640.0,
         Spacing => 8.0);
      UI.Widgets.Editors.Attach (Item.Page, Item.Doc'Unchecked_Access);
      Widgets.Focus (Item.Page);

      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Column);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Bar), Yoga.Row);
      Nodes.Set_Height (Widgets.Node (Item.Bar), 32.0 * Density);
      Nodes.Set_Padding
        (Widgets.Node (Item.Bar), Yoga.All_Edges, 4.0 * Density);
      Nodes.Set_Gap (Widgets.Node (Item.Bar), Yoga.Column, 4.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.First), 80.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.Second), 80.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.Third), 80.0 * Density);
      Nodes.Set_Flex_Grow (Widgets.Node (Item.Page), 1.0);
      Nodes.Set_Margin (Widgets.Node (Item.Page), Yoga.All_Edges,
                        8.0 * Density);

      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   --  Where, in points, the middle of each button is, and of the text.

   First_At  : constant := 44.0;
   Second_At : constant := 128.0;
   Third_At  : constant := 212.0;
   Bar_Y     : constant := 16.0;
   Gap_At    : constant := 300.0;  --  in the bar, past the buttons
   Page_At   : constant := 100.0;  --  across and down

   --  Reading what is there

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   function Text_Of (Box : Widgets.Pixel_Box) return String is
     (Image (Box.Left) & "," & Image (Box.Top) & " "
      & Image (Box.Width) & "x" & Image (Box.Height));

   function Box_Of (Item : Widgets.Widget'Class) return Widgets.Pixel_Box is
     ((Left   => Integer (Widgets.Left_Of (Item)),
       Top    => Integer (Widgets.Top_Of (Item)),
       Width  => Integer (Widgets.Width_Of (Item)),
       Height => Integer (Widgets.Height_Of (Item))));

   procedure Check_Box
     (Name : String; Expected : String; Item : Widgets.Widget'Class) is
   begin
      Goldens.Check_Text (Name, Expected, Text_Of (Box_Of (Item)));
   end Check_Box;

   procedure Check_Flag (Name : String; Expected, Actual : Boolean) is
   begin
      Goldens.Check_Text (Name, Expected'Image, Actual'Image);
   end Check_Flag;

   --  Events, as SDL would give them, at X, Y points

   function Move (X, Y : Float; Held : Boolean := False) return Events.Event
   is ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y,
        Left_Held => Held, others => <>));

   function Press (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   function Release (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Up, Button => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   procedure Send
     (Item : in out Fixture; Event : Events.Event; Taken : Boolean) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, Event, Handled);
      pragma Assert
        (Handled = Taken, "an event was not taken as it should be");
   end Send;

   function Clicked (Item : in out Fixture; Which : Natural) return Boolean is
      Result : Boolean;
   begin
      case Which is
         when 1 => UI.Widgets.Buttons.Take_Click (Item.First, Result);
         when 2 => UI.Widgets.Buttons.Take_Click (Item.Second, Result);
         when others => UI.Widgets.Buttons.Take_Click (Item.Third, Result);
      end case;
      return Result;
   end Clicked;

   --  Drawing

   procedure Paint (Item : in out Fixture; Keep : Boolean := True) is
   begin
      Widgets.Paint (Item.Tree, Item.Target, Colors, Retained => Keep);
   end Paint;

   procedure Check_Painted
     (Item : in out Fixture; Name : String; Golden : Boolean := True)
   is
      Incremental, Everything : Images.Image;
   begin
      --  What is drawn by drawing what changed is what is drawn by
      --  drawing it all.
      Paint (Item);
      Images.Read (Incremental, Item.Target);
      Widgets.Invalidate_All (Item.Tree);
      Paint (Item);
      Images.Read (Everything, Item.Target);
      Goldens.Check_Same (Name & "-retained", Everything, Incremental);
      if Golden then
         Goldens.Check (Name, Incremental);
      end if;
   end Check_Painted;

   --  The tests

   procedure Layout is
      Item : Fixture;
   begin
      Open (Item);
      Check_Box ("widgets-layout-root", "0,0 720x400", Item.Root);
      Check_Box ("widgets-layout-bar", "0,0 720x64", Item.Bar);
      Check_Box ("widgets-layout-first", "8,8 160x48", Item.First);
      Check_Box ("widgets-layout-second", "176,8 160x48", Item.Second);
      Check_Box ("widgets-layout-third", "344,8 160x48", Item.Third);
      Check_Box ("widgets-layout-page", "16,80 688x304", Item.Page);

      --  Everything was placed, so all is damaged, and the window is to
      --  be drawn.
      Goldens.Check_Text
        ("widgets-layout-damage", "0,0 720x400",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Flag ("widgets-layout-needs-paint", True,
                  Widgets.Needs_Paint (Item.Tree));

      Paint (Item);
      Check_Flag ("widgets-layout-painted", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  Laying out again, with nothing changed, damages nothing.
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-layout-again", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  Restyling moves only what it moves: the buttons after the first
      --  are pushed right, and the bar is not. Damage is where they were
      --  and where they are.
      Nodes.Set_Width (Widgets.Node (Item.First), 100.0 * Density);
      Widgets.Request_Layout (Item.First);
      Check_Flag ("widgets-layout-restyled", True,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-layout-wider", "8,8 200x48", Item.First);
      Check_Box ("widgets-layout-pushed", "216,8 160x48", Item.Second);
      Goldens.Check_Text
        ("widgets-layout-restyled-damage", "8,8 536x48",
         Text_Of (Widgets.Damage (Item.Tree)));
   end Layout;

   procedure Idle is
      Item : Fixture;
   begin
      Open (Item);
      Check_Painted (Item, "widgets-idle");
   end Idle;

   procedure Buttons is
      Item : Fixture;
   begin
      Open (Item);
      Paint (Item);

      --  The pointer over a button changes how only it looks.
      Send (Item, Move (First_At, Bar_Y), Taken => False);
      Check_Flag ("widgets-buttons-hovered", True,
                  Widgets.Is_Hovered (Item.First));
      Check_Flag ("widgets-buttons-bar-hovered", True,
                  Widgets.Is_Hovered (Item.Bar));
      Check_Flag ("widgets-buttons-second-not", False,
                  Widgets.Is_Hovered (Item.Second));
      Goldens.Check_Text
        ("widgets-buttons-hover-damage", "8,8 160x48",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-buttons-hover");

      --  Moving within it changes nothing.
      Send (Item, Move (First_At + 5.0, Bar_Y), Taken => False);
      Check_Flag ("widgets-buttons-moved-within", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  Pressing it, and letting go over it, is a click.
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-buttons-pressed", True,
                  UI.Widgets.Buttons.Is_Pressed (Item.First));
      Check_Painted (Item, "widgets-buttons-pressed");
      Send (Item, Release (First_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-buttons-clicked", True, Clicked (Item, 1));
      Check_Flag ("widgets-buttons-clicked-once", False, Clicked (Item, 1));
      Check_Flag ("widgets-buttons-let-go", False,
                  UI.Widgets.Buttons.Is_Pressed (Item.First));

      --  Pressing it and letting go elsewhere is not. The button still
      --  has the pointer's release, though it is over another.
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Send (Item, Move (Second_At, Bar_Y, Held => True), Taken => False);
      Check_Flag ("widgets-buttons-dragged-off", False,
                  UI.Widgets.Buttons.Is_Pressed (Item.First));
      Check_Flag ("widgets-buttons-dragged-onto", True,
                  Widgets.Is_Hovered (Item.Second));
      Check_Painted (Item, "widgets-buttons-dragged-off", Golden => False);
      Send (Item, Release (Second_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-buttons-not-clicked", False, Clicked (Item, 1));
      Check_Flag ("widgets-buttons-not-clicked-other", False,
                  Clicked (Item, 2));

      --  A press on the bar, which takes nothing, is taken by no one.
      Send (Item, Press (Gap_At, Bar_Y), Taken => True);
      --  (It took the text area's focus away: see Focus.)
      Send (Item, Release (Gap_At, Bar_Y), Taken => False);

      --  The label is changed with the usual care.
      UI.Widgets.Buttons.Set_Label (Item.Third, "Three");
      Check_Flag ("widgets-buttons-same-label", False,
                  Widgets.Needs_Paint (Item.Tree) and then False);
      Paint (Item);
      UI.Widgets.Buttons.Set_Label (Item.Third, "3");
      Goldens.Check_Text
        ("widgets-buttons-label-damage", "344,8 160x48",
         Text_Of (Widgets.Damage (Item.Tree)));
   end Buttons;

   procedure Focus is
      Item : Fixture;
   begin
      Open (Item);
      Check_Flag ("widgets-focus-initial", True,
                  Widgets.Has_Focus (Item.Page));

      --  A click on a button, which takes none, keeps the focus.
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Send (Item, Release (First_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-focus-kept", True, Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-focus-kept-in-editor", True,
                  UI.Widgets.Editors.Is_Focused (Item.Page));

      --  Typing goes to the text area.
      Send (Item, Events.Text_Event ("!"), Taken => True);
      Goldens.Check_Text
        ("widgets-focus-typed", "!Great skua", Docs.Whole (Item.Doc));

      --  A click where nothing takes it takes the focus away, and is
      --  taken; typing then goes nowhere.
      Send (Item, Press (Gap_At, Bar_Y), Taken => True);
      Send (Item, Release (Gap_At, Bar_Y), Taken => False);
      Check_Flag ("widgets-focus-lost", False, Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-focus-lost-in-editor", False,
                  UI.Widgets.Editors.Is_Focused (Item.Page));
      Check_Flag ("widgets-focus-none", True,
                  Widgets.Focus_Of (Item.Tree) = null);
      Send (Item, Events.Text_Event ("?"), Taken => False);
      Goldens.Check_Text
        ("widgets-focus-not-typed", "!Great skua", Docs.Whole (Item.Doc));

      --  A click in the text area gives it back.
      Send (Item, Press (Page_At, Page_At), Taken => True);
      Send (Item, Release (Page_At, Page_At), Taken => False);
      Check_Flag ("widgets-focus-regained", True,
                  Widgets.Has_Focus (Item.Page));

      --  Escape leaves it, and the tree knows.
      Send (Item,
            (Kind => Events.Key_Down, Key => Events.Key_Escape,
             others => <>),
            Taken => True);
      Check_Flag ("widgets-focus-escaped", False,
                  Widgets.Has_Focus (Item.Page));

      --  Keys nobody has the focus for still reach the text area, which
      --  scrolls: a shortcut.
      Send (Item,
            (Kind => Events.Key_Down, Key => Events.Key_Page_Down,
             others => <>),
            Taken => True);
   end Focus;

   procedure Damage is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Paint (Item);

      --  Nothing to do, nothing damaged. The time passing, within a
      --  blink, changes nothing.
      Widgets.Update (Item.Tree, 400);
      Check_Flag ("widgets-damage-quiet", False,
                  Widgets.Needs_Paint (Item.Tree));
      Goldens.Check_Text
        ("widgets-damage-wait", " 100",
         Integer'Image (Widgets.Until_Update (Item.Tree)));

      --  The caret hiding damages around the caret, not the text area.
      Widgets.Update (Item.Tree, 600);
      Check_Flag ("widgets-damage-blink", True,
                  Widgets.Needs_Paint (Item.Tree));
      declare
         Part : constant Widgets.Pixel_Box := Widgets.Damage (Item.Tree);
      begin
         Check_Flag ("widgets-damage-blink-small", True,
                     Part.Width < 40 and then Part.Height < 80);
         Check_Flag ("widgets-damage-blink-in-page", True,
                     Part.Left >= 16 and then Part.Top >= 80);
      end;
      Check_Painted (Item, "widgets-damage-blink-off");
      Widgets.Update (Item.Tree, 1100);
      Check_Painted (Item, "widgets-damage-blink-on", Golden => False);

      --  The document changed by someone else is noticed.
      Docs.Replace
        (Item.Doc, Docs.Text_End (Item.Doc), Docs.Text_End (Item.Doc),
         " and skua");
      Check_Flag ("widgets-damage-unseen", False,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Update (Item.Tree, 1110);
      Goldens.Check_Text
        ("widgets-damage-document", "16,80 688x304",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-damage-edited");

      --  The wheel scrolls it.
      Send (Item,
            (Kind => Events.Mouse_Wheel, Wheel_Y => -2.0,
             Mouse_X => Page_At, Mouse_Y => Page_At, others => <>),
            Taken => True);
      Goldens.Check_Text
        ("widgets-damage-wheel", "16,80 688x304",
         Text_Of (Widgets.Damage (Item.Tree)));

      --  Over the bar it is not taken.
      Paint (Item);
      Send (Item,
            (Kind => Events.Mouse_Wheel, Wheel_Y => -2.0,
             Mouse_X => Gap_At, Mouse_Y => Bar_Y, others => <>),
            Taken => False);
      Check_Flag ("widgets-damage-wheel-bar", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  A panel's colour, set to what it is, damages nothing; changed,
      --  only it.
      Panels.Set_Fill (Item.Bar, (52, 54, 66, 255));
      Check_Flag ("widgets-damage-same-fill", False,
                  Widgets.Needs_Paint (Item.Tree));
      Panels.Set_Fill (Item.Bar, (80, 60, 40, 255));
      Goldens.Check_Text
        ("widgets-damage-fill", "0,0 720x64",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-damage-fill");
   end Damage;

   procedure Retained is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie" & ASCII.LF
            & "Arctic skua");
      Check_Painted (Item, "widgets-retained-start", Golden => False);

      --  A run of things, each drawn by drawing what it changed.
      Send (Item, Move (Second_At, Bar_Y), Taken => False);
      Check_Painted (Item, "widgets-retained-hover", Golden => False);
      Send (Item, Press (Second_At, Bar_Y), Taken => True);
      Check_Painted (Item, "widgets-retained-press", Golden => False);
      Send (Item, Move (Third_At, Bar_Y, Held => True), Taken => False);
      Check_Painted (Item, "widgets-retained-drag", Golden => False);
      Send (Item, Release (Third_At, Bar_Y), Taken => True);
      Check_Painted (Item, "widgets-retained-release", Golden => False);
      Send (Item, Press (Page_At, Page_At), Taken => True);
      Send (Item, Move (Page_At + 60.0, Page_At, Held => True),
            Taken => True);
      Check_Painted (Item, "widgets-retained-select", Golden => True);
      Send (Item, Release (Page_At + 60.0, Page_At), Taken => False);
      Send (Item, Events.Text_Event ("Bonxies"), Taken => True);
      Check_Painted (Item, "widgets-retained-typed", Golden => False);
      Widgets.Update (Item.Tree, 800);
      Check_Painted (Item, "widgets-retained-blink", Golden => False);
      Widgets.Set_Settled (Item.Tree, False);
      Check_Painted (Item, "widgets-retained-unsettled", Golden => False);
      Widgets.Set_Settled (Item.Tree, True);
      UI.Widgets.Editors.Set_Zoom (Item.Page, 2.0);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-retained-zoomed", Golden => True);
   end Retained;

   procedure Resized is
      Item : Fixture;
   begin
      Open (Item);
      Paint (Item);

      --  A target of another size is drawn all, and the widgets are
      --  fitted to it, though nothing said so.
      Renderers.Resize
        (Item.Target,
         Positive (Float (Width - 100) * Density),
         Positive (Float (Height + 40) * Density));
      Check_Painted (Item, "widgets-resized");
      Check_Box ("widgets-resized-page", "16,80 488x384", Item.Page);

      --  Another density puts them all again.
      Widgets.Set_Density (Item.Tree, 3.0);
      Check_Flag ("widgets-resized-density", True,
                  Widgets.Needs_Paint (Item.Tree));
   end Resized;

   procedure Tree_Walk is
      Item : Fixture;
   begin
      Open (Item);
      Goldens.Check_Text
        ("widgets-walk-count", " 2",
         Natural'Image (Widgets.Child_Count (Item.Root)));
      Goldens.Check_Text
        ("widgets-walk-bar", " 3",
         Natural'Image (Widgets.Child_Count (Item.Bar)));
      Check_Flag ("widgets-walk-child", True,
                  Widgets.Child_At (Item.Bar, 2)
                  = Widgets.Widget_Access'(Item.Second'Unchecked_Access));
      Check_Flag ("widgets-walk-parent", True,
                  Widgets.Parent_Of (Item.Page)
                  = Widgets.Widget_Access'(Item.Root'Unchecked_Access));

      --  What is where: the last of the deepest.
      Check_Flag ("widgets-walk-hit-button", True,
                  Widgets.Hit (Item.Tree, 20.0, 20.0)
                  = Widgets.Widget_Access'(Item.First'Unchecked_Access));
      Check_Flag ("widgets-walk-hit-bar", True,
                  Widgets.Hit (Item.Tree, 600.0, 20.0)
                  = Widgets.Widget_Access'(Item.Bar'Unchecked_Access));
      Check_Flag ("widgets-walk-hit-page", True,
                  Widgets.Hit (Item.Tree, 300.0, 300.0)
                  = Widgets.Widget_Access'(Item.Page'Unchecked_Access));
      Check_Flag ("widgets-walk-hit-outside", True,
                  Widgets.Hit (Item.Tree, 800.0, 20.0) = null);
   end Tree_Walk;

   procedure Caret_Only is
      Item : Fixture;
      Text : constant String :=
        "Great skua" & ASCII.LF & "Bonxie" & ASCII.LF & "Arctic skua"
        & ASCII.LF & "Pomarine skua" & ASCII.LF & "Long-tailed skua";
      Before, After : Natural;

      function Drawn return Natural is
        (UI.Text_Areas.Lines_Drawn (UI.Widgets.Editors.Area (Item.Page).all));
   begin
      Open (Item, Text);
      Paint (Item);
      Before := Drawn;
      Check_Flag ("widgets-caret-all-lines", True, Before >= 5);

      --  The caret hiding and showing draws the line it is in, and no
      --  more of the page.
      Widgets.Update (Item.Tree, 600);
      Paint (Item);
      After := Drawn;
      Goldens.Check_Text
        ("widgets-caret-hides", " 1", Natural'Image (After - Before));
      Widgets.Update (Item.Tree, 1100);
      Paint (Item);
      Goldens.Check_Text
        ("widgets-caret-shows", " 1", Natural'Image (Drawn - After));
      Check_Painted (Item, "widgets-caret-same", Golden => False);

      --  Anything else of the text area is drawn as before: its text is.
      Send (Item, Events.Text_Event ("!"), Taken => True);
      Before := Drawn;
      Paint (Item);
      Check_Flag ("widgets-caret-typed-all", True, Drawn - Before >= 5);
   end Caret_Only;

   procedure Hiding is
      Item  : Fixture;
      Start : Images.Image;
      Again : Images.Image;
   begin
      Open (Item);
      Paint (Item);
      Images.Read (Start, Item.Target);

      --  Hidden, a button takes no room: the next moves up to it.
      Widgets.Set_Visible (Item.Second, False);
      Check_Flag ("widgets-hiding-hidden", False,
                  Widgets.Is_Visible (Item.Second));
      Check_Flag ("widgets-hiding-needs-paint", True,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-hiding-first", "8,8 160x48", Item.First);
      Check_Box ("widgets-hiding-second", "0,0 0x0", Item.Second);
      Check_Box ("widgets-hiding-third", "176,8 160x48", Item.Third);
      Goldens.Check_Text
        ("widgets-hiding-damage", "176,8 328x48",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-hiding");

      --  What was there is now what moved up to it.
      Check_Flag ("widgets-hiding-hit", True,
                  Widgets.Hit (Item.Tree, Second_At * Density, Bar_Y * Density)
                  = Widgets.Widget_Access'(Item.Third'Unchecked_Access));
      Send (Item, Press (Second_At, Bar_Y), Taken => True);
      Send (Item, Release (Second_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-hiding-clicked-third", True, Clicked (Item, 3));
      Check_Flag ("widgets-hiding-not-second", False, Clicked (Item, 2));

      --  Shown again, it is as it was, the pointer being off it.
      Send (Item, Move (Gap_At, Bar_Y), Taken => False);
      Widgets.Set_Visible (Item.Second, True);
      Paint (Item);
      Images.Read (Again, Item.Target);
      Goldens.Check_Same ("widgets-hiding-shown", Start, Again);
      Check_Box ("widgets-hiding-shown-second", "176,8 160x48", Item.Second);

      --  Hiding what holds others hides them, whose own settings stay.
      Widgets.Set_Visible (Item.Bar, False);
      Check_Flag ("widgets-hiding-child-visible", True,
                  Widgets.Is_Visible (Item.First));
      Check_Flag ("widgets-hiding-child-shown", False,
                  Widgets.Is_Shown (Item.First));
      Check_Painted (Item, "widgets-hiding-bar", Golden => False);
      Check_Flag ("widgets-hiding-bar-hit", True,
                  Widgets.Hit (Item.Tree, 4.0, 4.0)
                  = Widgets.Widget_Access'(Item.Root'Unchecked_Access));
      Check_Flag ("widgets-hiding-bar-page-up", True,
                  Widgets.Hit (Item.Tree, 20.0, 20.0)
                  = Widgets.Widget_Access'(Item.Page'Unchecked_Access));

      --  A hidden widget has not the focus, and does not wake the loop.
      Check_Flag ("widgets-hiding-focused", True,
                  Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-hiding-wakes", True,
                  Widgets.Until_Update (Item.Tree) >= 0);
      Widgets.Set_Visible (Item.Page, False);
      Check_Flag ("widgets-hiding-lost-focus", False,
                  Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-hiding-no-focus", True,
                  Widgets.Focus_Of (Item.Tree) = null);
      Check_Flag ("widgets-hiding-quiet", True,
                  Widgets.Until_Update (Item.Tree) < 0);
      Send (Item, Events.Text_Event ("?"), Taken => False);
      Goldens.Check_Text
        ("widgets-hiding-not-typed", "Great skua", Docs.Whole (Item.Doc));
      Check_Painted (Item, "widgets-hiding-all", Golden => False);

      Widgets.Set_Visible (Item.Page, True);
      Widgets.Set_Visible (Item.Bar, True);
      Check_Painted (Item, "widgets-hiding-restored", Golden => False);
      Check_Box ("widgets-hiding-restored-page", "16,80 688x304", Item.Page);
   end Hiding;

   procedure Removing is
      Item : Fixture;
   begin
      Open (Item);
      Paint (Item);

      Widgets.Remove (Item.Second);
      Check_Flag ("widgets-removing-attached", False,
                  Widgets.Is_Attached (Item.Second));
      Check_Flag ("widgets-removing-parent", True,
                  Widgets.Parent_Of (Item.Second) = null);
      Goldens.Check_Text
        ("widgets-removing-count", " 2",
         Natural'Image (Widgets.Child_Count (Item.Bar)));
      Check_Flag ("widgets-removing-needs-paint", True,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-removing-third", "176,8 160x48", Item.Third);
      Goldens.Check_Text
        ("widgets-removing-damage", "176,8 328x48",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Flag ("widgets-removing-child", True,
                  Widgets.Child_At (Item.Bar, 2)
                  = Widgets.Widget_Access'(Item.Third'Unchecked_Access));
      Check_Painted (Item, "widgets-removing");

      --  Put back, it is last, and is styled again.
      Widgets.Add (Item.Bar, Item.Second);
      Nodes.Set_Width (Widgets.Node (Item.Second), 80.0 * Density);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-removing-added-third", "176,8 160x48", Item.Third);
      Check_Box ("widgets-removing-added", "344,8 160x48", Item.Second);
      Check_Painted (Item, "widgets-removing-added", Golden => False);

      --  A press, taken by what is removed before it is let go, goes
      --  nowhere, and the pointer is over what it was in.
      Send (Item, Move (First_At, Bar_Y), Taken => False);
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Widgets.Remove (Item.First);
      Check_Flag ("widgets-removing-unhovered", False,
                  Widgets.Is_Hovered (Item.First));
      Check_Flag ("widgets-removing-bar-hovered", True,
                  Widgets.Is_Hovered (Item.Bar));
      Send (Item, Release (First_At, Bar_Y), Taken => False);
      Check_Flag ("widgets-removing-not-clicked", False, Clicked (Item, 1));
      Check_Painted (Item, "widgets-removing-first", Golden => False);

      --  The focus goes with what had it, and so with what it is in.
      Check_Flag ("widgets-removing-focused", True,
                  Widgets.Has_Focus (Item.Page));
      Widgets.Remove (Item.Page);
      Check_Flag ("widgets-removing-no-focus", True,
                  Widgets.Focus_Of (Item.Tree) = null);
      Check_Flag ("widgets-removing-unfocused", False,
                  UI.Widgets.Editors.Is_Focused (Item.Page));
      Check_Painted (Item, "widgets-removing-page", Golden => False);

      --  A whole branch goes, and is not in the tree: nor are its parts.
      Widgets.Remove (Item.Bar);
      Check_Flag ("widgets-removing-branch", False,
                  Widgets.Is_Attached (Item.Third));
      Goldens.Check_Text
        ("widgets-removing-branch-count", " 0",
         Natural'Image (Widgets.Child_Count (Item.Bar)));
      Goldens.Check_Text
        ("widgets-removing-root-count", " 0",
         Natural'Image (Widgets.Child_Count (Item.Root)));
      Check_Painted (Item, "widgets-removing-bare", Golden => False);

      --  And can be built again, below another, and show as before.
      Widgets.Add (Item.Root, Item.Bar);
      Widgets.Add (Item.Bar, Item.Third);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Bar), Yoga.Row);
      Nodes.Set_Height (Widgets.Node (Item.Bar), 32.0 * Density);
      Nodes.Set_Padding
        (Widgets.Node (Item.Bar), Yoga.All_Edges, 4.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.Third), 80.0 * Density);
      Panels.Set_Fill (Item.Bar, (52, 54, 66, 255));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-removing-rebuilt", "8,8 160x48", Item.Third);
      Check_Painted (Item, "widgets-removing-rebuilt");
   end Removing;

   --  A window, to draw in as it keeps the frame: with SDL's dummy video
   --  driver, unless another is asked for, so that it needs no display.

   procedure In_Window;
   --  The body of Window_Frame, which has SDL initialized for it.

   procedure Window_Frame is
   begin
      if not Ada.Environment_Variables.Exists ("SDL_VIDEODRIVER") then
         Ada.Environment_Variables.Set ("SDL_VIDEODRIVER", "dummy");
      end if;
      SDL3.Initialize;
      In_Window;
      --  After the window and its renderer are gone.
      SDL3.Shutdown;
   end Window_Frame;

   procedure In_Window is
      Win    : SDL3.Windows.Window;
      Target : Renderers.Renderer;  --  after Win
      Tree   : Widgets.Tree;
      Root   : aliased Panels.Panel;
      Side   : aliased Panels.Panel;
      Main   : aliased Panels.Panel;
      Incremental, Everything : Images.Image;
      Changed : Boolean;
      Wide, High : Natural;

      procedure Frame is
      begin
         Widgets.Paint (Tree, Target, Colors, Retained => True);
         Renderers.Present (Target);
      end Frame;

      procedure Check_Frame (Name : String) is
      begin
         --  After the frame was presented, what is drawn is still there.
         Images.Read (Incremental, Target);
         Widgets.Invalidate_All (Tree);
         Widgets.Paint (Tree, Target, Colors, Retained => True);
         Images.Read (Everything, Target);
         Goldens.Check_Same (Name, Everything, Incremental);
      end Check_Frame;
   begin
      SDL3.Windows.Create (Win, "test", 360, 200, Resizable => True);
      Renderers.Create (Target, Win, VSync => False);
      Check_Flag ("widgets-window-keeps", True,
                  Renderers.Keeps_Frame (Target));

      Widgets.Set_Density (Tree, SDL3.Windows.Pixel_Density (Win));
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Side);
      Widgets.Add (Root, Main);
      Nodes.Set_Flex_Direction (Widgets.Node (Root), Yoga.Row);
      Nodes.Set_Width (Widgets.Node (Side), 100.0);
      Nodes.Set_Flex_Grow (Widgets.Node (Main), 1.0);
      Panels.Set_Fill (Side, (52, 54, 66, 255));
      Panels.Set_Fill (Main, (200, 120, 40, 255));
      Frame;

      --  A change drawn after the frame went to the window draws only
      --  that, over what the last frame left.
      Panels.Set_Fill (Side, (40, 80, 120, 255));
      Goldens.Check_Text
        ("widgets-window-damage", "0,0 100x200",
         Text_Of (Widgets.Damage (Tree)));
      Frame;
      Check_Frame ("widgets-window-retained");

      --  Not being the size of the window, it is fitted.
      Renderers.Fit (Target, Changed);
      Check_Flag ("widgets-window-fit-same", False, Changed);
      SDL3.Windows.Set_Size (Win, 300, 150);
      Renderers.Fit (Target, Changed);
      Check_Flag ("widgets-window-fit", True, Changed);
      Renderers.Output_Size (Target, Wide, High);
      Goldens.Check_Text
        ("widgets-window-fit-size", "300x150",
         Image (Wide) & "x" & Image (High));
      Frame;
      Check_Frame ("widgets-window-resized");
      Check_Box ("widgets-window-main", "100,0 200x150", Main);
   end In_Window;

end Widget_Tests;
