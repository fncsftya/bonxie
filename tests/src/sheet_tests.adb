with SDL3.Events;
with SDL3.Windows.Renderers;
with Texts.Documents;
with Goldens;
with UI.Clipboards;
with UI.Icons;
with UI.Line_Texts;
with UI.Text_Areas;
with UI.Themes;
with UI.Widgets.Badges;
with UI.Widgets.Buttons;
with UI.Widgets.Checks;
with UI.Widgets.Chips;
with UI.Widgets.Labels;
with UI.Widgets.Menus;
with UI.Widgets.Panels;
with UI.Widgets.Scrollers;
with UI.Widgets.Selects;
with UI.Widgets.Sliders;
with UI.Widgets.Switches;
with UI.Widgets.Text_Fields;
with UI.Widgets.Toasts;
with UI.Widgets.Tooltips;
with Yoga.Nodes;

package body Sheet_Tests is

   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames UI.Widgets;
   package Panels renames UI.Widgets.Panels;
   package Buttons renames UI.Widgets.Buttons;
   package Checks renames UI.Widgets.Checks;
   package Labels renames UI.Widgets.Labels;
   package Menus renames UI.Widgets.Menus;
   package Docs renames Texts.Documents;
   package Nodes renames Yoga.Nodes;

   Colors : constant UI.Themes.Theme := UI.Themes.Light;

   Density : constant Float := 2.0;

   type Icon_List is array (Positive range <>) of UI.Icons.Icon;

   Bare_Icons : constant Icon_List :=
     [UI.Icons.Edit, UI.Icons.Plus, UI.Icons.Delete, UI.Icons.Microphone,
      UI.Icons.Close];
   Tool_Icons : constant Icon_List :=
     [UI.Icons.Cursor, UI.Icons.Highlighter, UI.Icons.Eraser];

   --  Building

   type Base is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Lines  : aliased UI.Line_Texts.Drawer;
      Icons  : aliased UI.Icons.Library;
      Board  : UI.Clipboards.Memory_Clipboard;
      Root   : aliased Panels.Panel;
      --  after Target
   end record;

   procedure Open (Item : in out Base; Wide, High : Positive) is
   begin
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Wide) * Density), Positive (Float (High) * Density));
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Clipboard (Item.Tree, Item.Board);
      Widgets.Set_Line_Texts (Item.Tree, Item.Lines);
      UI.Icons.Set_Directory (Item.Icons, "../share/bonxie/icons");
      Widgets.Set_Icons (Item.Tree, Item.Icons);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Panels.Set_Fill (Item.Root, Colors.Background);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Column);
      Nodes.Set_Padding
        (Widgets.Node (Item.Root), Yoga.All_Edges, 20.0 * Density);
      Nodes.Set_Gap (Widgets.Node (Item.Root), Yoga.All_Gutters,
                     14.0 * Density);
   end Open;

   procedure Row (Parent : in out Widgets.Widget'Class;
                  Part   : in out Panels.Panel;
                  High   : Float) is
   begin
      Widgets.Add (Parent, Part);
      Nodes.Set_Flex_Direction (Widgets.Node (Part), Yoga.Row);
      Nodes.Set_Align_Items (Widgets.Node (Part), Yoga.Center);
      Nodes.Set_Gap (Widgets.Node (Part), Yoga.All_Gutters, 12.0 * Density);
      Nodes.Set_Height (Widgets.Node (Part), High * Density);
   end Row;

   procedure Put (Parent : in out Widgets.Widget'Class;
                  Part   : in out Widgets.Widget'Class;
                  Wide, High : Float) is
   begin
      Widgets.Add (Parent, Part);
      Nodes.Set_Width (Widgets.Node (Part), Wide * Density);
      Nodes.Set_Height (Widgets.Node (Part), High * Density);
      Nodes.Set_Flex_Shrink (Widgets.Node (Part), 0.0);
   end Put;

   procedure Button
     (Parent : in out Widgets.Widget'Class;
      Part   : in out Buttons.Button;
      Label  : String;
      Wide   : Float;
      Kind   : Buttons.Kind := Buttons.Normal;
      High   : Float := 30.0) is
   begin
      Put (Parent, Part, Wide, High);
      Buttons.Set_Label (Part, Label);
      Buttons.Set_Kind (Part, Kind);
   end Button;

   procedure Iconed
     (Part : in out Buttons.Button; Which : UI.Icons.Icon;
      Captioned : Boolean := True) is
   begin
      Buttons.Set_Icon (Part, Which);
      Buttons.Set_Icon_Size (Part, 13.0);
      Buttons.Set_Captioned (Part, Captioned);
   end Iconed;

   procedure Field
     (Parent : in out Widgets.Widget'Class;
      Part   : in out UI.Widgets.Text_Fields.Text_Field;
      Doc    : aliased in out Docs.Document;
      Text   : String;
      Wide   : Float) is
   begin
      Docs.Load (Doc, Text);
      UI.Widgets.Text_Fields.Configure
        (Part, UI.Line_Texts.Interface_Font, 13.0);
      UI.Widgets.Text_Fields.Attach (Part, Doc'Unchecked_Access);
      Put (Parent, Part, Wide, 30.0);
   end Field;

   procedure Check_Painted
     (Tree : in out Widgets.Tree; Target : Renderers.Renderer;
      Name : String)
   is
      Drawn : Images.Image;
   begin
      Widgets.Paint (Tree, Target, Colors);
      Images.Read (Drawn, Target);
      Goldens.Check (Name, Drawn);
   end Check_Painted;

   --  Events, at X, Y points

   function Move (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>));

   function Press (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   function Release (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Up, Button => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   function Key (Code : Events.Key_Code) return Events.Event is
     ((Kind => Events.Key_Down, Key => Code, others => <>));

   procedure Send (Tree : in out Widgets.Tree; Event : Events.Event) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Tree, Event, Handled);
   end Send;

   function Middle_X (Part : Widgets.Widget'Class) return Float is
     ((Widgets.Left_Of (Part) + Widgets.Width_Of (Part) / 2.0) / Density);

   function Middle_Y (Part : Widgets.Widget'Class) return Float is
     ((Widgets.Top_Of (Part) + Widgets.Height_Of (Part) / 2.0) / Density);

   procedure Click (Tree : in out Widgets.Tree; X, Y : Float) is
   begin
      Send (Tree, Move (X, Y));
      Send (Tree, Press (X, Y));
      Send (Tree, Release (X, Y));
   end Click;

   procedure Click_On
     (Tree : in out Widgets.Tree; Part : Widgets.Widget'Class) is
   begin
      Click (Tree, Middle_X (Part), Middle_Y (Part));
   end Click_On;

   procedure Check_Flag (Name : String; Expected, Actual : Boolean) is
   begin
      Goldens.Check_Text (Name, Expected'Image, Actual'Image);
   end Check_Flag;

   --  The board

   type Button_Array is array (Positive range <>) of Buttons.Button;
   type Check_Array is array (Positive range <>) of Checks.Check;
   type Field_Array is array (Positive range <>) of
     UI.Widgets.Text_Fields.Text_Field;
   type Doc_Array is array (Positive range <>) of aliased Docs.Document;
   type Panel_Array is array (Positive range <>) of Panels.Panel;
   type Label_Array is array (Positive range <>) of Labels.Label;

   type Board_Fixture is limited record
      Docs_Of  : Doc_Array (1 .. 6);
      Common   : Base;
      Rows     : Panel_Array (1 .. 9);
      Names    : Label_Array (1 .. 9);
      Kinds    : Button_Array (1 .. 6);
      Icons_Only : Button_Array (1 .. 5);
      Sizes    : Button_Array (1 .. 3);
      Toggles  : Button_Array (1 .. 2);
      Drops    : Button_Array (1 .. 3);
      Choice   : UI.Widgets.Selects.Select_Field;
      Modes    : Button_Array (1 .. 2);
      Tools    : Button_Array (1 .. 3);
      Boxes    : Check_Array (1 .. 5);
      Flips    : UI.Widgets.Switches.Switch;
      Flips_On : UI.Widgets.Switches.Switch;
      Slide    : UI.Widgets.Sliders.Slider;
      Fields   : Field_Array (1 .. 5);
      Add      : Buttons.Button;
      Chip_A   : UI.Widgets.Chips.Chip;
      Chip_B   : UI.Widgets.Chips.Chip;
      Count    : UI.Widgets.Badges.Badge;
      Tag      : UI.Widgets.Badges.Badge;
      Tip      : UI.Widgets.Tooltips.Tooltip;
      Toast    : UI.Widgets.Toasts.Toast;
      Drop_Menu : Menus.Menu;
      Context  : Menus.Menu;
      Scroll   : UI.Widgets.Scrollers.Scroller;
      Long     : Panels.Panel;
   end record;

   procedure Build (Item : in out Board_Fixture) is
      Common : Base renames Item.Common;

      procedure Named (Index : Positive; Name : String; High : Float) is
      begin
         Row (Common.Root, Item.Rows (Index), High);
         Put (Item.Rows (Index), Item.Names (Index), 70.0, High);
         Labels.Set_Text (Item.Names (Index), Name);
         Labels.Set_Style (Item.Names (Index), UI.Line_Texts.Caption);
      end Named;
   begin
      Open (Common, 960, 450);

      --  Buttons of each kind, and turned off.
      Named (1, "BUTTONS", 34.0);
      Button (Item.Rows (1), Item.Kinds (1), "Add source", 104.0,
              Buttons.Primary);
      Iconed (Item.Kinds (1), UI.Icons.Link);
      Button (Item.Rows (1), Item.Kinds (2), "Add document", 120.0);
      Iconed (Item.Kinds (2), UI.Icons.Document);
      Button (Item.Rows (1), Item.Kinds (3), "Delete", 84.0, Buttons.Danger);
      Iconed (Item.Kinds (3), UI.Icons.Delete);
      Button (Item.Rows (1), Item.Kinds (4), "Add source", 104.0,
              Buttons.Primary);
      Iconed (Item.Kinds (4), UI.Icons.Link);
      Button (Item.Rows (1), Item.Kinds (5), "Add document", 120.0);
      Iconed (Item.Kinds (5), UI.Icons.Document);
      Button (Item.Rows (1), Item.Kinds (6), "Delete", 84.0, Buttons.Danger);
      Iconed (Item.Kinds (6), UI.Icons.Delete);
      for Index in 4 .. 6 loop
         Buttons.Set_Enabled (Item.Kinds (Index), False);
      end loop;

      --  Icons only, sizes, toggles.
      Named (2, "MORE", 40.0);
      for Index in Item.Icons_Only'Range loop
         declare
            Which : constant UI.Icons.Icon := Bare_Icons (Index);
            Side  : constant Float := (if Index <= 3 then 28.0 else 20.0);
         begin
            Button (Item.Rows (2), Item.Icons_Only (Index), "x", Side,
                    (case Index is
                        when 2 => Buttons.Primary,
                        when 3 => Buttons.Danger,
                        when others => Buttons.Normal),
                    High => Side);
            Buttons.Set_Icon (Item.Icons_Only (Index), Which);
            Buttons.Set_Icon_Size
              (Item.Icons_Only (Index), (if Index <= 3 then 13.0 else 11.0));
         end;
      end loop;
      Button (Item.Rows (2), Item.Sizes (1), "Small", 52.0, High => 22.0);
      Button (Item.Rows (2), Item.Sizes (2), "Default", 70.0);
      Button (Item.Rows (2), Item.Sizes (3), "Large", 76.0, High => 38.0);
      for Index in Item.Toggles'Range loop
         Button (Item.Rows (2), Item.Toggles (Index), "Highlight", 96.0);
         Iconed (Item.Toggles (Index), UI.Icons.Highlighter);
      end loop;
      Buttons.Set_Selected (Item.Toggles (2), True);

      --  Dropdowns, a select field, a mode switch and a tool group.
      Named (3, "DROPDOWNS", 30.0);
      for Index in Item.Drops'Range loop
         Button (Item.Rows (3), Item.Drops (Index), "Sources", 112.0,
                 High => 28.0);
         Buttons.Set_Dropdown (Item.Drops (Index), True);
         Buttons.Set_Badge (Item.Drops (Index), (if Index = 2 then 0 else 2));
      end loop;
      Buttons.Set_Enabled (Item.Drops (2), False);
      Buttons.Set_Selected (Item.Drops (3), True);
      Put (Item.Rows (3), Item.Choice, 170.0, 28.0);
      UI.Widgets.Selects.Set_Value (Item.Choice, "Last opened");
      Button (Item.Rows (3), Item.Modes (1), "Canvas", 64.0, High => 26.0);
      Button (Item.Rows (3), Item.Modes (2), "Write", 64.0, High => 26.0);
      Buttons.Set_Selected (Item.Modes (1), True);
      for Index in Item.Tools'Range loop
         Button (Item.Rows (3), Item.Tools (Index), "t", 20.0, High => 21.0);
         Buttons.Set_Icon (Item.Tools (Index), Tool_Icons (Index));
         Buttons.Set_Icon_Size (Item.Tools (Index), 11.0);
      end loop;
      Buttons.Set_Selected (Item.Tools (2), True);

      --  Boxes, radios, switches, a slider.
      Named (4, "SELECTION", 24.0);
      for Index in Item.Boxes'Range loop
         Put (Item.Rows (4), Item.Boxes (Index), 92.0, 20.0);
         Checks.Set_Kind
           (Item.Boxes (Index), (if Index <= 3 then Checks.Box
                                 else Checks.Radio));
         Checks.Set_Label
           (Item.Boxes (Index),
            (case Index is
                when 1 => "Off", when 2 => "On", when 3 => "Disabled",
                when 4 => "Selected", when others => "Unselected"));
      end loop;
      Checks.Set_Checked (Item.Boxes (2), True);
      Checks.Set_Enabled (Item.Boxes (3), False);
      Checks.Set_Checked (Item.Boxes (4), True);
      Put (Item.Rows (4), Item.Flips, 70.0, 20.0);
      UI.Widgets.Switches.Set_Label (Item.Flips, "Off");
      Put (Item.Rows (4), Item.Flips_On, 70.0, 20.0);
      UI.Widgets.Switches.Set_Label (Item.Flips_On, "On");
      UI.Widgets.Switches.Set_On (Item.Flips_On, True);
      Put (Item.Rows (4), Item.Slide, 120.0, 16.0);
      UI.Widgets.Sliders.Set_Value (Item.Slide, 0.55);

      --  Fields: at rest, focused, invalid with a hint, turned off, and
      --  the address of a source with an icon, a hint and its button.
      Named (5, "INPUTS", 30.0);
      Field (Item.Rows (5), Item.Fields (1), Item.Docs_Of (1),
             "First project", 130.0);
      Field (Item.Rows (5), Item.Fields (2), Item.Docs_Of (2),
             "First project", 130.0);
      Field (Item.Rows (5), Item.Fields (3), Item.Docs_Of (3), "", 110.0);
      UI.Widgets.Text_Fields.Set_Placeholder (Item.Fields (3), "Untitled");
      UI.Widgets.Text_Fields.Set_Invalid (Item.Fields (3), True);
      Field (Item.Rows (5), Item.Fields (4), Item.Docs_Of (4),
             "First project", 110.0);
      UI.Widgets.Text_Fields.Set_Enabled (Item.Fields (4), False);
      Field (Item.Rows (5), Item.Fields (5), Item.Docs_Of (5), "", 150.0);
      UI.Text_Areas.Set_Single_Line
        (UI.Widgets.Text_Fields.Area (Item.Fields (5)).all);
      UI.Widgets.Text_Fields.Set_Icon (Item.Fields (5), UI.Icons.Link);
      UI.Widgets.Text_Fields.Set_Placeholder (Item.Fields (5), "https://");
      Button (Item.Rows (5), Item.Add, "Add", 48.0, Buttons.Primary);
      Nodes.Set_Margin (Widgets.Node (Item.Add), Yoga.Left, -10.0 * Density);

      --  Chips, a count, a tag, a tooltip, a toast.
      Named (6, "CHIPS", 36.0);
      Put (Item.Rows (6), Item.Chip_A, 136.0, 22.0);
      UI.Widgets.Chips.Set_Label (Item.Chip_A, "Codeless Code");
      UI.Widgets.Chips.Set_Swatch (Item.Chip_A, Colors.Primary);
      Put (Item.Rows (6), Item.Chip_B, 104.0, 22.0);
      UI.Widgets.Chips.Set_Label (Item.Chip_B, "Ten steps");
      UI.Widgets.Chips.Set_Swatch (Item.Chip_B, Colors.Focus);
      Put (Item.Rows (6), Item.Count, 16.0, 16.0);
      UI.Widgets.Badges.Set_Count (Item.Count, 2);
      Put (Item.Rows (6), Item.Tag, 120.0, 18.0);
      UI.Widgets.Badges.Set_Kind (Item.Tag, UI.Widgets.Badges.Tag);
      UI.Widgets.Badges.Set_Text (Item.Tag, "Captured 13 Oct 2026");
      Nodes.Set_Width
        (Widgets.Node (Item.Tag),
         Float'Rounding
           (UI.Widgets.Badges.Natural_Width (Item.Tag) * Density));
      Put (Item.Rows (6), Item.Tip, 70.0, UI.Widgets.Tooltips.Height);
      UI.Widgets.Tooltips.Set_Text (Item.Tip, "Highlight");
      Nodes.Set_Width
        (Widgets.Node (Item.Tip),
         Float'Rounding
           (UI.Widgets.Tooltips.Natural_Width (Item.Tip) * Density));
      Put (Item.Rows (6), Item.Toast, 200.0, UI.Widgets.Toasts.Height);
      UI.Widgets.Toasts.Set_Message (Item.Toast, "Highlight saved");
      UI.Widgets.Toasts.Set_Action (Item.Toast, "Undo");

      --  Menus, and a list that scrolls.
      Named (7, "MENUS", 150.0);
      Nodes.Set_Align_Items (Widgets.Node (Item.Rows (7)), Yoga.Flex_Start);
      Put (Item.Rows (7), Item.Drop_Menu, 240.0, 10.0);
      Menus.Add (Item.Drop_Menu, Menus.Heading, "LINKED TO INTRO");
      Menus.Add (Item.Drop_Menu, Menus.Check, "Ten steps towards happiness",
                 Checked => True);
      Menus.Set_Swatch (Item.Drop_Menu, 2, Colors.Focus);
      Menus.Add (Item.Drop_Menu, Menus.Check, "Codeless Code");
      Menus.Set_Swatch (Item.Drop_Menu, 3, Colors.Primary);
      Menus.Add (Item.Drop_Menu, Menus.Separator);
      Menus.Add (Item.Drop_Menu, Menus.Action, "Add source", Menus.Primary);
      Menus.Set_Icon (Item.Drop_Menu, 5, UI.Icons.Plus);
      Put (Item.Rows (7), Item.Context, 140.0, 10.0);
      Menus.Add (Item.Context, Menus.Action, "Open");
      Menus.Set_Icon (Item.Context, 1, UI.Icons.Document);
      Menus.Add (Item.Context, Menus.Action, "Rename");
      Menus.Set_Icon (Item.Context, 2, UI.Icons.Edit);
      Menus.Add (Item.Context, Menus.Separator);
      Menus.Add (Item.Context, Menus.Action, "Delete", Menus.Danger);
      Menus.Set_Icon (Item.Context, 4, UI.Icons.Delete);
      Put (Item.Rows (7), Item.Scroll, 110.0, 120.0);
      Widgets.Add (Item.Scroll, Item.Long);
      Panels.Set_Fill (Item.Long, UI.Themes.White);
      Nodes.Set_Height (Widgets.Node (Item.Long), 360.0 * Density);
      Nodes.Set_Flex_Shrink (Widgets.Node (Item.Long), 0.0);

      Widgets.Layout (Common.Tree, Common.Target);
      Widgets.Focus (Item.Fields (2));
   end Build;

   procedure Board is
      Item : Board_Fixture;
   begin
      Build (Item);
      --  The pointer over the list, to show its bar.
      Send (Item.Common.Tree,
            Move (Middle_X (Item.Scroll), Middle_Y (Item.Scroll)));
      Check_Painted (Item.Common.Tree, Item.Common.Target, "sheet-board");
   end Board;

   procedure States is
      Item : Board_Fixture;
   begin
      Build (Item);
      --  Under the pointer: a row of a menu, then a button; then a button
      --  pressed, and one with the focus.
      Buttons.Set_Focusable (Item.Kinds (2), True);
      Widgets.Focus (Item.Kinds (2));
      Send (Item.Common.Tree,
            Move (Middle_X (Item.Context),
                  Widgets.Top_Of (Item.Context) / Density + 44.0));
      Check_Painted
        (Item.Common.Tree, Item.Common.Target, "sheet-states-menu-hover");
      Send (Item.Common.Tree,
            Move (Middle_X (Item.Kinds (1)), Middle_Y (Item.Kinds (1))));
      Check_Painted
        (Item.Common.Tree, Item.Common.Target, "sheet-states-hover");
      Send (Item.Common.Tree,
            Move (Middle_X (Item.Kinds (3)), Middle_Y (Item.Kinds (3))));
      Send (Item.Common.Tree,
            Press (Middle_X (Item.Kinds (3)), Middle_Y (Item.Kinds (3))));
      Check_Painted
        (Item.Common.Tree, Item.Common.Target, "sheet-states-pressed");
   end States;

   procedure Behaviour is
      Item : Board_Fixture;
      Tree : Widgets.Tree renames Item.Common.Tree;
      Clicked, Changed : Boolean;
      Chosen : Natural;
   begin
      Build (Item);

      --  A button turned off takes no click.
      Click_On (Tree, Item.Kinds (4));
      Buttons.Take_Click (Item.Kinds (4), Clicked);
      Check_Flag ("sheet-disabled-click", False, Clicked);
      Click_On (Tree, Item.Kinds (1));
      Buttons.Take_Click (Item.Kinds (1), Clicked);
      Check_Flag ("sheet-enabled-click", True, Clicked);

      --  A button that takes the focus is clicked by Return and Space,
      --  but not by keys while it does not have it.
      Send (Tree, Key (Events.Key_Return));
      Buttons.Take_Click (Item.Kinds (2), Clicked);
      Check_Flag ("sheet-key-unfocused", False, Clicked);
      Buttons.Set_Focusable (Item.Kinds (2), True);
      Click_On (Tree, Item.Kinds (2));
      Buttons.Take_Click (Item.Kinds (2), Clicked);
      Check_Flag ("sheet-focus-click", True, Clicked);
      Check_Flag ("sheet-focus-taken", True,
                  Widgets.Has_Focus (Item.Kinds (2)));
      Send (Tree, Key (Events.Key_Return));
      Buttons.Take_Click (Item.Kinds (2), Clicked);
      Check_Flag ("sheet-key-return", True, Clicked);
      Send (Tree, Key (Events.Key_Space));
      Buttons.Take_Click (Item.Kinds (2), Clicked);
      Check_Flag ("sheet-key-space", True, Clicked);
      Buttons.Set_Enabled (Item.Kinds (2), False);
      Check_Flag ("sheet-focus-lost", False,
                  Widgets.Has_Focus (Item.Kinds (2)));

      --  A box turns over; a radio is only chosen; one turned off stays.
      Click_On (Tree, Item.Boxes (1));
      Checks.Take_Change (Item.Boxes (1), Changed);
      Check_Flag ("sheet-box-changed", True, Changed);
      Check_Flag ("sheet-box-ticked", True,
                  Checks.Is_Checked (Item.Boxes (1)));
      Click_On (Tree, Item.Boxes (2));
      Check_Flag ("sheet-box-unticked", False,
                  Checks.Is_Checked (Item.Boxes (2)));
      Click_On (Tree, Item.Boxes (3));
      Checks.Take_Change (Item.Boxes (3), Changed);
      Check_Flag ("sheet-box-disabled", False, Changed);
      Click_On (Tree, Item.Boxes (4));
      Checks.Take_Change (Item.Boxes (4), Changed);
      Check_Flag ("sheet-radio-stays", False, Changed);
      Click_On (Tree, Item.Boxes (5));
      Checks.Take_Change (Item.Boxes (5), Changed);
      Check_Flag ("sheet-radio-chosen", True,
                  Changed and then Checks.Is_Checked (Item.Boxes (5)));

      --  A switch turns over.
      Click_On (Tree, Item.Flips);
      UI.Widgets.Switches.Take_Change (Item.Flips, Changed);
      Check_Flag ("sheet-switch", True,
                  Changed and then UI.Widgets.Switches.Is_On (Item.Flips));

      --  A select field is clicked, as a button is.
      Click_On (Tree, Item.Choice);
      UI.Widgets.Selects.Take_Click (Item.Choice, Clicked);
      Check_Flag ("sheet-select", True, Clicked);

      --  A menu's rows: a heading and a line are not to choose.
      Click (Tree, Middle_X (Item.Drop_Menu),
             Widgets.Top_Of (Item.Drop_Menu) / Density + 10.0);
      Menus.Take_Choice (Item.Drop_Menu, Chosen);
      Goldens.Check_Text ("sheet-menu-heading", "0", Chosen'Image (2 .. 2));
      Click (Tree, Middle_X (Item.Drop_Menu),
             Widgets.Top_Of (Item.Drop_Menu) / Density + 4.0 + 24.0 + 26.0
             + 13.0);
      Menus.Take_Choice (Item.Drop_Menu, Chosen);
      Goldens.Check_Text ("sheet-menu-check", "3", Chosen'Image (2 .. 2));
      Goldens.Check_Text
        ("sheet-menu-height", "122",
         Natural'Image (Natural (Menus.Height_For (Item.Drop_Menu))) (2 .. 4));

      --  A chip's cross, and a toast's button.
      Click (Tree,
             (Widgets.Left_Of (Item.Chip_A) + Widgets.Width_Of (Item.Chip_A))
             / Density - 10.0,
             Middle_Y (Item.Chip_A));
      UI.Widgets.Chips.Take_Close (Item.Chip_A, Clicked);
      Check_Flag ("sheet-chip-close", True, Clicked);
      Click_On (Tree, Item.Chip_B);
      UI.Widgets.Chips.Take_Close (Item.Chip_B, Clicked);
      Check_Flag ("sheet-chip-label", False, Clicked);
      Click (Tree,
             (Widgets.Left_Of (Item.Toast) + Widgets.Width_Of (Item.Toast))
             / Density - 24.0,
             Middle_Y (Item.Toast) - 1.0);
      UI.Widgets.Toasts.Take_Action (Item.Toast, Clicked);
      Check_Flag ("sheet-toast-action", True, Clicked);

      --  The arrows of a scroll bar scroll a step.
      Send (Tree, Move (Middle_X (Item.Scroll), Middle_Y (Item.Scroll)));
      Click (Tree,
             (Widgets.Left_Of (Item.Scroll) + Widgets.Width_Of (Item.Scroll))
             / Density - 6.0,
             (Widgets.Top_Of (Item.Scroll) + Widgets.Height_Of (Item.Scroll))
             / Density - 6.0);
      Goldens.Check_Text
        ("sheet-scroll-arrow", "15",
         Natural'Image
           (Natural (UI.Widgets.Scrollers.Offset (Item.Scroll))) (2 .. 3));
   end Behaviour;

end Sheet_Tests;
