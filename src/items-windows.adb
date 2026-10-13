with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with SDL3.Cursors;
with UI.Boxes;
with UI.Text_Areas;
with UI.Icons;
with UI.Line_Texts;
with Yoga.Nodes;

package body Items.Windows is

   package Widgets renames UI.Widgets;
   package Panels renames UI.Widgets.Panels;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;
   package Grips renames UI.Widgets.Grips;
   package Editors renames UI.Widgets.Editors;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Sliders renames UI.Widgets.Sliders;

   use type Docs.Version;
   use type Ada.Calendar.Time;
   use type SDL3.Events.Milliseconds;

   pragma Assert (Items.Max_Marks = UI.Widgets.Pictures.Max_Marks);

   --  In points

   Outline       : constant Float := 1.0;
   Bar_Height    : constant Float := 28.0;
   Bar_Pad       : constant Float := 6.0;
   Button_Size   : constant Float := 18.0;
   Bar_Icon_Size : constant Float := 11.0;
   Tag_Size      : constant Float := 9.0;
   Tag_Gap       : constant Float := 7.0;
   --  The square of a source's colour before its title, and after it.
   Button_Gap    : constant Float := 4.0;
   Drag_Room     : constant Float := 32.0;
   --  Left of the title field before the buttons, to take hold of.
   Title_Size    : constant Float := 12.0;
   Title_Height  : constant Float := 20.0;
   Text_Size     : constant Float := 15.0;
   Link_Size     : constant Float := 12.0;
   --  Of the text of a note, in the serif, and of the link of a source.
   Measure       : constant Float := 2000.0;
   Status_Height : constant Float := 26.0;
   Status_Pad    : constant Float := 10.0;
   Corner_Size   : constant Float := 18.0;
   Mini_Width    : constant Float := 200.0;
   Mini_Height   : constant Float := 28.0;
   Mini_Gap      : constant Float := 4.0;
   Mini_Chars    : constant := 16;
   --  How many characters of a title the bar in the dock shows.
   Zoom_Row_Height : constant Float := 19.0;
   Zoom_Button_Width : constant Float := 44.0;
   Zoom_Slider_Width : constant Float := 56.0;
   Progress_Height   : constant Float := 3.0;
   Preset_Width  : constant Float := 44.0;
   Speak_Icon_Size : constant Float := 12.0;
   Level_Steps   : constant Float := 20.0;
   --  How many sizes of the bar that shows how loud the speech is.
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;
   Label_Height  : constant Float := 20.0;

   Preset_Zooms : constant array (Preset_Index) of Float :=
     [0.5, 0.75, 1.0, 1.5, 2.0, 3.0];
   --  The menu's, in two rows of three.
   Url_Height    : constant Float := 30.0;
   Fetch_Width   : constant Float := 40.0;
   Fetch_Height  : constant Float := 22.0;
   Fetch_Inset   : constant Float := 4.0;
   --  The button to take the picture of a link, at the right of it.
   Compact_Below : constant Float := 0.75;
   --  Under this zoom a window shows only what it says: no status line,
   --  and a source no link.
   Min_Chrome    : constant Float := 0.6;
   --  How small the bar of a window gets, as a part of its size, when
   --  zoomed out, so that its title is not large over the text.

   function Count_Words (Of_Text : String) return Natural is
      Total  : Natural := 0;
      Inside : Boolean := False;
   begin
      for C of Of_Text loop
         if C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Inside := False;
         elsif not Inside then
            Inside := True;
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Count_Words;

   function Shortened (Title : String) return String is
     (if Title'Length <= Mini_Chars then Title
      else Title (Title'First .. Title'First + Mini_Chars - 1) & "..");
   --  For the bar in the dock.

   function Status_Text (Number : Natural) return String is
     (Ada.Strings.Fixed.Trim (Number'Image, Ada.Strings.Both)
      & (if Number = 1 then " word" else " words"));

   function Day (Taken : Projects.Seconds) return String is
      Image : constant String :=
        Ada.Calendar.Formatting.Image
          (Ada.Calendar.Formatting.Time_Of (1970, 1, 1, Time_Zone => 0)
           + Duration (Taken),
           Time_Zone => 0);
      Months : constant array (1 .. 12) of String (1 .. 3) :=
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      Date  : constant Positive := Positive'Value (Image (9 .. 10));
   begin
      return Ada.Strings.Fixed.Trim (Date'Image, Ada.Strings.Both) & " "
        & Months (Positive'Value (Image (6 .. 7))) & " " & Image (1 .. 4);
   end Day;
   --  As 13 Oct 2026, in UTC.

   function Fitted (Message : String) return String is
     (Message (Message'First ..
               Message'First - 1
               + Natural'Min (Message'Length, Labels.Text_Capacity)));
   --  As much as a label takes.

   procedure Build
     (Item    : in out Window;
      Canvas  : in out Widgets.Widget'Class;
      Dock    : in out Widgets.Widget'Class;
      Colors  : UI.Themes.Theme;
      Bar     : UI.Themes.Color;
      Density : Float)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Density;
      Edge   : constant Float :=
        Float'Max (1.0, Float'Rounding (Outline * Pixels));
      --  Whole pixels: a border that is not is a pixel more or less where
      --  it is drawn, or none.

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;
   begin
      Item.Pixels := Pixels;
      Widgets.Add (Canvas, Item.Frame);
      Widgets.Add (Item.Frame, Item.Title_Bar);
      Widgets.Add (Item.Title_Bar, Item.Title_Area);
      Widgets.Add (Item.Title_Area, Item.Tag);
      Widgets.Add (Item.Title_Area, Item.Title_Label);
      Widgets.Add (Item.Title_Bar, Item.Title_Field);
      Widgets.Add (Item.Title_Bar, Item.Spacer);
      Widgets.Add (Item.Title_Bar, Item.Minimize_Button);
      Widgets.Add (Item.Title_Bar, Item.Close_Button);
      Widgets.Add (Item.Frame, Item.Body_Text);
      Widgets.Add (Item.Frame, Item.Picture);
      Widgets.Add (Item.Frame, Item.Status_Bar);
      Widgets.Add (Item.Status_Bar, Item.Status);
      Widgets.Add (Item.Status_Bar, Item.Tools);
      Widgets.Add (Item.Tools, Item.Cursor_Button);
      Widgets.Add (Item.Tools, Item.Marker_Button);
      Widgets.Add (Item.Tools, Item.Eraser_Button);
      Widgets.Add (Item.Status_Bar, Item.Speak_Button);
      Widgets.Add (Item.Status_Bar, Item.Zoom_Slider);
      Widgets.Add (Item.Status_Bar, Item.Zoom_Button);
      Widgets.Add (Item.Status_Bar, Item.Corner);
      Widgets.Add (Item.Status_Bar, Item.Progress);
      Widgets.Add (Dock, Item.Mini);
      Widgets.Add (Item.Mini, Item.Mini_Area);
      Widgets.Add (Item.Mini_Area, Item.Mini_Title);
      Widgets.Add (Item.Mini, Item.Mini_Close);

      --  The window: an outline round a column of the bar, the text and
      --  the status line, placed by its edges on the canvas.
      --  Its outline is its fill, round what is in it; its shadow is
      --  inside its box, at the right and the foot.
      Item.Ring_Ink := Colors.Accent;
      Panels.Set_Fill (Item.Frame, Colors.Border);
      Panels.Set_Shadow (Item.Frame, Colors.Shadow);
      Set_Position_Type (Widgets.Node (Item.Frame), Yoga.Absolute);
      Set_Flex_Direction (Widgets.Node (Item.Frame), Yoga.Column);
      Set_Padding (Widgets.Node (Item.Frame), Yoga.Left, Edge);
      Set_Padding (Widgets.Node (Item.Frame), Yoga.Top, Edge);
      Set_Padding
        (Widgets.Node (Item.Frame), Yoga.Right,
         Edge + UI.Boxes.Offset (Pixels));
      Set_Padding
        (Widgets.Node (Item.Frame), Yoga.Bottom,
         Edge + UI.Boxes.Offset (Pixels));

      Grips.Set_Fill (Item.Title_Bar, Bar);
      Set_Height (Widgets.Node (Item.Title_Bar), Bar_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Title_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Title_Bar), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Title_Bar), Yoga.Horizontal, Bar_Pad * Pixels);
      Set_Gap
        (Widgets.Node (Item.Title_Bar), Yoga.All_Gutters,
         Button_Gap * Pixels);
      Text_Fields.Configure
        (Item.Title_Field, UI.Line_Texts.Interface_Font, Title_Size);
      Set_Flex_Grow (Widgets.Node (Item.Title_Field), 1.0);
      Set_Width (Widgets.Node (Item.Title_Field), 0.0);
      Set_Height (Widgets.Node (Item.Title_Field), Title_Height * Pixels);
      Set_Margin
        (Widgets.Node (Item.Title_Field), Yoga.Right, Drag_Room * Pixels);
      --  The title is text, in the field's place, until it is to be
      --  edited.
      Grips.Set_Hover_Outline (Item.Title_Area, Colors.Background);
      Set_Flex_Grow (Widgets.Node (Item.Title_Area), 1.0);
      Set_Width (Widgets.Node (Item.Title_Area), 0.0);
      Set_Height (Widgets.Node (Item.Title_Area), Title_Height * Pixels);
      Set_Margin
        (Widgets.Node (Item.Title_Area), Yoga.Right, Drag_Room * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Title_Area), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Title_Area), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Title_Area), Yoga.Left, Bar_Pad * Pixels);
      Panels.Set_Fill (Item.Tag, Colors.Bar);
      Size (Item.Tag, Tag_Size, Tag_Size);
      Set_Flex_Shrink (Widgets.Node (Item.Tag), 0.0);
      Set_Margin (Widgets.Node (Item.Tag), Yoga.Right, Tag_Gap * Pixels);
      Labels.Set_Style (Item.Title_Label, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Title_Label, UI.Themes.White);
      Set_Flex_Grow (Widgets.Node (Item.Title_Label), 1.0);
      Set_Width (Widgets.Node (Item.Title_Label), 0.0);
      Set_Height (Widgets.Node (Item.Title_Label), Label_Height * Pixels);
      --  Nothing: the bar is held there.
      Set_Width (Widgets.Node (Item.Spacer), 0.0);
      Buttons.Set_Label (Item.Minimize_Button, "Min");
      Buttons.Set_Icon (Item.Minimize_Button, UI.Icons.Minimize);
      Buttons.Set_Label (Item.Close_Button, "Close");
      Buttons.Set_Icon (Item.Close_Button, UI.Icons.Close);
      Buttons.Set_Icon_Size (Item.Minimize_Button, Bar_Icon_Size);
      Buttons.Set_Icon_Size (Item.Close_Button, Bar_Icon_Size);
      Size (Item.Minimize_Button, Button_Size, Button_Size);
      Size (Item.Close_Button, Button_Size, Button_Size);

      Editors.Configure
        (Item.Body_Text, UI.Line_Texts.Serif, Text_Size, Measure);
      Editors.Set_Paper (Item.Body_Text, (255, 255, 255, 255));
      Set_Flex_Grow (Widgets.Node (Item.Body_Text), 1.0);
      --  Its own outline is the window's at the sides.
      Set_Margin
        (Widgets.Node (Item.Body_Text), Yoga.Horizontal, -Edge);
      Set_Height (Widgets.Node (Item.Body_Text), 0.0);

      Set_Flex_Grow (Widgets.Node (Item.Picture), 1.0);
      Set_Height (Widgets.Node (Item.Picture), 0.0);

      --  Its outline over the window's at the sides and the foot, a line
      --  between it and what is above.
      Panels.Set_Fill (Item.Status_Bar, Colors.Tint);
      Panels.Set_Border (Item.Status_Bar, Colors.Border);
      Set_Margin (Widgets.Node (Item.Status_Bar), Yoga.Horizontal, -Edge);
      Set_Margin (Widgets.Node (Item.Status_Bar), Yoga.Bottom, -Edge);
      Set_Height (Widgets.Node (Item.Status_Bar), Status_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Status_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Status_Bar), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Status_Bar), Yoga.Left, Status_Pad * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Status), 1.0);
      Set_Width (Widgets.Node (Item.Status), 0.0);
      Set_Height (Widgets.Node (Item.Status), Label_Height * Pixels);
      Grips.Set_Shape (Item.Corner, Grips.Corner);
      Grips.Set_Wanted_Cursor (Item.Corner, SDL3.Cursors.Resize);
      Size (Item.Corner, Corner_Size, Status_Height);
      Widgets.Add (Item.Frame, Item.Zoom_Menu);
      Widgets.Add (Item.Frame, Item.Fetch_Button);
      for Row in Item.Menu_Rows'Range loop
         Widgets.Add (Item.Zoom_Menu, Item.Menu_Rows (Row));
      end loop;
      for Which in Item.Menu_Buttons'Range loop
         Widgets.Add (Item.Menu_Rows (1 + (Which - 1) / 3),
                      Item.Menu_Buttons (Which));
      end loop;

      --  The bar in the dock.
      Panels.Set_Fill (Item.Mini, Bar);
      Size (Item.Mini, Mini_Width, Mini_Height);
      Set_Flex_Direction (Widgets.Node (Item.Mini), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Mini), Yoga.Center);
      Set_Padding (Widgets.Node (Item.Mini), Yoga.Right, Mini_Gap * Pixels);
      Set_Gap (Widgets.Node (Item.Mini), Yoga.All_Gutters, Mini_Gap * Pixels);
      --  The whole title is to click, to bring the window back.
      Grips.Set_Hover_Outline (Item.Mini_Area, Colors.Background);
      Grips.Set_Wanted_Cursor (Item.Mini_Area, SDL3.Cursors.Pointer);
      Set_Flex_Grow (Widgets.Node (Item.Mini_Area), 1.0);
      Set_Width (Widgets.Node (Item.Mini_Area), 0.0);
      Set_Height (Widgets.Node (Item.Mini_Area), Mini_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Mini_Area), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Mini_Area), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Mini_Area), Yoga.Left, Bar_Pad * Pixels);
      Labels.Set_Style (Item.Mini_Title, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Mini_Title, UI.Themes.White);
      Set_Flex_Grow (Widgets.Node (Item.Mini_Title), 1.0);
      Set_Width (Widgets.Node (Item.Mini_Title), 0.0);
      Set_Height (Widgets.Node (Item.Mini_Title), Label_Height * Pixels);
      Buttons.Set_Label (Item.Mini_Close, "Close");
      Buttons.Set_Icon (Item.Mini_Close, UI.Icons.Close);
      Buttons.Set_Icon_Size (Item.Mini_Close, Bar_Icon_Size);
      Size (Item.Mini_Close, Button_Size, Button_Size);

      --  The progress bar, along the foot of the status line.
      Set_Position_Type (Widgets.Node (Item.Progress), Yoga.Absolute);
      Set_Position (Widgets.Node (Item.Progress), Yoga.Left, 0.0);
      Set_Position (Widgets.Node (Item.Progress), Yoga.Right, 0.0);
      Set_Position (Widgets.Node (Item.Progress), Yoga.Bottom, 0.0);
      Set_Height
        (Widgets.Node (Item.Progress), Progress_Height * Pixels);

      --  The tools, in the middle of the status line (see Place).
      Set_Position_Type (Widgets.Node (Item.Tools), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Tools), Yoga.Top,
         (Status_Height - Zoom_Row_Height) / 2.0 * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Tools), Yoga.Row);
      Set_Gap
        (Widgets.Node (Item.Tools), Yoga.All_Gutters, Button_Gap * Pixels);
      Buttons.Set_Label (Item.Cursor_Button, "Ptr");
      Buttons.Set_Icon (Item.Cursor_Button, UI.Icons.Cursor);
      Buttons.Set_Label (Item.Marker_Button, "Mark");
      Buttons.Set_Icon (Item.Marker_Button, UI.Icons.Highlighter);
      Buttons.Set_Label (Item.Eraser_Button, "Rub");
      Buttons.Set_Icon (Item.Eraser_Button, UI.Icons.Eraser);
      Buttons.Set_Selected (Item.Cursor_Button, True);
      Size (Item.Eraser_Button, Button_Size, Zoom_Row_Height);
      Size (Item.Cursor_Button, Button_Size, Zoom_Row_Height);
      Size (Item.Marker_Button, Button_Size, Zoom_Row_Height);

      --  The zoom bar: a slider, and the button for the menu.
      Set_Gap
        (Widgets.Node (Item.Status_Bar), Yoga.All_Gutters,
         Button_Gap * Pixels);
      Set_Width (Widgets.Node (Item.Zoom_Slider), Zoom_Slider_Width * Pixels);
      Set_Height (Widgets.Node (Item.Zoom_Slider), Zoom_Row_Height * Pixels);
      Buttons.Set_Label (Item.Zoom_Button, "100%");
      Size (Item.Zoom_Button, Zoom_Button_Width, Zoom_Row_Height);

      --  The button to dictate, of a note.
      Buttons.Set_Label (Item.Speak_Button, "Mic");
      Buttons.Set_Icon (Item.Speak_Button, UI.Icons.Microphone);
      Size (Item.Speak_Button, Button_Size, Zoom_Row_Height);
      Buttons.Set_Icon_Size (Item.Speak_Button, Speak_Icon_Size);
      --  In the middle of the status line, as the tools are (see Place).
      Set_Position_Type (Widgets.Node (Item.Speak_Button), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Speak_Button), Yoga.Top,
         (Status_Height - Zoom_Row_Height) / 2.0 * Pixels);

      --  The menu: over the picture, at the right, with the window's
      --  outline between its buttons.
      Panels.Set_Fill (Item.Zoom_Menu, Colors.Border);
      Set_Position_Type (Widgets.Node (Item.Zoom_Menu), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Zoom_Menu), Yoga.Right,
         (Corner_Size + Edge) * Pixels);
      Set_Position
        (Widgets.Node (Item.Zoom_Menu), Yoga.Bottom,
         (Status_Height + Edge) * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Zoom_Menu), Yoga.Column);
      Set_Padding (Widgets.Node (Item.Zoom_Menu), Yoga.All_Edges, Edge);
      Set_Gap (Widgets.Node (Item.Zoom_Menu), Yoga.All_Gutters, Edge);
      for Row of Item.Menu_Rows loop
         Set_Flex_Direction (Widgets.Node (Row), Yoga.Row);
         Set_Gap (Widgets.Node (Row), Yoga.All_Gutters, Edge);
      end loop;
      for Which in Item.Menu_Buttons'Range loop
         Buttons.Set_Label
           (Item.Menu_Buttons (Which), Percent (Preset_Zooms (Which)));
         Size (Item.Menu_Buttons (Which), Preset_Width, Zoom_Row_Height);
      end loop;

      --  Over the right of the link, which leaves room for it (see
      --  Show_Fetch); its top is put by Fit_Zoom.
      Buttons.Set_Label (Item.Fetch_Button, "Add");
      Buttons.Set_Kind (Item.Fetch_Button, Buttons.Primary);
      Size (Item.Fetch_Button, Fetch_Width, Fetch_Height);
      Set_Position_Type (Widgets.Node (Item.Fetch_Button), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Fetch_Button), Yoga.Right,
         Edge + UI.Boxes.Offset (Pixels) + Fetch_Inset * Pixels);

      Widgets.Set_Visible (Item.Title_Field, False);
      Widgets.Set_Visible (Item.Fetch_Button, False);
      Widgets.Set_Visible (Item.Tools, False);
      Widgets.Set_Visible (Item.Zoom_Slider, False);
      Widgets.Set_Visible (Item.Zoom_Button, False);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Picture, False);
      Widgets.Set_Visible (Item.Progress, False);
      Widgets.Set_Visible (Item.Frame, False);
      Widgets.Set_Visible (Item.Mini, False);
   end Build;

   function Is_Assigned (Item : Window) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Window; To : UI.Themes.Color) is
   begin
      Panels.Set_Fill (Item.Tag, To);
   end Set_Tag;

   function Details (Item : Window) return Items.Info is (Item.Details);

   function Text (Item : Window) return String is
     (Docs.Whole (Item.Content_Doc));

   function Words (Item : Window) return Natural is (Item.Word_Count);

   function Title_Document
     (Item : in out Window) return Texts.Documents.Document_Access is
     (Item.Title_Doc'Unchecked_Access);

   function Content_Document
     (Item : in out Window) return Texts.Documents.Document_Access is
     (Item.Content_Doc'Unchecked_Access);

   procedure Hold_Typing (Item : in out Window; To : Boolean) is
   begin
      Item.Held := To;
   end Hold_Typing;

   function Marks_Version (Item : Window) return Natural is
     (UI.Widgets.Pictures.Marks_Version (Item.Picture));

   function Is_Marking (Item : Window) return Boolean is
     (UI.Widgets.Pictures.Is_Marking (Item.Picture));

   procedure Get_Marks (Item : Window; Into : out Items.Mark_List) is
   begin
      Into.Count := UI.Widgets.Pictures.Mark_Count (Item.Picture);
      for Index in 1 .. Into.Count loop
         declare
            Each : constant UI.Widgets.Pictures.Mark :=
              UI.Widgets.Pictures.Mark_At (Item.Picture, Index);
         begin
            Into.Marks (Index) :=
              (Left => Each.Left, Right => Each.Right, Y => Each.Y);
         end;
      end loop;
   end Get_Marks;

   function Status (Item : Window) return String is
     (Labels.Text (Item.Status));

   function Tool (Item : Window) return UI.Widgets.Pictures.Tools is
     (UI.Widgets.Pictures.Tool (Item.Picture));

   function Mark_Count (Item : Window) return Natural is
     (UI.Widgets.Pictures.Mark_Count (Item.Picture));

   procedure Select_Tool
     (Item : in out Window; To : UI.Widgets.Pictures.Tools) is
   begin
      UI.Widgets.Pictures.Set_Tool (Item.Picture, To);
      Buttons.Set_Selected
        (Item.Cursor_Button, To = UI.Widgets.Pictures.Pointer);
      Buttons.Set_Selected
        (Item.Marker_Button, To = UI.Widgets.Pictures.Highlighter);
      Buttons.Set_Selected
        (Item.Eraser_Button, To = UI.Widgets.Pictures.Eraser);
   end Select_Tool;

   function Unit (Value : Float) return Float is
     (Float'Min (1.0, Float'Max (0.0, Value)));
   --  Within the picture.

   procedure Set_Marks (Item : in out Window; Kept : Items.Mark_List) is
      Shown : UI.Widgets.Pictures.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Mark renames Kept.Marks (Index);
         begin
            Shown (Index) :=
              (Left  => Unit (Each.Left),
               Right => Float'Max (Unit (Each.Left), Unit (Each.Right)),
               Y     => Unit (Each.Y));
         end;
      end loop;
      UI.Widgets.Pictures.Set_Marks (Item.Picture, Shown);
      Item.Marks_Saved := UI.Widgets.Pictures.Marks_Version (Item.Picture);
   end Set_Marks;

   procedure Set_Recognized
     (Item : in out Window; Found : Vision.Result) is
   begin
      Item.Recognized := Found;
      UI.Widgets.Pictures.Set_Words
        (Item.Picture, Item.Recognized'Unchecked_Access);
   end Set_Recognized;

   procedure Clear_Recognized (Item : in out Window);
   --  Forget the words, as of a picture that is not the one shown.

   procedure Clear_Recognized (Item : in out Window) is
   begin
      UI.Widgets.Pictures.Set_Words (Item.Picture, null);
      Item.Recognized.Count := 0;
      Item.Recognized.Length := 0;
      Item.Recognized.Truncated := False;
   end Clear_Recognized;

   function Recognized_Count (Item : Window) return Natural is
     (Item.Recognized.Count);

   function Selected_Text (Item : Window) return String is
     (UI.Widgets.Pictures.Selected_Text (Item.Picture));

   procedure Set_Title_Text (Item : in out Window; To : String) is
   begin
      Docs.Replace
        (Item.Title_Doc, (Paragraph => 1, Index => 1),
         Docs.Text_End (Item.Title_Doc), To);
      --  Poll shows it, as it does what is typed.
   end Set_Title_Text;

   procedure Set_Progress (Item : in out Window; To : Float) is
   begin
      UI.Widgets.Progress_Bars.Set_Value (Item.Progress, To);
   end Set_Progress;

   procedure Show_Fetch (Item : in out Window);
   --  Show the button to take the picture of a source's link, and leave
   --  room for it, while there is none and the link is shown.

   procedure Show_Fetch (Item : in out Window) is
      Wanted : constant Boolean :=
        Item.Details.Kind = Source and then Item.Details.Captured_At = 0
        and then Item.Zoom >= Compact_Below;
   begin
      if Wanted /= Widgets.Is_Visible (Item.Fetch_Button) then
         Widgets.Set_Visible (Item.Fetch_Button, Wanted);
         UI.Text_Areas.Set_Trail
           (Editors.Area (Item.Body_Text).all,
            (if Wanted then Fetch_Width + Fetch_Inset else 0.0));
         Widgets.Request_Layout (Item.Body_Text);
      end if;
   end Show_Fetch;

   procedure Set_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0) is
   begin
      Widgets.Set_Visible (Item.Progress, To = Busy);
      if To = Busy then
         UI.Widgets.Progress_Bars.Set_Value (Item.Progress, 0.0);
      end if;
      case To is
         when Waiting =>
            Labels.Set_Text (Item.Status, "Press Return to capture");
         when Busy =>
            Labels.Set_Text (Item.Status, "Capturing...");
         when Ready =>
            Item.Details.Captured_At := At_Time;
            Clear_Recognized (Item);
            UI.Widgets.Pictures.Clear_Marks (Item.Picture);
            UI.Widgets.Pictures.Set_File (Item.Picture, File);
            Labels.Set_Text (Item.Status, "Captured " & Day (At_Time));
            Show_Fetch (Item);
         when Failed =>
            Labels.Set_Text
              (Item.Status, Fitted ("Failed: " & Detail));
      end case;
   end Set_Capture;

   procedure Set_Zoom (Item : in out Window; To : Float) is
   begin
      if To /= Item.Details.Zoom then
         Item.Details.Zoom := To;
         Item.Zoom_Dirty := True;
      end if;
      UI.Widgets.Pictures.Set_Zoom (Item.Picture, To);
      Sliders.Set_Value (Item.Zoom_Slider, To_Slider (To));
      Buttons.Set_Label (Item.Zoom_Button, Percent (To));
   end Set_Zoom;

   function Box (Item : Window) return Items.Frame is
     ((Left   => Widgets.Left_Of (Item.Frame),
       Top    => Widgets.Top_Of (Item.Frame),
       Width  => Widgets.Width_Of (Item.Frame),
       Height => Widgets.Height_Of (Item.Frame)));

   function Is_Hovered (Item : Window) return Boolean is
     (Item.Assigned and then Item.Details.State = Open
      and then Widgets.Is_Hovered (Item.Frame));

   procedure Show_Title (Item : in out Window);
   --  Take the title as edited, for the item and the bar in the dock.

   procedure Show_Title (Item : in out Window) is
      Typed : constant String := Docs.Whole (Item.Title_Doc);
      Title : constant Projects.Titles.Bounded_String :=
        Projects.Titles.To_Bounded_String (Typed, Ada.Strings.Right);
   begin
      Item.Details.Title := Title;
      Item.Title_Version := Docs.Current (Item.Title_Doc);
      Labels.Set_Text
        (Item.Title_Label,
         Typed (Typed'First ..
                Typed'First - 1
                + Natural'Min (Typed'Length, Labels.Text_Capacity)));
      declare
         Short : constant String := Shortened (Typed);
      begin
         Labels.Set_Text
           (Item.Mini_Title,
            Short (Short'First ..
                   Short'First - 1
                   + Natural'Min (Short'Length, Labels.Text_Capacity)));
      end;
   end Show_Title;

   procedure Show_Words (Item : in out Window);
   --  Count the words, and say how many.

   procedure Show_Words (Item : in out Window) is
   begin
      Item.Content_Version := Docs.Current (Item.Content_Doc);
      if Item.Details.Kind = Note then
         Item.Word_Count := Count_Words (Docs.Whole (Item.Content_Doc));
         --  A failure to dictate is told until the text is changed; what
         --  is going on is told while it is.
         if Item.Dictating in Silent | Failed then
            Item.Dictating := Silent;
            Labels.Set_Text (Item.Status, Status_Text (Item.Word_Count));
         end if;
      end if;
   end Show_Words;

   procedure Take_Back_Live (Item : in out Window);
   --  Remove the text shown while listening, if it can be.

   procedure Take_Back_Live (Item : in out Window) is
      Doc : Docs.Document renames Item.Content_Doc;
   begin
      if Item.Live_Shown and then not Item.Live_Lost then
         pragma Assert (Docs.Current (Doc) = Item.Live_Seen);
         Docs.Replace
           (Doc, Item.Live_From, Item.Live_To, "", Recorded => False);
      end if;
      Item.Live_Shown := False;
      Item.Live_Lost := False;
   end Take_Back_Live;

   function Dictation (Item : Window) return Dictations is
     (Item.Dictating);

   procedure Set_Dictation
     (Item   : in out Window;
      To     : Dictations;
      Detail : String := "") is
   begin
      if To = Failed then
         Take_Back_Live (Item);
      end if;
      Item.Dictating := To;
      Widgets.Set_Visible (Item.Progress, To = Listening);
      UI.Widgets.Progress_Bars.Set_Value (Item.Progress, 0.0);
      Buttons.Set_Icon
        (Item.Speak_Button,
         (if To in Preparing | Listening
          then UI.Icons.Stop else UI.Icons.Microphone));
      Buttons.Set_Label
        (Item.Speak_Button,
         (if To in Preparing | Listening then "Stop" else "Mic"));
      case To is
         when Silent =>
            Labels.Set_Text (Item.Status, Status_Text (Item.Word_Count));
         when Preparing =>
            Labels.Set_Text (Item.Status, "Getting ready...");
         when Listening =>
            Labels.Set_Text (Item.Status, "Listening...");
         when Transcribing =>
            Labels.Set_Text (Item.Status, "Transcribing...");
         when Failed =>
            Labels.Set_Text
              (Item.Status, Fitted ("Could not dictate: " & Detail));
      end case;
   end Set_Dictation;

   procedure Set_Level (Item : in out Window; To : Float) is
      Stepped : constant Float :=
        Float'Rounding (To * Level_Steps) / Level_Steps;
   begin
      if Item.Dictating = Listening
        and then UI.Widgets.Progress_Bars.Value (Item.Progress) /= Stepped
      then
         UI.Widgets.Progress_Bars.Set_Value (Item.Progress, Stepped);
      end if;
   end Set_Level;

   function One_Line_Feeds (Said : String) return String;
   --  Said as it goes in a note: paragraphs are made by line feeds alone.

   function One_Line_Feeds (Said : String) return String is
   begin
      return Spoken : String := Said do
         for C of Spoken loop
            if C = ASCII.CR then
               C := ' ';
            end if;
         end loop;
      end return;
   end One_Line_Feeds;

   procedure Set_Live_Dictation (Item : in out Window; Said : String) is
      Area   : UI.Text_Areas.Text_Area
        renames Editors.Area (Item.Body_Text).all;
      Doc    : Docs.Document renames Item.Content_Doc;
      Spoken : constant String := One_Line_Feeds (Said);
   begin
      if Item.Live_Shown and then Docs.Current (Doc) /= Item.Live_Seen then
         Item.Live_Lost := True;
      end if;
      if Item.Live_Lost then
         return;
      end if;
      if not Item.Live_Shown then
         if Spoken = "" then
            return;
         end if;
         if Widgets.Has_Focus (Item.Body_Text) then
            Item.Live_From := UI.Text_Areas.Caret (Area);
            Item.Live_Break := False;
         else
            Item.Live_From := Docs.Text_End (Doc);
            Item.Live_Break := Docs.Byte_Length (Doc, Docs.Count (Doc)) /= 0;
         end if;
         Item.Live_To := Item.Live_From;
         Item.Live_Shown := True;
      end if;
      declare
         Shown : constant String :=
           (if Item.Live_Break then [ASCII.LF] else "") & Spoken;
      begin
         if Docs.Between (Doc, Item.Live_From, Item.Live_To) /= Shown then
            Docs.Replace
              (Doc, Item.Live_From, Item.Live_To, Shown, Recorded => False);
            Item.Live_To := Texts.End_After (Item.Live_From, Shown);
            Item.Live_Seen := Docs.Current (Doc);
         end if;
      end;
   end Set_Live_Dictation;

   procedure Add_Dictation (Item : in out Window; Said : String) is
      Area : UI.Text_Areas.Text_Area renames Editors.Area (Item.Body_Text).all;
      Doc  : Docs.Document renames Item.Content_Doc;
      Spoken : constant String := One_Line_Feeds (Said);
   begin
      Take_Back_Live (Item);
      if Spoken = "" then
         return;
      end if;
      if Widgets.Has_Focus (Item.Body_Text) then
         --  At the caret, not over what is selected.
         UI.Text_Areas.Select_Range
           (Area, UI.Text_Areas.Caret (Area), UI.Text_Areas.Caret (Area));
         UI.Text_Areas.Insert (Area, Spoken);
      else
         declare
            After : constant Texts.Position := Docs.Text_End (Doc);
            --  An empty last paragraph is filled, not left as a gap.
            Blank : constant Boolean :=
              Docs.Byte_Length (Doc, Docs.Count (Doc)) = 0;
         begin
            Docs.Begin_Step (Doc);
            Docs.Replace
              (Doc, After, After, (if Blank then "" else [ASCII.LF]) & Spoken);
            Docs.End_Step (Doc);
         end;
      end if;
   end Add_Dictation;

   procedure Set_State (Item : in out Window; To : States) is
   begin
      Item.Details.State := To;
      if To /= Open then
         Select_Tool (Item, UI.Widgets.Pictures.Pointer);
         Widgets.Set_Visible (Item.Zoom_Menu, False);
         UI.Widgets.Pictures.Unload (Item.Picture);
      end if;
      Widgets.Set_Visible (Item.Frame, To = Open);
      Widgets.Set_Visible (Item.Mini, To = Minimized);
      Item.Was_Used := False;
   end Set_State;

   procedure Warm (Item : in out Window) is
   begin
      UI.Widgets.Pictures.Load_Soon
        (Item.Picture, Urgent => Item.Details.State = Open);
   end Warm;

   procedure Fit_Zoom (Item : in out Window);
   --  Show what the zoom leaves room for: compact, the bar is smaller and
   --  there is no status line, nor link in a source.

   procedure Fit_Zoom (Item : in out Window) is
      use Yoga.Nodes;
      Chrome : constant Float :=
        Float'Min (1.0, Float'Max (Min_Chrome, Item.Zoom));
      Pixels : constant Float := Item.Pixels;
      Narrow : constant Boolean := Item.Zoom < Compact_Below;
      Of_Source : constant Boolean := Item.Details.Kind = Source;

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Chrome * Pixels);
         Set_Height (Widgets.Node (Part), High * Chrome * Pixels);
      end Size;
   begin
      Widgets.Set_Visible (Item.Status_Bar, not Narrow);
      Widgets.Set_Visible (Item.Body_Text, not (Narrow and then Of_Source));
      Set_Height (Widgets.Node (Item.Title_Bar), Bar_Height * Chrome * Pixels);
      Set_Height
        (Widgets.Node (Item.Title_Field), Title_Height * Chrome * Pixels);
      Set_Height
        (Widgets.Node (Item.Title_Area), Title_Height * Chrome * Pixels);
      Set_Height
        (Widgets.Node (Item.Title_Label), Label_Height * Chrome * Pixels);
      Set_Margin
        (Widgets.Node (Item.Title_Field), Yoga.Right,
         Drag_Room * Chrome * Pixels);
      Set_Margin
        (Widgets.Node (Item.Title_Area), Yoga.Right,
         Drag_Room * Chrome * Pixels);
      Set_Padding
        (Widgets.Node (Item.Title_Bar), Yoga.Horizontal,
         Bar_Pad * Chrome * Pixels);
      Set_Padding
        (Widgets.Node (Item.Title_Area), Yoga.Left,
         Bar_Pad * Chrome * Pixels);
      Size (Item.Minimize_Button, Button_Size, Button_Size);
      Size (Item.Close_Button, Button_Size, Button_Size);
      Size (Item.Tag, Tag_Size, Tag_Size);
      Set_Margin
        (Widgets.Node (Item.Tag), Yoga.Right, Tag_Gap * Chrome * Pixels);
      Labels.Set_Scale (Item.Title_Label, Chrome);
      Set_Position
        (Widgets.Node (Item.Fetch_Button), Yoga.Top,
         Float'Max (1.0, Float'Rounding (Outline * Pixels))
         + (Bar_Height * Chrome + (Url_Height - Fetch_Height) / 2.0)
           * Pixels);
      Show_Fetch (Item);
      Widgets.Request_Layout (Item.Frame);
   end Fit_Zoom;

   procedure Show_Kind (Item : in out Window);
   --  Make the text area the item's text, or its one line, the link; and
   --  show the picture of a source.

   procedure Show_Kind (Item : in out Window) is
      use Yoga.Nodes;
      Of_Source : constant Boolean := Item.Details.Kind = Source;
      Node : constant Yoga.Nodes.Node := Widgets.Node (Item.Body_Text);
   begin
      --  A note's text is in the serif; a source's link, in the face of
      --  the interface.
      if Item.Face_Of /= Item.Details.Kind then
         Item.Face_Of := Item.Details.Kind;
         if Of_Source then
            Editors.Configure
              (Item.Body_Text, UI.Line_Texts.Interface_Font, Link_Size,
               Measure);
         else
            Editors.Configure
              (Item.Body_Text, UI.Line_Texts.Serif, Text_Size, Measure);
         end if;
      end if;
      Widgets.Set_Visible (Item.Tag, Of_Source);
      UI.Text_Areas.Set_Single_Line
        (Editors.Area (Item.Body_Text).all, Of_Source);
      if Of_Source then
         Editors.Set_Icon (Item.Body_Text, UI.Icons.Link);
         Editors.Set_Placeholder (Item.Body_Text, "https://");
      else
         Editors.Clear_Icon (Item.Body_Text);
         Editors.Set_Placeholder (Item.Body_Text, "");
      end if;
      Set_Flex_Grow (Node, (if Of_Source then 0.0 else 1.0));
      Set_Height (Node, (if Of_Source then Url_Height * Item.Pixels else 0.0));
      Widgets.Set_Visible (Item.Speak_Button, not Of_Source);
      Widgets.Set_Visible (Item.Tools, Of_Source);
      Widgets.Set_Visible (Item.Zoom_Slider, Of_Source);
      Widgets.Set_Visible (Item.Zoom_Button, Of_Source);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Picture, Of_Source);
      Fit_Zoom (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Show_Kind;

   function Across_Of (Item : Window) return Float;

   function Scroll_Of (Item : in out Window) return Float;
   --  How far the content is scrolled now (see Items.Info.Scroll).

   function Across_Of (Item : Window) return Float is
     (if Item.Details.Kind = Source
      then UI.Widgets.Pictures.Scrolled_Across (Item.Picture) else 0.0);
   --  How far across it is scrolled: only a source's picture is.

   function Scroll_Of (Item : in out Window) return Float is
     (if Item.Details.Kind = Source
      then UI.Widgets.Pictures.Scrolled (Item.Picture)
      else UI.Text_Areas.Scroll_Top (Editors.Area (Item.Body_Text).all));

   procedure Assign
     (Item       : in out Window;
      Of_Item    : Items.Info;
      Saved_Text : String;
      Picture_File : String := "") is
   begin
      Item.Assigned := True;
      Item.Details := Of_Item;
      Docs.Load
        (Item.Title_Doc, Projects.Titles.To_String (Of_Item.Title));
      Docs.Load (Item.Content_Doc, Saved_Text);
      Item.Dictating := Silent;
      Item.Live_Shown := False;
      Item.Live_Lost := False;
      Text_Fields.Attach (Item.Title_Field, Item.Title_Doc'Unchecked_Access);
      Editors.Attach (Item.Body_Text, Item.Content_Doc'Unchecked_Access);
      Item.Title_Saved := Docs.State (Item.Title_Doc);
      Item.Title_Seen := Item.Title_Saved;
      Item.Content_Saved := Docs.State (Item.Content_Doc);
      Item.Content_Seen := Item.Content_Saved;
      Item.Frame_Dirty := False;
      Item.Zoom_Dirty := False;
      Item.Scroll_Seen := Of_Item.Scroll;
      Item.Across_Seen := Of_Item.Scroll_Across;
      Item.Scroll_At := 0;
      Item.Scroll_Pending := False;
      Item.Editing := False;
      Widgets.Set_Visible (Item.Title_Area, True);
      Widgets.Set_Visible (Item.Title_Field, False);
      Show_Title (Item);
      Show_Kind (Item);
      Clear_Recognized (Item);
      UI.Widgets.Pictures.Set_File (Item.Picture, "");
      UI.Widgets.Pictures.Clear_Marks (Item.Picture);
      Item.Marks_Saved := UI.Widgets.Pictures.Marks_Version (Item.Picture);
      Select_Tool (Item, UI.Widgets.Pictures.Pointer);
      if Of_Item.Kind = Source then
         Set_Zoom (Item, Of_Item.Zoom);
         Item.Zoom_Dirty := False;
         Item.Content_Version := Docs.Current (Item.Content_Doc);
         if Of_Item.Captured_At > 0 and then Picture_File /= "" then
            Set_Capture
              (Item, Ready, Picture_File, At_Time => Of_Item.Captured_At);
         else
            Set_Capture (Item, Waiting);
         end if;
         UI.Widgets.Pictures.Scroll_To
           (Item.Picture, Float'Min (1.0, Of_Item.Scroll));
         UI.Widgets.Pictures.Scroll_Across_To
           (Item.Picture, Float'Min (1.0, Of_Item.Scroll_Across));
      else
         Show_Words (Item);
         Item.Scroll_Pending := Of_Item.Scroll > 0.0;
      end if;
      Set_State (Item, Of_Item.State);
      if Item.Placed_Once then
         Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
      end if;
   end Assign;

   procedure Release (Item : in out Window) is
   begin
      Clear_Recognized (Item);
      UI.Widgets.Pictures.Unload (Item.Picture);
      Widgets.Set_Visible (Item.Frame, False);
      Widgets.Set_Visible (Item.Mini, False);
      Item.Assigned := False;
      Item.Frame_Dirty := False;
      Item.Zoom_Dirty := False;
      Item.Scroll_Pending := False;
      Item.Was_Used := False;
      Item.Dictating := Silent;
      Item.Live_Shown := False;
      Item.Live_Lost := False;
   end Release;

   procedure Place
     (Item : in out Window; Zoom, Origin_X, Origin_Y : Float)
   is
      use Yoga.Nodes;
      Where  : Items.Frame renames Item.Details.Where;
      Pixels : constant Float := Item.Pixels;
   begin
      Item.Zoom := Zoom;
      Item.Origin_X := Origin_X;
      Item.Origin_Y := Origin_Y;
      Item.Placed_Once := True;
      if Item.Assigned and then Item.Details.State = Open then
         Fit_Zoom (Item);
         --  On whole pixels, so that its edges, and the borders in them,
         --  are the same wherever it is.
         Set_Position
           (Widgets.Node (Item.Frame), Yoga.Left,
            Float'Rounding ((Origin_X + Where.Left * Zoom) * Pixels));
         Set_Position
           (Widgets.Node (Item.Frame), Yoga.Top,
            Float'Rounding ((Origin_Y + Where.Top * Zoom) * Pixels));
         Set_Width
           (Widgets.Node (Item.Frame),
            Float'Rounding (Where.Width * Zoom * Pixels));
         Set_Height
           (Widgets.Node (Item.Frame),
            Float'Rounding (Where.Height * Zoom * Pixels));
         --  The link is not zoomed, nor is the title.
         Editors.Set_Zoom
           (Item.Body_Text,
            (if Item.Details.Kind = Source then 1.0 else Zoom));
         --  The tools are in the middle of the status line, which is as
         --  wide as the window within its outline.
         Set_Position
           (Widgets.Node (Item.Tools), Yoga.Left,
            Float'Rounding
              ((Float'Rounding (Where.Width * Zoom * Pixels)
                - 2.0 * Float'Max (1.0, Float'Rounding (Outline * Pixels))
                - UI.Boxes.Offset (Pixels)
                - Tools_Width * Pixels) / 2.0));
         Set_Position
           (Widgets.Node (Item.Speak_Button), Yoga.Left,
            Float'Rounding
              ((Float'Rounding (Where.Width * Zoom * Pixels)
                - 2.0 * Float'Max (1.0, Float'Rounding (Outline * Pixels))
                - UI.Boxes.Offset (Pixels)
                - Button_Size * Pixels) / 2.0));
         Widgets.Request_Layout (Item.Frame);
      end if;
   end Place;

   procedure Bring_To_Front (Item : in out Window) is
   begin
      Widgets.Raise_To_Front (Item.Frame);
   end Bring_To_Front;

   function Is_Editing_Title (Item : Window) return Boolean is
     (Item.Editing);

   procedure Begin_Edit (Item : in out Window);
   --  Make the title a field, with all of it selected, to type over.

   procedure Begin_Edit (Item : in out Window) is
   begin
      Item.Editing := True;
      Widgets.Set_Visible (Item.Title_Area, False);
      --  The press that began it is not let go on what is hidden.
      Grips.Cancel_Drag (Item.Title_Area);
      Widgets.Set_Visible (Item.Title_Field, True);
      UI.Text_Areas.Select_All (Text_Fields.Area (Item.Title_Field).all);
      Widgets.Focus (Item.Title_Field);
   end Begin_Edit;

   procedure End_Edit (Item : in out Window);
   --  Make the title text again, as it has been edited.

   procedure End_Edit (Item : in out Window) is
   begin
      Item.Editing := False;
      Show_Title (Item);
      Widgets.Set_Visible (Item.Title_Field, False);
      Widgets.Set_Visible (Item.Title_Area, True);
   end End_Edit;

   procedure Focus_Text (Item : in out Window) is
   begin
      Widgets.Focus (Item.Body_Text);
   end Focus_Text;

   function Is_Dragging (Item : Window) return Boolean is
     (Grips.Is_Dragging (Item.Title_Bar)
      or else Grips.Is_Dragging (Item.Title_Area)
      or else Grips.Is_Dragging (Item.Corner));

   procedure Poll (Item : in out Window; Action : out Actions) is
      Across, Down : Float;
      Area_Across, Area_Down : Float;
      Clicked      : Boolean;
      Entered      : Boolean;
      Doubled      : Boolean;
      Used         : Boolean;
   begin
      Action := None;

      if Item.Scroll_Pending
        and then Item.Details.State = Open
        and then Widgets.Width_Of (Item.Body_Text) > 0.0
      then
         UI.Text_Areas.Scroll_To
           (Editors.Area (Item.Body_Text).all, Item.Details.Scroll);
         Widgets.Invalidate (Item.Body_Text);
         Item.Scroll_Pending := False;
         Item.Scroll_Seen := Scroll_Of (Item);
      end if;

      --  Moved and sized, in canvas units.
      Grips.Take_Drag (Item.Title_Bar, Across, Down);
      Grips.Take_Drag (Item.Title_Area, Area_Across, Area_Down);
      Across := Across + Area_Across;
      Down := Down + Area_Down;
      if Across /= 0.0 or else Down /= 0.0 then
         Item.Details.Where.Left :=
           Item.Details.Where.Left + Across / Item.Zoom;
         Item.Details.Where.Top := Item.Details.Where.Top + Down / Item.Zoom;
         Item.Frame_Dirty := True;
         Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
      end if;
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Grips.Take_Drag (Item.Corner, Across, Down);
      if Across /= 0.0 or else Down /= 0.0 then
         Item.Raw_Width := Item.Raw_Width + Across / Item.Zoom;
         Item.Raw_Height := Item.Raw_Height + Down / Item.Zoom;
         Item.Details.Where := Sized
           ((Item.Details.Where with delta
               Width  => Item.Raw_Width,
               Height => Item.Raw_Height));
         Item.Frame_Dirty := True;
         Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
      end if;
      Item.Resizing := Grips.Is_Dragging (Item.Corner);

      --  Raised when it starts to be used.
      Used := Is_Dragging (Item)
        or else Sliders.Is_Dragging (Item.Zoom_Slider)
        or else Item.Editing
        or else Widgets.Has_Focus (Item.Body_Text);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Widgets.Raise_To_Front (Item.Frame);
      end if;
      Item.Was_Used := Used;
      --  A ring round the window being typed in.
      if Item.Editing or else Widgets.Has_Focus (Item.Body_Text) then
         Panels.Set_Ring (Item.Frame, Item.Ring_Ink);
      else
         Panels.Clear_Ring (Item.Frame);
      end if;

      --  What was typed.
      if Docs.Current (Item.Title_Doc) /= Item.Title_Version then
         Show_Title (Item);
      end if;
      if Docs.Current (Item.Content_Doc) /= Item.Content_Version then
         Show_Words (Item);
      end if;
      Grips.Take_Double_Click (Item.Title_Area, Doubled);
      if Doubled and then Item.Details.State = Open
        and then not Item.Editing
      then
         Begin_Edit (Item);
      end if;
      if Item.Details.Kind = Source and then Item.Details.State = Open then
         UI.Text_Areas.Take_Return
           (Editors.Area (Item.Body_Text).all, Entered);
         Buttons.Take_Click (Item.Fetch_Button, Clicked);
         if Entered or else Clicked then
            Action := Capture;
            return;
         end if;
      end if;
      if Item.Details.Kind = Source and then Item.Details.State = Open then
         Sliders.Take_Change (Item.Zoom_Slider, Entered);
         if Entered then
            Set_Zoom (Item, From_Slider (Sliders.Value (Item.Zoom_Slider)));
         end if;
         Buttons.Take_Click (Item.Cursor_Button, Clicked);
         if Clicked then
            Select_Tool (Item, UI.Widgets.Pictures.Pointer);
         end if;
         Buttons.Take_Click (Item.Marker_Button, Clicked);
         if Clicked then
            Select_Tool (Item, UI.Widgets.Pictures.Highlighter);
         end if;
         Buttons.Take_Click (Item.Eraser_Button, Clicked);
         if Clicked then
            Select_Tool (Item, UI.Widgets.Pictures.Eraser);
         end if;
         Buttons.Take_Click (Item.Zoom_Button, Clicked);
         if Clicked then
            Widgets.Set_Visible
              (Item.Zoom_Menu, not Widgets.Is_Visible (Item.Zoom_Menu));
            Widgets.Raise_To_Front (Item.Zoom_Menu);
         end if;
         for Which in Item.Menu_Buttons'Range loop
            Buttons.Take_Click (Item.Menu_Buttons (Which), Clicked);
            if Clicked then
               Set_Zoom (Item, Preset_Zooms (Which));
               Widgets.Set_Visible (Item.Zoom_Menu, False);
            end if;
         end loop;
      end if;
      if Item.Editing then
         Text_Fields.Take_Return (Item.Title_Field, Entered);
         if Entered or else not Widgets.Has_Focus (Item.Title_Field) then
            End_Edit (Item);
         end if;
      end if;

      if Item.Details.Kind = Note and then Item.Details.State = Open then
         Buttons.Take_Click (Item.Speak_Button, Clicked);
         if Clicked then
            Action := Speak;
            return;
         end if;
      end if;

      --  Whichever button, of the window or the bar in the dock.
      if Item.Details.State = Open then
         Buttons.Take_Click (Item.Minimize_Button, Clicked);
         if Clicked then
            Action := Minimize;
            return;
         end if;
         Buttons.Take_Click (Item.Close_Button, Clicked);
         if Clicked then
            Action := Close;
         end if;
      elsif Item.Details.State = Minimized then
         Grips.Take_Click (Item.Mini_Area, Clicked);
         if Clicked then
            Action := Restore;
            return;
         end if;
         Buttons.Take_Click (Item.Mini_Close, Clicked);
         if Clicked then
            Action := Close;
         end if;
      end if;
   end Poll;

   procedure Flush
     (Item  : in out Window;
      Store : in out Projects.Store;
      Now   : SDL3.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
   is
      Title_Now   : constant Natural := Docs.State (Item.Title_Doc);
      Content_Now : constant Natural := Docs.State (Item.Content_Doc);
      Typing      : constant Boolean :=
        Widgets.Has_Focus (Item.Title_Field)
        or else Widgets.Has_Focus (Item.Body_Text)
        or else Item.Held;
   begin
      Wrote := False;
      if Title_Now /= Item.Title_Seen or else Content_Now /= Item.Content_Seen
      then
         Item.Title_Seen := Title_Now;
         Item.Content_Seen := Content_Now;
         Item.Changed_At := Now;
      end if;

      if Item.Frame_Dirty and then not Is_Dragging (Item) then
         Set_Frame (Store, Item.Details.Key, Item.Details.Where);
         Item.Frame_Dirty := False;
         Wrote := True;
      end if;

      if Item.Zoom_Dirty
        and then not Sliders.Is_Dragging (Item.Zoom_Slider)
      then
         Items.Set_Zoom (Store, Item.Details.Key, Item.Details.Zoom);
         Item.Zoom_Dirty := False;
         Wrote := True;
      end if;

      if not Item.Scroll_Pending and then Item.Details.State = Open then
         declare
            Scrolled : constant Float := Scroll_Of (Item);
            Across   : constant Float := Across_Of (Item);
         begin
            if Scrolled /= Item.Scroll_Seen or else Across /= Item.Across_Seen
            then
               Item.Scroll_Seen := Scrolled;
               Item.Across_Seen := Across;
               Item.Scroll_At := Now;
            end if;
            if (Scrolled /= Item.Details.Scroll
                or else Across /= Item.Details.Scroll_Across)
              and then (Force or else Now >= Item.Scroll_At + Idle_Delay)
            then
               Items.Set_Scroll (Store, Item.Details.Key, Scrolled, Across);
               Item.Details.Scroll := Scrolled;
               Item.Details.Scroll_Across := Across;
               Wrote := True;
            end if;
         end;
      end if;

      if Item.Details.Kind = Source
        and then UI.Widgets.Pictures.Marks_Version (Item.Picture)
                 /= Item.Marks_Saved
        and then not UI.Widgets.Pictures.Is_Marking (Item.Picture)
      then
         declare
            Kept : Items.Mark_List;
         begin
            Get_Marks (Item, Kept);
            Items.Save_Marks (Store, Item.Details.Key, Kept);
         end;
         Item.Marks_Saved := UI.Widgets.Pictures.Marks_Version (Item.Picture);
         Wrote := True;
      end if;

      if (Title_Now /= Item.Title_Saved
          or else Content_Now /= Item.Content_Saved)
        and then (Force or else not Typing
                  or else Now >= Item.Changed_At + Idle_Delay)
      then
         if Title_Now /= Item.Title_Saved then
            Set_Title
              (Store, Item.Details.Key,
               Projects.Titles.To_String (Item.Details.Title));
            Item.Title_Saved := Title_Now;
         end if;
         if Content_Now /= Item.Content_Saved then
            Set_Content
              (Store, Item.Details.Key, Docs.Whole (Item.Content_Doc));
            Item.Content_Saved := Content_Now;
         end if;
         Wrote := True;
      end if;
   end Flush;

end Items.Windows;
