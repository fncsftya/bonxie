with Items.Records;
with Items.Sources;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
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
   package Frames renames UI.Widgets.Frames;
   package Editors renames UI.Widgets.Editors;
   package Pictures renames UI.Widgets.Pictures;

   use type Widgets.Clipboard_Access;
   package Sliders renames UI.Widgets.Sliders;

   use type Docs.Version;
   use type Ada.Calendar.Time;
   use type SDL3.Events.Milliseconds;

   pragma Assert (Items.Marks.Max_Marks = UI.Widgets.Pictures.Max_Marks);

   --  In points

   Outline       : constant Float := Frames.Outline;
   Button_Size   : constant Float := Frames.Button_Size;
   Button_Gap    : constant Float := Frames.Button_Gap;
   Label_Height  : constant Float := Frames.Label_Height;
   Status_Height : constant Float := Frames.Status_Height;
   Corner_Size   : constant Float := Frames.Corner_Size;
   Bar_Height    : constant Float := Frames.Bar_Height;
   Text_Size     : constant Float := 15.0;
   Link_Size     : constant Float := 12.0;
   --  Of the text of a note, in the serif, and of the link of a source.
   Measure       : constant Float := 2000.0;
   Zoom_Row_Height : constant Float := 19.0;
   Zoom_Button_Width : constant Float := 44.0;
   Zoom_Slider_Width : constant Float := 56.0;
   Progress_Height   : constant Float := 3.0;
   Preset_Width  : constant Float := 44.0;
   Speak_Icon_Size : constant Float := 12.0;
   Level_Steps   : constant Float := 20.0;
   --  How many sizes of the bar that shows how loud the speech is.
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;

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

   procedure Set_Shared
     (Item   : in out Window;
      Shared : not null Shared_Access) is
   begin
      Frames.Share_Title (Item.Chrome, Shared);
      Editors.Set_Shared (Item.Body_Text, Shared);
   end Set_Shared;

   procedure Build
     (Item    : in out Window;
      Canvas  : in out Widgets.Widget'Class;
      Dock    : in out Widgets.Widget'Class;
      Bar     : UI.Themes.Slot;
      Density : Float)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Density;
      Edge   : constant Float := UI.Boxes.Edge (Outline * Pixels);

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;
   begin
      Item.Pixels := Pixels;
      Frames.Build
        (Item.Chrome, Canvas, Bar, Pixels, Editable_Title => True,
         Dock => Dock'Unrestricted_Access);
      Frames.Add_Content (Item.Chrome, Item.Body_Text);
      Frames.Add_Content (Item.Chrome, Item.Picture);
      Frames.Add_Status_Item (Item.Chrome, Item.Status);
      Frames.Add_Status_Item (Item.Chrome, Item.Tools);
      Widgets.Add (Item.Tools, Item.Cursor_Button);
      Widgets.Add (Item.Tools, Item.Marker_Button);
      Widgets.Add (Item.Tools, Item.Eraser_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Speak_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Slider);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Button);
      Frames.Add_Over_Status (Item.Chrome, Item.Progress);

      Editors.Configure
        (Item.Body_Text, UI.Line_Texts.Serif, Text_Size, Measure);
      Editors.Set_Paper (Item.Body_Text, UI.Themes.Page);
      Set_Flex_Grow (Widgets.Node (Item.Body_Text), 1.0);
      --  Its own outline is the window's at the sides.
      Set_Margin
        (Widgets.Node (Item.Body_Text), Yoga.Horizontal, -Edge);
      Set_Height (Widgets.Node (Item.Body_Text), 0.0);

      Set_Flex_Grow (Widgets.Node (Item.Picture), 1.0);
      Set_Height (Widgets.Node (Item.Picture), 0.0);

      Set_Flex_Grow (Widgets.Node (Item.Status), 1.0);
      Set_Width (Widgets.Node (Item.Status), 0.0);
      Set_Height (Widgets.Node (Item.Status), Label_Height * Pixels);
      Frames.Add_Over_Content (Item.Chrome, Item.Zoom_Menu);
      Frames.Add_Over_Content (Item.Chrome, Item.Fetch_Button);
      for Row in Item.Menu_Rows'Range loop
         Widgets.Add (Item.Zoom_Menu, Item.Menu_Rows (Row));
      end loop;
      for Which in Item.Menu_Buttons'Range loop
         Widgets.Add (Item.Menu_Rows (1 + (Which - 1) / 3),
                      Item.Menu_Buttons (Which));
      end loop;

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
      Panels.Set_Fill (Item.Zoom_Menu, UI.Themes.Border);
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
           (Item.Menu_Buttons (Which),
            Items.Sources.Percent (Preset_Zooms (Which)));
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

      Widgets.Set_Visible (Item.Fetch_Button, False);
      Widgets.Set_Visible (Item.Tools, False);
      Widgets.Set_Visible (Item.Zoom_Slider, False);
      Widgets.Set_Visible (Item.Zoom_Button, False);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Picture, False);
      Widgets.Set_Visible (Item.Progress, False);
   end Build;

   function Is_Assigned (Item : Window) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Window; To : UI.Themes.Slot) is
   begin
      Frames.Set_Tag (Item.Chrome, To);
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

   procedure Get_Marks (Item : Window; Into : out Items.Marks.Mark_List) is
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

   procedure Set_Marks (Item : in out Window; Kept : Items.Marks.Mark_List) is
      Shown : UI.Widgets.Pictures.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Marks.Mark renames Kept.Marks (Index);
         begin
            Shown (Index) :=
              UI.Widgets.Pictures.Clamped_Mark
                (Each.Left, Each.Right, Each.Y);
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
              (Item.Status, Labels.Fitted ("Failed: " & Detail));
      end case;
   end Set_Capture;

   procedure Set_Zoom (Item : in out Window; To : Float) is
   begin
      if To /= Item.Details.Zoom then
         Item.Details.Zoom := To;
         Item.Zoom_Dirty := True;
      end if;
      UI.Widgets.Pictures.Set_Zoom (Item.Picture, To);
      Sliders.Set_Value (Item.Zoom_Slider, Items.Sources.To_Slider (To));
      Buttons.Set_Label (Item.Zoom_Button, Items.Sources.Percent (To));
   end Set_Zoom;

   function Box (Item : Window) return Items.Frame is
     ((Left   => Frames.Left_Of (Item.Chrome),
       Top    => Frames.Top_Of (Item.Chrome),
       Width  => Frames.Width_Of (Item.Chrome),
       Height => Frames.Height_Of (Item.Chrome)));

   function Owns (Item : Window; Hit : UI.Widgets.Widget_Access)
     return Boolean is (Frames.Owns (Item.Chrome, Hit));

   function Text_Contains (Item : Window; X, Y : Float) return Boolean is
     (Widgets.Contains (Item.Body_Text, X, Y));

   function Over_Text_Selection
     (Item : in out Window; X, Y : Float) return Boolean is
     (UI.Text_Areas.Is_Over_Selection
        (Editors.Area (Item.Body_Text).all, X, Y));

   procedure Put_Caret (Item : in out Window; X, Y : Float) is
      Area : UI.Text_Areas.Text_Area renames Editors.Area (Item.Body_Text).all;
   begin
      Widgets.Focus (Item.Body_Text);
      UI.Text_Areas.Click (Area, X, Y);
      UI.Text_Areas.Release (Area);
   end Put_Caret;

   procedure Edit_Text (Item : in out Window; Act : Text_Acts) is
      Area  : UI.Text_Areas.Text_Area renames
        Editors.Area (Item.Body_Text).all;
      Board : constant Widgets.Clipboard_Access :=
        Widgets.Clipboard (Item.Body_Text);
   begin
      if Act = Select_All then
         UI.Text_Areas.Select_All (Area);
      elsif Board /= null then
         case Act is
            when Copy =>
               UI.Text_Areas.Copy (Area, Board.all);
            when Cut =>
               UI.Text_Areas.Cut (Area, Board.all);
            when Paste =>
               UI.Text_Areas.Paste (Area, Board.all);
            when Select_All =>
               null;
         end case;
      end if;
   end Edit_Text;

   function Picture_Contains (Item : Window; X, Y : Float) return Boolean is
     (Widgets.Contains (Item.Picture, X, Y));

   function Over_Picture_Selection
     (Item : Window; X, Y : Float) return Boolean is
     (Pictures.Is_Over_Selection (Item.Picture, X, Y));

   function Has_Words (Item : Window) return Boolean is
     (Pictures.Has_Words (Item.Picture));

   procedure Select_All_Words (Item : in out Window) is
   begin
      Pictures.Select_All (Item.Picture);
   end Select_All_Words;

   procedure Copy_Words (Item : Window) is
   begin
      Pictures.Copy (Item.Picture);
   end Copy_Words;

   function Is_Hovered (Item : Window) return Boolean is
     (Item.Assigned and then Item.Details.State = Open
      and then Frames.Is_Hovered (Item.Chrome));

   procedure Show_Title (Item : in out Window);
   --  Take the title as edited, for the item and the bar in the dock.

   procedure Show_Title (Item : in out Window) is
      Typed : constant String := Docs.Whole (Item.Title_Doc);
      Title : constant Projects.Titles.Bounded_String :=
        Projects.Titles.To_Bounded_String (Typed, Ada.Strings.Right);
   begin
      Item.Details.Title := Title;
      Item.Title_Version := Docs.Current (Item.Title_Doc);
      Frames.Set_Title (Item.Chrome, Typed);
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
      UI.Text_Areas.Clear_Faint (Editors.Area (Item.Body_Text).all);
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
              (Item.Status, Labels.Fitted ("Could not dictate: " & Detail));
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

   procedure Set_Live_Dictation (Item : in out Window; Said : String; Settled : Natural := 0) is
      Area   : UI.Text_Areas.Text_Area
        renames Editors.Area (Item.Body_Text).all;
      Doc    : Docs.Document renames Item.Content_Doc;
      Spoken : constant String := One_Line_Feeds (Said);
   begin
      if Item.Live_Shown and then Docs.Current (Doc) /= Item.Live_Seen then
         Item.Live_Lost := True;
      end if;
      if Item.Live_Lost then
         UI.Text_Areas.Clear_Faint (Area);
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
         declare
            --  What is not settled starts at a character's beginning.
            Edge : Natural := Natural'Min (Settled, Spoken'Length);
         begin
            while Edge < Spoken'Length
              and then Character'Pos (Spoken (Spoken'First + Edge)) in 16#80# .. 16#BF#
            loop
               Edge := Edge + 1;
            end loop;
            if Edge < Spoken'Length then
               UI.Text_Areas.Set_Faint
                 (Area,
                  Texts.End_After
                    (Item.Live_From, Shown (Shown'First .. Shown'Last - (Spoken'Length - Edge))),
                  Item.Live_To);
            else
               UI.Text_Areas.Clear_Faint (Area);
            end if;
         end;
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
      Frames.Set_Shown (Item.Chrome, To = Open, To = Minimized);
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
   begin
      Frames.Set_Status_Visible (Item.Chrome, not Narrow);
      Widgets.Set_Visible (Item.Body_Text, not (Narrow and then Of_Source));
      Frames.Set_Scale (Item.Chrome, Chrome);
      Set_Position
        (Widgets.Node (Item.Fetch_Button), Yoga.Top,
         UI.Boxes.Edge (Outline * Pixels)
         + (Bar_Height * Chrome + (Url_Height - Fetch_Height) / 2.0)
           * Pixels);
      Show_Fetch (Item);
      Widgets.Request_Layout (Item.Body_Text);
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
      Frames.Set_Tag_Visible (Item.Chrome, Of_Source);
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
      Frames.Attach_Title (Item.Chrome, Item.Title_Doc'Unchecked_Access);
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
      Frames.Reset_Title_Edit (Item.Chrome);
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
      Frames.Set_Shown (Item.Chrome, False, False);
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
         Frames.Place
           (Item.Chrome,
            Float'Rounding ((Origin_X + Where.Left * Zoom) * Pixels),
            Float'Rounding ((Origin_Y + Where.Top * Zoom) * Pixels),
            Float'Rounding (Where.Width * Zoom * Pixels),
            Float'Rounding (Where.Height * Zoom * Pixels));
         --  The link is not zoomed, nor is the title.
         Editors.Set_Zoom
           (Item.Body_Text,
            (if Item.Details.Kind = Source then 1.0 else Zoom));
         --  The tools are in the middle of the status line, which is as
         --  wide as the window within its outline.
         declare
            Across : constant Float :=
              Frames.Status_Width
                (Item.Chrome, Float'Rounding (Where.Width * Zoom * Pixels));
         begin
            Set_Position
              (Widgets.Node (Item.Tools), Yoga.Left,
               Float'Rounding ((Across - Tools_Width * Pixels) / 2.0));
            Set_Position
              (Widgets.Node (Item.Speak_Button), Yoga.Left,
               Float'Rounding ((Across - Button_Size * Pixels) / 2.0));
         end;
      end if;
   end Place;

   procedure Bring_To_Front (Item : in out Window) is
   begin
      Frames.Raise_To_Front (Item.Chrome);
   end Bring_To_Front;

   function Is_Editing_Title (Item : Window) return Boolean is
     (Frames.Is_Editing_Title (Item.Chrome));

   procedure Begin_Edit (Item : in out Window);
   --  Make the title a field, with all of it selected, to type over.

   procedure Begin_Edit (Item : in out Window) is
   begin
      Frames.Begin_Title_Edit (Item.Chrome);
   end Begin_Edit;

   procedure End_Edit (Item : in out Window);
   --  Make the title text again, as it has been edited.

   procedure End_Edit (Item : in out Window) is
   begin
      Show_Title (Item);
      Frames.End_Title_Edit (Item.Chrome);
   end End_Edit;

   procedure Focus_Text (Item : in out Window) is
   begin
      Widgets.Focus (Item.Body_Text);
   end Focus_Text;

   function Is_Dragging (Item : Window) return Boolean is
     (Frames.Is_Dragging (Item.Chrome));

   procedure Poll (Item : in out Window; Action : out Actions) is
      Across, Down : Float;
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
      Frames.Take_Move (Item.Chrome, Across, Down);
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
      Frames.Take_Size (Item.Chrome, Across, Down);
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
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);

      --  Raised when it starts to be used.
      Used := Is_Dragging (Item)
        or else Sliders.Is_Dragging (Item.Zoom_Slider)
        or else Frames.Is_Editing_Title (Item.Chrome)
        or else Widgets.Has_Focus (Item.Body_Text);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Frames.Raise_To_Front (Item.Chrome);
      end if;
      Item.Was_Used := Used;
      --  A ring round the window being typed in.
      Frames.Set_Ring
        (Item.Chrome,
         Frames.Is_Editing_Title (Item.Chrome)
         or else Widgets.Has_Focus (Item.Body_Text));

      --  What was typed.
      if Docs.Current (Item.Title_Doc) /= Item.Title_Version then
         Show_Title (Item);
      end if;
      if Docs.Current (Item.Content_Doc) /= Item.Content_Version then
         Show_Words (Item);
      end if;
      Frames.Take_Title_Double_Click (Item.Chrome, Doubled);
      if Doubled and then Item.Details.State = Open
        and then not Frames.Is_Editing_Title (Item.Chrome)
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
            Set_Zoom
              (Item,
               Items.Sources.From_Slider (Sliders.Value (Item.Zoom_Slider)));
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
      if Frames.Is_Editing_Title (Item.Chrome) then
         Frames.Take_Title_Return (Item.Chrome, Entered);
         if Entered or else not Frames.Title_Has_Focus (Item.Chrome) then
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
         Frames.Take_Minimize (Item.Chrome, Clicked);
         if Clicked then
            Action := Minimize;
            return;
         end if;
         Frames.Take_Close (Item.Chrome, Clicked);
         if Clicked then
            Action := Close;
         end if;
      elsif Item.Details.State = Minimized then
         Frames.Take_Restore (Item.Chrome, Clicked);
         if Clicked then
            Action := Restore;
            return;
         end if;
         Frames.Take_Close (Item.Chrome, Clicked);
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
        Frames.Title_Has_Focus (Item.Chrome)
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
         Items.Records.Set_Frame
           (Store, Item.Details.Key, Item.Details.Where);
         Item.Frame_Dirty := False;
         Wrote := True;
      end if;

      if Item.Zoom_Dirty
        and then not Sliders.Is_Dragging (Item.Zoom_Slider)
      then
         Items.Sources.Set_Zoom (Store, Item.Details.Key, Item.Details.Zoom);
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
               Items.Records.Set_Scroll
                 (Store, Item.Details.Key, Scrolled, Across);
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
            Kept : Items.Marks.Mark_List;
         begin
            Get_Marks (Item, Kept);
            Items.Marks.Save_Marks (Store, Item.Details.Key, Kept);
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
            Items.Records.Set_Title
              (Store, Item.Details.Key,
               Projects.Titles.To_String (Item.Details.Title));
            Item.Title_Saved := Title_Now;
         end if;
         if Content_Now /= Item.Content_Saved then
            Items.Records.Set_Content
              (Store, Item.Details.Key, Docs.Whole (Item.Content_Doc));
            Item.Content_Saved := Content_Now;
         end if;
         Wrote := True;
      end if;
   end Flush;

end Items.Windows;
