with Pomarine.Widgets.Panels;
with Publish_UI;
with Publish_VM;
with Pomarine.UI.Menus;
with Canvas_VM;
with Home_UI;
with Home_VM;
with Nav_UI;
with Nav_VM;
with Pomarine.UI;
with Pomarine.Boxes;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Editors;
with Items.Windows;
with SDL3.Cursors;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with View.Links;
with View.Style;
with Pomarine.Icons;

package body View.Build.Shell_Views is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Grips renames Pomarine.Widgets.Grips;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Editors renames Pomarine.Widgets.Editors;
   package Selects renames Pomarine.Widgets.Selects;
   package Menus renames Pomarine.Widgets.Menus;
   package Themes renames Pomarine.Themes;
   package UI renames Pomarine.UI;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Build_Header (Item : in out Session) is
   begin
      --  Not shown: the screens leave room for the window's own buttons
      --  (Header_Size above the home screen, Header_Inset at the left of
      --  the toolbar), and its title is the window's.
      Open_Screen (Item, Header_Region);
      declare
         Form : UI.View renames Screen_Of (Item, Header_Region).all;
      begin
         UI.Mount_Into
           (Form,
            Item.Root.Window_Panel,
            UI.Styled
              (UI.Put_In (Form, Item.Root.Header_Panel, [UI.Put (Form, Item.Root.Header_Title)]),
               (Height => Layouts.Length_Of (Header_Size), others => <>)));
      end;
      Widgets.Set_Visible (Item.Root.Header_Panel, False);
   end Build_Header;

   --  The cards of the recent projects: what each says is the view-model's, for its row.

   function Title_Of (Item : Home_VM.View_Model; Row : Positive) return String
   is (if Row <= Home_VM.Count (Item) then Home_VM.Title (Item, Row) else "");
   function Meta_Of (Item : Home_VM.View_Model; Row : Positive) return String
   is (if Row <= Home_VM.Count (Item) then Home_VM.Meta (Item, Row) else "");
   function Is_Listed (Item : Home_VM.View_Model; Row : Positive) return Boolean
   is (Row <= Home_VM.Count (Item));

   function Is_Editing_Row (Item : Home_VM.View_Model; Row : Positive) return Boolean
   is (Home_VM.Editing (Item) = Row);
   function Is_Not_Editing_Row (Item : Home_VM.View_Model; Row : Positive) return Boolean
   is (Home_VM.Editing (Item) /= Row);

   procedure Set_Draft_Of_Row (Item : in out Home_VM.View_Model; Words : String) is
   begin
      --  What is typed in the field of the card, which is the one being renamed.
      if Home_VM.Editing (Item) /= 0 then
         Home_VM.Set_Draft (Item, Words);
      end if;
   end Set_Draft_Of_Row;

   Editing_Flag : constant Home_UI.Flag_Property := Home_UI.Showing (Is_Editing_Row'Access);
   Name_Flag    : constant Home_UI.Flag_Property := Home_UI.Showing (Is_Not_Editing_Row'Access);
   Draft_Text   : constant Home_UI.Text_Property := Home_UI.Editing (Home_VM.Draft'Access, Set_Draft_Of_Row'Access);
   Title_Text   : constant Home_UI.Text_Property := Home_UI.Showing (Title_Of'Access);
   Meta_Text    : constant Home_UI.Text_Property := Home_UI.Showing (Meta_Of'Access);
   Listed_Flag  : constant Home_UI.Flag_Property := Home_UI.Showing (Is_Listed'Access);

   procedure Build_Home (Item : in out Session) is
      Front : Home_Parts renames Item.Home_View;
      Top   : constant Float := (if Item.Shell.Windowed then Header_Size else 0.0);
      --  Clear of the window's own buttons.
   begin
      Open_Screen (Item, Home_Region);
      declare
         Form  : UI.View renames Screen_Of (Item, Home_Region).all;
         Navs  : constant Nav_UI.Context'Class := Nav_UI.Bind (Form, Item.Nav_Model.Model);
         Homes : constant Home_UI.Context'Class := Home_UI.Bind (Form, Item.Home_Model.Model);

         Logo     : constant UI.Label_Handle := Navs.Label ("bonxie", Style => Pomarine.Line_Texts.Display);
         Starting : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("New project",
                 Buttons.Primary,
                 Icon      => Pomarine.Icons.Shown (Icon_Set.Plus),
                 Captioned => True,
                 Focusable => True),
              Nav_VM.Start_Project,
              Reflect => False);
         Settings : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("Settings", Icon => Pomarine.Icons.Shown (Icon_Set.Settings), Captioned => True, Focusable => True),
              Nav_VM.Open_Settings,
              Reflect => False);
         Recent   : constant UI.Label_Handle := Navs.Label ("Recent projects", Style => Pomarine.Line_Texts.Display);
         Scroller : constant UI.Widget_Handle := Navs.Borrow_Widget (Front.Cards_Scroll);

         --  A project: its picture, which is clicked to open it, and below it its name, which is too, and the
         --  buttons to rename and delete it.
         function Card_Of (Number : Positive) return UI.Layout is
            Card    : Project_Card renames Front.Cards (Number);
            Peek    : constant UI.Grip_Handle :=
              Navs.Grip
                ((Fill      => Themes.Border,
                  Radius    => Themes.Large_Radius,
                  Round     => Pomarine.Boxes.Top_Corners,
                  Pointer   => True,
                  Focusable => True,
                  others    => <>),
                 Nav_VM.Open_Project,
                 Number);
            Picture : constant UI.Widget_Handle := Navs.Borrow_Widget (Card.Picture);
            Name    : constant UI.Grip_Handle :=
              Navs.Grip ((Pointer => True, others => <>), Nav_VM.Open_Project, Number);
            Heading : constant UI.Label_Handle :=
              Homes.Label (Title_Text, Number, Style => Pomarine.Line_Texts.Heading);
            Meta    : constant UI.Label_Handle := Homes.Label (Meta_Text, Number);
            Rename  : constant UI.Button_Handle :=
              Homes.Button
                (Buttons.Looks ("Rename", Icon => Pomarine.Icons.Shown (Icon_Set.Edit), Focusable => True),
                 Home_VM.Begin_Rename,
                 Number);
            Delete  : constant UI.Button_Handle :=
              Homes.Button
                (Buttons.Looks
                   ("Delete", Buttons.Danger, Icon => Pomarine.Icons.Shown (Icon_Set.Delete), Focusable => True),
                 Home_VM.Ask_Delete,
                 Number);
            Sized   : constant Layouts.Style := (Width => Card_Button, Height => Card_Button, others => <>);

            --  In place of the name and the buttons, while the project is renamed.
            Field   : constant UI.Field_Handle := Homes.Text_Field (Draft_Text, Home_VM.Accept_Rename);
            Ok      : constant UI.Button_Handle :=
              Homes.Button (Buttons.Looks ("OK", Buttons.Primary, Focusable => True), Home_VM.Accept_Rename);
            Cancel  : constant UI.Button_Handle :=
              Homes.Button (Buttons.Looks ("Cancel", Focusable => True), Home_VM.Cancel_Rename);
            Editing : constant UI.Layout :=
              UI.Styled
                (UI.Row
                   ([UI.Place (Field, Grow => 1.0, Width => 0.0, Height => Card_Button, Exact => True),
                     UI.Place (Ok, Width => Ok_Width, Height => Card_Button, Exact => True),
                     UI.Place (Cancel, Width => Cancel_Width, Height => Card_Button, Exact => True)]),
                 (Flow => Row, Align => Center, Grow => 1.0, Width => 0.0, Gap => Row_Gap, others => <>));

            Naming : constant UI.Layout :=
              UI.Styled
                (UI.Hold
                   (Name,
                    [UI.Place (Heading, Height => Card_Title_Height, Exact => True),
                     UI.Place (Meta, Height => Card_Meta_Height, Exact => True)]),
                 (Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center, Align_Self => Stretch, others => <>));

            Info : constant UI.Layout :=
              UI.Styled
                (UI.Row
                   ([Naming, UI.Styled (UI.Place (Rename), Sized), UI.Styled (UI.Place (Delete), Sized), Editing],
                    Appearance =>
                      (Fill   => Themes.Tint,
                       Radius => Themes.Large_Radius,
                       Round  => Pomarine.Boxes.Bottom_Corners,
                       others => <>)),
                 (Grow    => 1.0,
                  Flow    => Row,
                  Align   => Center,
                  Gap     => Row_Gap,
                  Padding => (Left | Right => Layouts.Length_Of (Card_Pad), others => <>),
                  others  => <>));

            Whole : constant UI.Layout :=
              UI.Styled
                (UI.Column
                   ([UI.Styled
                       (UI.Hold
                          (Peek,
                           [UI.Styled
                              (UI.Place (Picture),
                               (Grow => 1.0, Margin => (Bottom => Hairline, others => <>), others => <>))]),
                        (Height => Thumb_Height, Flow => Column, others => <>)),
                     Info],
                    Appearance =>
                      (Fill   => Themes.Tint,
                       Border => Themes.Border,
                       Shadow => Themes.Shadow,
                       Radius => Themes.Large_Radius,
                       Framed => True,
                       others => <>)),
                 (Flow     => Column,
                  Width    => Layouts.Length_Of (Card_Width),
                  Height   => Layouts.Length_Of (Card_Height),
                  Shrink   => 0.0,
                  Outlined => On,
                  Shadowed => On,
                  others   => <>));
         begin
            Homes.Show_When (Whole, Listed_Flag, Number);
            Homes.Show_When (Naming, Name_Flag, Number);
            Homes.Show_When (UI.Any (Rename), Name_Flag, Number);
            Homes.Show_When (UI.Any (Delete), Name_Flag, Number);
            Homes.Show_When (Editing, Editing_Flag, Number);
            --  Its field has the focus, with its text selected, once it is shown.
            Homes.Focus_When (UI.Focus_Of (Field), Editing_Flag, Number);
            Card.Editing := Editing;
            Card.Field := Field;
            Card.Ok := Ok;
            Card.Cancel := Cancel;
            Card.Panel := Whole;
            Card.Info := Info;
            Card.Peek := Peek;
            Card.Name := Name;
            Card.Rename := Rename;
            return Whole;
         end Card_Of;

         --  The outline of a card, to make a project.
         Plus          : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks ("New", Buttons.Primary, Icon => Pomarine.Icons.Shown (Icon_Set.Plus), Focusable => False),
              Nav_VM.Start_Project,
              Reflect => False);
         Wording       : constant UI.Label_Handle :=
           Navs.Label ("New project", Style => Pomarine.Line_Texts.Strong, Ink => Style.New_Project_Ink);
         Starter       : constant UI.Grip_Handle :=
           Navs.Grip
             ((Border    => Style.Dashed_Edge,
               Dashed    => True,
               Radius    => Themes.Large_Radius,
               Pointer   => True,
               Focusable => True,
               others    => <>),
              Nav_VM.Start_Project,
              Name => "New project");
         Starting_Card : constant UI.Layout :=
           UI.Styled
             (UI.Hold
                (Starter,
                 [UI.Place (Plus, Width => Plus_Size, Height => Plus_Size, Exact => True),
                  UI.Styled
                    (UI.Place (Wording),
                     (Width  => Layouts.Length_Of (Card_Width / 2.0),
                      Height => Title_Height,
                      Margin => (Top => Row_Gap, others => <>),
                      others => <>))]),
              (Width  => Layouts.Length_Of (Card_Width - Themes.Shadow_Offset),
               Height => Layouts.Length_Of (Card_Height - Themes.Shadow_Offset),
               Shrink => 0.0,
               Flow   => Column,
               Spread => Center,
               Align  => Center,
               others => <>));

         Card_Layouts : UI.Layout_Array (1 .. Front.Cards'Length + 1);

         --  The sidebar: the name, New Project, and Settings at the foot.
         Sidebar : constant UI.Layout :=
           UI.Styled
             (UI.Column
                ([UI.Styled
                    (UI.Row ([UI.Place (Logo, Grow => 1.0, Height => Logo_Height, Exact => True)]),
                     (Flow   => Row,
                      Align  => Center,
                      Height => Logo_Height,
                      Margin => (Bottom => Logo_Gap, others => <>),
                      others => <>)),
                  UI.Place (Starting, Height => Action_Height, Exact => True),
                  UI.Styled (UI.Spacer (Form), (Grow => 1.0, others => <>)),
                  UI.Place (Settings, Height => Action_Height, Exact => True)],
                 Appearance => (Fill => (if Item.Shell.Windowed then 0 else Mid_Panel), others => <>)),
              (Flow    => Column,
               Width   => Home_Side_Width,
               Shrink  => 0.0,
               Padding => (Top => Layouts.Length_Of (Side_Pad + Top), others => Layouts.Length_Of (Side_Pad)),
               others  => <>));
      begin
         for Number in Front.Cards'Range loop
            Card_Layouts (Number) := Card_Of (Number);
         end loop;
         Card_Layouts (Card_Layouts'Last) := Starting_Card;
         declare
            --  The cards, in rows that wrap, scrolled; the projects after them, in a column of the title and
            --  them: the title is on the line of the name, as the same height from the same top.
            Cards_Layout    : constant UI.Layout :=
              UI.Styled
                (UI.Hold
                   (Scroller,
                    [UI.Styled
                       (UI.Row (Card_Layouts),
                        (Flow    => Row,
                         Wrap    => On,
                         Align   => Start,
                         Shrink  => 0.0,
                         Gap     => Layouts.Length_Of (Card_Gap),
                         Padding =>
                           (Right  => Layouts.Length_Of (Home_Margin - Card_Gap),
                            Bottom => Layouts.Length_Of (Home_Margin),
                            others => <>),
                         others  => <>))]),
                 (Grow => 1.0, Height => 0.0, others => <>));
            Projects_Column : constant UI.Layout :=
              UI.Styled
                (UI.Column
                   ([UI.Styled
                       (UI.Place (Recent),
                        (Height => Logo_Height, Margin => (Bottom => Logo_Gap, others => <>), others => <>)),
                     Cards_Layout]),
                 (Flow    => Column,
                  Grow    => 1.0,
                  Width   => 0.0,
                  Padding =>
                    (Top => Layouts.Length_Of (Side_Pad + Top), Left => Layouts.Length_Of (Home_Margin), others => <>),
                  others  => <>));

            Home : constant UI.Layout :=
              UI.Styled
                (UI.Row
                   ([Sidebar,
                     UI.Styled
                       (UI.Spacer (Form, (Fill => Themes.Border, others => <>)),
                        (Width => Hairline, Shrink => 0.0, others => <>)),
                     Projects_Column]),
                 (Flow => Row, Grow => 1.0, others => <>));
         begin
            Labels.Set_Centered (UI.Widget_Of (Form, Wording).all, True);
            Front.New_Card := Starter;
            Front.New_Card_Plus := Plus;
            Front.Home_Layout := Home;
            UI.Observe (Form, Item.Layout_Watcher'Access);
            UI.Mount_Into (Form, Item.Root.Window_Panel, Home);
         end;
      end;
      for Card of Front.Cards loop
         Card.Picture.Set_Corners (Themes.Large_Radius, Pomarine.Boxes.Top_Corners);
      end loop;
   end Build_Home;

   function Not_Renaming (Model : Nav_VM.View_Model) return Boolean
   is (not Nav_VM.Is_Renaming (Model));

   Project_Name  : constant Nav_UI.Text_Property :=

       Nav_UI
       .Showing (Nav_VM.Name'Access, Changes => Nav_VM.Name_Version'Access);
   Project_Draft : constant Nav_UI.Text_Property := Nav_UI.Editing (Nav_VM.Draft'Access, Nav_VM.Set_Draft'Access);
   Renaming      : constant Nav_UI.Flag_Property := Nav_UI.Showing (Nav_VM.Is_Renaming'Access);
   Named         : constant Nav_UI.Flag_Property := Nav_UI.Showing (Not_Renaming'Access);

   procedure Build_Project (Item : in out Session) is
      Bar : Toolbar_Parts renames Item.Toolbar;

      function Size (Wide, High : Float) return Layouts.Style
      is (Width => Layouts.Length_Of (Wide), Height => Layouts.Length_Of (High), Shrink => 0.0, others => <>);

      function Side (Along : Spread_Kind) return Layouts.Style
      is (Flow => Row, Align => Center, Spread => Along, Grow => 1.0, Width => 0.0, others => <>);
   begin
      Text_Fields.Set_Shared (Bar.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure (Bar.Title_Field, Pomarine.Line_Texts.Interface_Font, Pomarine.Line_Texts.Heading_Size);
      Text_Fields.Attach (Bar.Title_Field, Bar.Title_Doc'Unchecked_Access);
      Open_Screen (Item, Project_Region);
      declare
         Form : UI.View renames Screen_Of (Item, Project_Region).all;
         Navs : constant Nav_UI.Context'Class := Nav_UI.Bind (Form, Item.Nav_Model.Model);

         function Tab (Words : String; What : Nav_VM.Command) return UI.Button_Handle
         is (Navs.Button (Buttons.Looks (Words, Focusable => True), What));

         Back    : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("Projects",
                 Buttons.Quiet,
                 Icon      => Pomarine.Icons.Shown (Icon_Set.Back),
                 Captioned => True,
                 Focusable => True),
              Nav_VM.Leave_Project);
         Outline : constant UI.Button_Handle := Tab ("Outline", Nav_VM.Show_Outline);
         Canvas  : constant UI.Button_Handle := Tab ("Canvas", Nav_VM.Show_Canvas);
         Write   : constant UI.Button_Handle := Tab ("Write", Nav_VM.Show_Writing);
         Publish : constant UI.Button_Handle := Tab ("Publish", Nav_VM.Show_Publish);
         Listing : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("Items", Icon => Pomarine.Icons.Shown (Icon_Set.List), Captioned => True, Focusable => True),
              Nav_VM.Open_List);
         Caption : constant UI.Label_Handle := Navs.Borrow_Label (Bar.Project_Title, Project_Name);
         Area    : constant UI.Widget_Handle := Navs.Borrow_Widget (Bar.Title_Area);
         Field   : constant UI.Field_Handle := Navs.Borrow_Field (Bar.Title_Field, Bar.Title_Doc, Project_Draft);

         --  The bar across the top: the way back and the project's name at the left, the tabs in the
         --  middle (the sides take equal shares), the list of items at the right.
         Bar_Rule    : constant UI.Layout :=
           UI.Styled
             (UI.Spacer (Form, (Fill => Rule_Ink, others => <>)),
              (Width  => Hairline,
               Height => Bar_Rule_Height,
               Shrink => 0.0,
               Margin => (Left | Right => Name_Gap, others => <>),
               others => <>));
         Name_Area   : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Bar.Title_Area,
                 [UI.Place (Caption, Shrink => 0.0, Height => Layouts.Length_Of (Tab_Height), Exact => True)]),
              (Flow => Row, Align => Center, Shrink => 0.0, Height => Layouts.Length_Of (Tab_Height), others => <>));
         Left_Side   : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([UI.Styled (UI.Place (Back), Size (Back_Width, Tab_Height)),
                  Bar_Rule,
                  Name_Area,
                  UI.Place
                    (Field, Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Tab_Height), Exact => True)]),
              Side (Start));
         Tabs        : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([UI.Styled (UI.Place (Outline), Size (Tab_Width, Tab_Height)),
                  UI.Styled (UI.Place (Canvas), Size (Tab_Width, Tab_Height)),
                  UI.Styled (UI.Place (Write), Size (Tab_Width, Tab_Height)),
                  UI.Styled (UI.Place (Publish), Size (Tab_Width, Tab_Height))]),
              (Flow => Row, Gap => Tab_Gap, others => <>));
         Finish_Side : constant UI.Layout :=
           UI.Styled (UI.Row ([UI.Styled (UI.Place (Listing), Size (Items_Width, Tab_Height))]), Side (Finish));
         Toolbar_Row : constant UI.Layout :=
           UI.Styled
             (UI.Row ([Left_Side, Tabs, Finish_Side], Appearance => (Fill => Toolbar, others => <>)),
              (Height  => Layouts.Length_Of (Toolbar_Size),
               Shrink  => 0.0,
               Flow    => Row,
               Align   => Center,
               Padding =>
                 (Left   => (Layouts.Length_Of (if Item.Shell.Windowed then Header_Inset else Bar_Inset)),
                  Right  => Layouts.Length_Of (Bar_Inset),
                  others => <>),
               others  => <>));
         --  The pages are taller than it: the content takes what the bars leave. Under it, the dock of
         --  minimised items, a row of bars that scrolls across when they are wider than the window.
         Content     : constant UI.Layout :=
           UI.Styled
             (UI.Column ([UI.Styled (UI.Put (Form, Item.Canvas_View), (Grow => 1.0, others => <>))]),
              (Grow => 1.0, Flow => Column, Height => 0.0, others => <>));
         Dock_Row    : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Item.Dock.Dock_Panel,
                 [UI.Styled
                    (UI.Put_In
                       (Form,
                        Item.Dock.Dock_Scroll,
                        [UI.Styled
                           (UI.Put_In (Form, Item.Dock.Dock_Content, []),
                            (Flow    => Row,
                             Shrink  => 0.0,
                             Align   => Center,
                             Gap     => Dock_Gap,
                             Padding => (Left | Right => Dock_Inset, others => <>),
                             others  => <>))]),
                     (Flow => Row, Grow => 1.0, Width => 0.0, others => <>))],
                 Flow => Layouts.Row),
              (Height => Dock_Height, Shrink => 0.0, Flow => Row, others => <>));
         Project     : constant UI.Layout :=
           UI.Styled (UI.Column ([Toolbar_Row, Content, Dock_Row]), (Flow => Column, Grow => 1.0, others => <>));
      begin
         Widgets.Set_Accessible_Name (Bar.Title_Field, "Project name");
         Navs.On_Event (Area, Widgets.Double_Click, Nav_VM.Begin_Rename);
         Navs.On_Event (UI.Any (Field), Widgets.Submit, Nav_VM.Accept_Rename);
         Navs.On_Event (UI.Any (Field), Widgets.Blur, Nav_VM.Accept_Rename);
         Navs.Show_When (UI.Any (Area), Named);
         Navs.Show_When (UI.Any (Field), Renaming);
         Navs.Focus_When (UI.Focus_Of (Field), Renaming);
         UI.Observe (Form, Item.Layout_Watcher'Access);
         Bar.Project_Layout := Project;
         Bar.Content_Layout := Content;
         Bar.Close_Button := Back;
         Bar.Outline_Tab := Outline;
         Bar.Canvas_Tab := Canvas;
         Bar.Write_Tab := Write;
         Bar.Publish_Tab := Publish;
         Item.Dock.Tool_List := Listing;
         UI.Mount_Into (Form, Item.Root.Window_Panel, Project);
      end;
      Labels.Set_Style (Bar.Project_Title, Pomarine.Line_Texts.Heading);
      Labels.Set_Ink (Bar.Project_Title, Themes.Bar_Ink);
      Labels.Set_Intrinsic (Bar.Project_Title);
      Grips.Set_Hover_Outline (Bar.Title_Area, Themes.Rule);
      Grips.Set_Wanted_Cursor (Bar.Title_Area, SDL3.Cursors.Pointer);

      Buttons.Set_Selected (UI.Widget_Of (Screen_Of (Item, Project_Region).all, Bar.Canvas_Tab).all, True);

      --  The dock of minimised items, under the canvas, and the
      --  windows of the items: on the canvas, or as bars in the dock.
      Panels.Set_Fill (Item.Dock.Dock_Panel, Dock);
      Scrollers.Set_Across (Item.Dock.Dock_Scroll, True);
      Links.Build (Item);
   end Build_Project;

   procedure Make_Window (Item : in out Session; Which : Items.Slot) is
   begin
      Items.Windows.Set_Shared (Item.Windows (Which), Item.Host.Doc_Resources'Unchecked_Access);
      Items.Windows.Build
        (Item.Windows (Which),
         Item.Models (Which).Item,
         Canvas_VM.Shown_Camera (Item.Canvas_Model.Model),
         Item.Canvas_View,
         Item.Dock.Dock_Content,
         Toolbar,
         Item.Shell.Density);
   end Make_Window;

   procedure Build_Tray (Item : in out Session) is
      Tray : Dock_Parts renames Item.Dock;
   begin
      Open_Screen (Item, Tray_Region);
      declare
         Form : UI.View renames Screen_Of (Item, Tray_Region).all;
         Navs : constant Nav_UI.Context'Class := Nav_UI.Bind (Form, Item.Nav_Model.Model);

         Document : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("Add document",
                 Icon      => Pomarine.Icons.Shown (Icon_Set.Document),
                 Captioned => True,
                 Focusable => True),
              Nav_VM.Add_Document);
         Source   : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("Add source",
                 Buttons.Primary,
                 Icon      => Pomarine.Icons.Shown (Icon_Set.Link),
                 Captioned => True,
                 Focusable => True),
              Nav_VM.Add_Source);
         Tools    : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([UI.Place
                    (Document,
                     Width  => Layouts.Length_Of (Wide_Tool_Width),
                     Height => Layouts.Length_Of (Tool_Height),
                     Exact  => True),
                  UI.Place
                    (Source,
                     Width  => Layouts.Length_Of (Tool_Width),
                     Height => Layouts.Length_Of (Tool_Height),
                     Exact  => True)],
                 Appearance => (Fill => Toolbar, Shadow => Themes.Shadow, others => <>)),
              (Place    => Absolute,
               Position => (Bottom => Layouts.Length_Of (Tray_Foot - Themes.Shadow_Offset), others => <>),
               Width    => Layouts.Length_Of (Tray_Width),
               Height   => Tray_Height,
               Flow     => Row,
               Align    => Center,
               Padding  => (others => Layouts.Length_Of (Tray_Pad)),
               Shadowed => On,
               Gap      => Layouts.Length_Of (Tray_Gap),
               others   => <>));
      begin
         Tray.Tools := Tools;
         UI.Mount_Into (Form, Content_Panel (Item).all, Tools);
      end;
   end Build_Tray;

   procedure Build_Publish (Item : in out Session) is
      Pane : Publish_Parts renames Item.Publish_View;
   begin
      Buttons.Configure (Pane.Copy, Buttons.Looks ("Copy to Clipboard", Focusable => True));
      Open_Screen (Item, Publish_Region);
      declare
         Form         : UI.View renames Screen_Of (Item, Publish_Region).all;
         Bound        : constant Publish_UI.Controls.Context'Class := Publish_UI.Controls.Bind (Form, Pane.Options);
         Format_Field : constant UI.Widget_Handle := Bound.Borrow_Widget (Pane.Format);
         Format_Menu  : constant UI.Widget_Handle := Bound.Borrow_Widget (Pane.Format_Menu);
         Export       : constant UI.Button_Handle := Bound.Button ("Export", Publish_VM.Export, Focusable => True);
         Copy         : constant UI.Button_Handle := Bound.Borrow_Button (Pane.Copy, Publish_VM.Copy);
         Sections     : constant UI.Switch_Handle :=
           Bound.Switch ("Include section headings", Publish_UI.Sections, Publish_VM.Toggle_Section_Headings);
         Documents    : constant UI.Switch_Handle :=
           Bound.Switch ("Include document headings", Publish_UI.Documents, Publish_VM.Toggle_Document_Headings);

         function Line (Widget : in out Widgets.Widget'Class; Box : Layouts.Style) return UI.Layout
         is (UI.Styled (UI.Put (Form, Widget), Box));

         Sidebar : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Pane.Sidebar,
                 [UI.Styled
                    (UI.Place (Format_Field), (Height => 32.0, Margin => (Bottom => 8.0, others => <>), others => <>)),
                  UI.Place (Sections, Height => 32.0, Exact => True),
                  UI.Place (Documents, Height => 32.0, Exact => True),
                  Line
                    (Pane.Divider,
                     (Height => Hairline,
                      Shrink => 0.0,
                      Margin => (Top => 12.0, Bottom => 12.0, others => <>),
                      others => <>)),
                  UI.Place (Export, Height => Layouts.Length_Of (Tab_Height), Exact => True),
                  UI.Styled
                    (UI.Place (Copy),
                     (Height => Layouts.Length_Of (Tab_Height), Margin => (Top => 8.0, others => <>), others => <>))]),
              (Flow    => Column,
               Width   => Layouts.Length_Of (Item.Page_View.Sidebar_Wide),
               Shrink  => 0.0,
               Padding =>
                 (Top => Layouts.Length_Of (Sidebar_Pad + Heading_Top), others => Layouts.Length_Of (Sidebar_Pad)),
               others  => <>));

         --  The sheets: the source (Source_Text) at the left of the page as it is rendered, which is shown
         --  only when the format is text.
         Source_Sheet : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Pane.Source_Scroll,
                 [UI.Styled
                    (UI.Put_In
                       (Form,
                        Pane.Source_Content,
                        [Line
                           (Pane.Source_Text,
                            (Shrink => 0.0,
                             Height => Layouts.Length_Of (Page_Min_Height),
                             Width  => Layouts.Length_Of (Page_Width),
                             others => <>))]),
                     (Flow    => Column,
                      Shrink  => 0.0,
                      Align   => Start,
                      Padding => (Left => Layouts.Length_Of (Page_Inset), others => Layouts.Length_Of (Page_Margin)),
                      others  => <>))]),
              (Grow => 1.0, Width => 0.0, others => <>));
         Sheet        : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Pane.Scroll,
                 [UI.Styled
                    (UI.Put_In
                       (Form,
                        Pane.Content,
                        [Line
                           (Pane.Text,
                            (Shrink => 0.0,
                             Height => Layouts.Length_Of (Page_Min_Height),
                             Width  => Layouts.Length_Of (Page_Width),
                             others => <>))]),
                     (Flow    => Column,
                      Shrink  => 0.0,
                      Align   => Start,
                      Padding => (Left => Layouts.Length_Of (Page_Inset), others => Layouts.Length_Of (Page_Margin)),
                      others  => <>))]),
              (Grow => 1.0, Width => 0.0, others => <>));

         Whole : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Pane.View,
                 [Sidebar,
                  Line (Pane.Rule, (Width => Hairline, Shrink => 0.0, others => <>)),
                  Source_Sheet,
                  Line (Pane.Split_Rule, (Width => Hairline, Shrink => 0.0, others => <>)),
                  Sheet,
                  UI.Styled
                    (UI.Place (Format_Menu),
                     (Place => Absolute, Width => Layouts.Length_Of (Menu_Width), others => <>))],
                 Flow => Layouts.Row),
              (Flow => Row, Grow => 1.0, Height => 0.0, others => <>));
      begin
         Bound.Caption_From (Copy, Publish_UI.Copy_Caption);
         Bound.On_Event (Format_Field, Widgets.Click, Publish_VM.Toggle_Format);
         Bound.On_Event (Format_Menu, Widgets.Choose, Publish_VM.Choose_Format, Index_From_Event => True);
         UI.Mount_Into (Form, Content_Panel (Item).all, Whole);
         UI.Observe (Form, Item.Publish_Watcher'Access);
      end;
      Panels.Set_Fill (Pane.Split_Rule, Themes.Border);
      Selects.Set_Value (Pane.Format, "Choose a format");
      Widgets.Set_Accessible_Name (Pane.Format, "Publish format");
      Widgets.Set_Visible (Pane.Format_Menu, False);
      Pomarine.UI.Menus.Set_Content
        (Pane.Format_Menu,
         [for Place in 1 .. Publish_VM.Formats'Pos (Publish_VM.Formats'Last) + 1 =>
            Pomarine.UI.Menus.Row (Menus.Check, Publish_VM.Label (Publish_VM.Formats'Val (Place - 1)))]);
      Panels.Set_Fill (Pane.Divider, Themes.Border);
      if not Item.Shell.Windowed then
         Panels.Set_Fill (Pane.View, Desk);
      end if;
      Panels.Set_Fill (Pane.Sidebar, Side_Fill);
      Panels.Set_Fill (Pane.Rule, Themes.Border);
      Editors.Set_Shared (Pane.Source_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure (Pane.Source_Text, "Menlo", Source_Text_Size, 2000.0, Spacing => 0.35 * Source_Text_Size);
      Editors.Set_Paper (Pane.Source_Text, Paper);
      Editors.Set_Borderless (Pane.Source_Text, True);
      Editors.Set_Indent (Pane.Source_Text, Page_Margin - Page_Text_Inset - Page_Border);
      Editors.Attach (Pane.Source_Text, Pane.Source_Doc'Unchecked_Access);
      Pomarine.Text_Areas.Set_Grows (Editors.Area (Pane.Source_Text).all);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Pane.Source_Text).all);
      Pomarine.Text_Areas.Set_Caret_Visible (Editors.Area (Pane.Source_Text).all, False);
      Pomarine.Text_Areas.Set_Keyboard_Navigation (Editors.Area (Pane.Source_Text).all, False);
      Pane.Source_Wide := Page_Width;
      Pane.Source_High := Page_Min_Height;
      Widgets.Set_Visible (Pane.Source_Scroll, False);
      Widgets.Set_Visible (Pane.Split_Rule, False);
      Editors.Set_Shared (Pane.Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (Pane.Text, Pomarine.Line_Texts.Serif, Page_Text_Size, 2000.0, Spacing => 0.35 * Page_Text_Size);
      Editors.Set_Paper (Pane.Text, Paper);
      Editors.Set_Borderless (Pane.Text, True);
      Editors.Set_Indent (Pane.Text, Page_Margin - Page_Text_Inset - Page_Border);
      Editors.Attach (Pane.Text, Pane.Doc'Unchecked_Access);
      Pomarine.Text_Areas.Set_Grows (Editors.Area (Pane.Text).all);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Pane.Text).all);
      Pomarine.Text_Areas.Set_Caret_Visible (Editors.Area (Pane.Text).all, False);
      Pomarine.Text_Areas.Set_Keyboard_Navigation (Editors.Area (Pane.Text).all, False);
      Pane.Wide := Page_Width;
      Pane.High := Page_Min_Height;
      Widgets.Set_Visible (Pane.View, False);
   end Build_Publish;

end View.Build.Shell_Views;
