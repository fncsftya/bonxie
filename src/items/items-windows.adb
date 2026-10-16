with Items.Records;
with Items.Sources;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Frames.Handlers;
with Pomarine.Widgets.Layouts;

package body Items.Windows is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;
   package Pictures renames Pomarine.Widgets.Pictures;

   use type Widgets.Clipboard_Access;
   package Sliders renames Pomarine.Widgets.Sliders;

   use type Docs.Version;
   use type Ada.Calendar.Time;
   use type SDL3.Events.Milliseconds;

   pragma Assert (Items.Marks.Max_Marks = Pomarine.Widgets.Pictures.Max_Marks);
   pragma Assert (Items.Marks.Max_Marks = Pomarine.Widgets.Page_Views.Max_Marks);

   package Views renames Pomarine.Widgets.Page_Views;

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
   Outline_Button_Width : constant Float := 76.0;
   --  Of the button of a note's link to the outline.
   Level_Steps   : constant Float := 20.0;
   --  How many sizes of the bar that shows how loud the speech is.
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;
   Pager_Width   : constant Float := 2.0 * Button_Size + Button_Gap;
   Pager_Lift    : constant Float := 6.0;
   Wizard_Gap    : constant Float := 10.0;
   Wizard_Button_Width  : constant Float := 150.0;
   Wizard_Button_Height : constant Float := 32.0;
   --  The page buttons' width, and how far they are above the status line.

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
      Editors.Set_Shared (Item.Text_View, Shared);
   end Set_Shared;

   procedure Listen (Item : in out Window);
   --  Give the window's widgets the procedures they call (see Update).

   procedure Build
     (Item    : in out Window;
      Canvas  : in out Widgets.Widget'Class;
      Dock    : in out Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float)
   is
      Pixels : constant Float := Density;
      Edge   : constant Float := Pomarine.Boxes.Edge (Outline * Pixels);
      --  In whole pixels, as the outline is.

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Layouts.Set_Layout (Part, Width => Wide, Height => High);
      end Size;
   begin
      Item.Pixels := Pixels;
      Frames.Build
        (Item.Chrome, Canvas, Bar, Pixels, Editable_Title => True,
         Dock => Dock'Unrestricted_Access);
      Frames.Add_Content (Item.Chrome, Item.Body_Text);
      Frames.Add_Content (Item.Chrome, Item.Picture);
      Frames.Add_Content (Item.Chrome, Item.Pages);
      Frames.Add_Content (Item.Chrome, Item.Text_View);
      Frames.Add_Content (Item.Chrome, Item.Wizard);
      Widgets.Add (Item.Wizard, Item.Link_Button);
      Widgets.Add (Item.Wizard, Item.File_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Status);
      Frames.Add_Status_Item (Item.Chrome, Item.Tools);
      Widgets.Add (Item.Tools, Item.Cursor_Button);
      Widgets.Add (Item.Tools, Item.Marker_Button);
      Widgets.Add (Item.Tools, Item.Eraser_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Speak_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Outline_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Slider);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Button);
      Frames.Add_Over_Status (Item.Chrome, Item.Progress);

      Editors.Configure
        (Item.Body_Text, Pomarine.Line_Texts.Serif, Text_Size, Measure);
      Editors.Set_Paper (Item.Body_Text, Pomarine.Themes.Page);
      Layouts.Set_Layout (Item.Body_Text, Grow => 1.0, Height => 0.0);
      --  Its own outline is the window's at the sides.
      Layouts.Set_Layout
        (Item.Body_Text, Margin => (Left | Right => -Edge, others => <>),
         Unit => Layouts.Device_Pixels);

      Layouts.Set_Layout (Item.Picture, Grow => 1.0, Height => 0.0);
      Layouts.Set_Layout (Item.Pages, Grow => 1.0, Height => 0.0);

      --  A text file's text: the page's paper, in the serif, as a note's,
      --  to be read and selected.
      Editors.Configure
        (Item.Text_View, Pomarine.Line_Texts.Serif, Text_Size, Measure);
      Editors.Set_Paper (Item.Text_View, Pomarine.Themes.Page);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Text_View).all);
      Layouts.Set_Layout (Item.Text_View, Grow => 1.0, Height => 0.0);
      Layouts.Set_Layout
        (Item.Text_View, Margin => (Left | Right => -Edge, others => <>),
         Unit => Layouts.Device_Pixels);

      --  The two ways to say where a source is from, in the middle.
      Panels.Set_Fill (Item.Wizard, Pomarine.Themes.Page);
      Layouts.Set_Layout
        (Item.Wizard, Grow => 1.0, Height => 0.0, Flow => Layouts.Column,
         Align => Layouts.Center, Spread => Layouts.Center, Gap => Wizard_Gap);
      Buttons.Set_Label (Item.Link_Button, "From URL");
      Buttons.Set_Icon (Item.Link_Button, Icon_Set.Link);
      Buttons.Set_Captioned (Item.Link_Button, True);
      Buttons.Set_Label (Item.File_Button, "From File");
      Buttons.Set_Icon (Item.File_Button, Icon_Set.Document);
      Buttons.Set_Captioned (Item.File_Button, True);
      Size (Item.Link_Button, Wizard_Button_Width, Wizard_Button_Height);
      Size (Item.File_Button, Wizard_Button_Width, Wizard_Button_Height);

      Layouts.Set_Layout (Item.Status, Grow => 1.0, Width => 0.0, Height => Label_Height);
      Frames.Add_Over_Content (Item.Chrome, Item.Zoom_Menu);
      Frames.Add_Over_Content (Item.Chrome, Item.Pager);
      Widgets.Add (Item.Pager, Item.Prev_Button);
      Widgets.Add (Item.Pager, Item.Next_Button);
      Frames.Add_Over_Content (Item.Chrome, Item.Fetch_Button);
      for Row in Item.Menu_Rows'Range loop
         Widgets.Add (Item.Zoom_Menu, Item.Menu_Rows (Row));
      end loop;
      for Which in Item.Menu_Buttons'Range loop
         Widgets.Add (Item.Menu_Rows (1 + (Which - 1) / 3),
                      Item.Menu_Buttons (Which));
      end loop;

      --  The progress bar, along the foot of the status line.
      Layouts.Set_Layout
        (Item.Progress, Place => Layouts.Absolute, Position => (Left | Right | Bottom => 0.0, others => <>),
         Height => Progress_Height);

      --  The tools, in the middle of the status line (see Place).
      Layouts.Set_Layout
        (Item.Tools, Place => Layouts.Absolute,
         Position => (Top => (Status_Height - Zoom_Row_Height) / 2.0, others => <>),
         Flow => Layouts.Row, Gap => Button_Gap);
      Buttons.Set_Label (Item.Cursor_Button, "Ptr");
      Buttons.Set_Icon (Item.Cursor_Button, Icon_Set.Cursor);
      Buttons.Set_Label (Item.Marker_Button, "Mark");
      Buttons.Set_Icon (Item.Marker_Button, Icon_Set.Highlighter);
      Buttons.Set_Label (Item.Eraser_Button, "Rub");
      Buttons.Set_Icon (Item.Eraser_Button, Icon_Set.Eraser);
      Buttons.Set_Selected (Item.Cursor_Button, True);
      Size (Item.Eraser_Button, Button_Size, Zoom_Row_Height);
      Size (Item.Cursor_Button, Button_Size, Zoom_Row_Height);
      Size (Item.Marker_Button, Button_Size, Zoom_Row_Height);

      --  The zoom bar: a slider, and the button for the menu.
      Size (Item.Zoom_Slider, Zoom_Slider_Width, Zoom_Row_Height);
      Buttons.Set_Label (Item.Zoom_Button, "100%");
      Size (Item.Zoom_Button, Zoom_Button_Width, Zoom_Row_Height);

      --  The button to dictate, of a note.
      Buttons.Set_Label (Item.Speak_Button, "Mic");
      Buttons.Set_Icon (Item.Speak_Button, Icon_Set.Microphone);
      Size (Item.Speak_Button, Button_Size, Zoom_Row_Height);
      Buttons.Set_Icon_Size (Item.Speak_Button, Speak_Icon_Size);
      --  In the middle of the status line, as the tools are (see Place).
      Layouts.Set_Layout
        (Item.Speak_Button, Place => Layouts.Absolute,
         Position => (Top => (Status_Height - Zoom_Row_Height) / 2.0, others => <>));

      --  The button of a note's link to the outline, at the right of its status line.
      Buttons.Set_Label (Item.Outline_Button, "Section");
      Buttons.Set_Captioned (Item.Outline_Button, True);
      Buttons.Set_Dropdown (Item.Outline_Button, True);
      Size (Item.Outline_Button, Outline_Button_Width, Zoom_Row_Height);

      --  The page buttons: over the picture, at the foot, in the middle (see Place).
      Layouts.Set_Layout
        (Item.Pager, Place => Layouts.Absolute,
         Position => (Bottom => (Status_Height + Edge + Pager_Lift) * Pixels, others => <>),
         Flow => Layouts.Row, Gap => Button_Gap, Unit => Layouts.Device_Pixels);
      Buttons.Set_Label (Item.Prev_Button, "Previous page");
      Buttons.Set_Icon (Item.Prev_Button, Icon_Set.Back);
      Buttons.Set_Label (Item.Next_Button, "Next page");
      Buttons.Set_Icon (Item.Next_Button, Icon_Set.Forward);
      Size (Item.Prev_Button, Button_Size, Zoom_Row_Height);
      Size (Item.Next_Button, Button_Size, Zoom_Row_Height);

      --  The menu: over the picture, at the right, with the window's
      --  outline between its buttons.
      Panels.Set_Fill (Item.Zoom_Menu, Pomarine.Themes.Border);
      Layouts.Set_Layout
        (Item.Zoom_Menu, Place => Layouts.Absolute,
         Position => (Right => (Corner_Size + Edge) * Pixels,
                      Bottom => (Status_Height + Edge) * Pixels,
                      others => <>),
         Flow => Layouts.Column, Padding => (others => Edge), Gap => Edge,
         Unit => Layouts.Device_Pixels);
      for Each of Item.Menu_Rows loop
         Layouts.Set_Layout
           (Each, Flow => Layouts.Row, Gap => Edge, Unit => Layouts.Device_Pixels);
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
      Layouts.Set_Layout
        (Item.Fetch_Button, Place => Layouts.Absolute,
         Position => (Right => Edge + Pomarine.Boxes.Offset (Pixels) + Fetch_Inset * Pixels,
                      others => <>),
         Unit => Layouts.Device_Pixels);

      Widgets.Set_Visible (Item.Fetch_Button, False);
      Widgets.Set_Visible (Item.Tools, False);
      Widgets.Set_Visible (Item.Zoom_Slider, False);
      Widgets.Set_Visible (Item.Zoom_Button, False);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Pager, False);
      Widgets.Set_Visible (Item.Text_View, False);
      Widgets.Set_Visible (Item.Wizard, False);
      Widgets.Set_Visible (Item.Picture, False);
      Widgets.Set_Visible (Item.Pages, False);
      Widgets.Set_Visible (Item.Progress, False);
      Listen (Item);
   end Build;

   function Is_Assigned (Item : Window) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Window; To : Pomarine.Themes.Slot) is
   begin
      Frames.Set_Tag (Item.Chrome, To);
   end Set_Tag;

   procedure Set_Outline_Link
     (Item   : in out Window;
      Linked : Boolean;
      Ink    : Pomarine.Themes.Slot;
      Open   : Boolean) is
   begin
      if Item.Details.Kind = Note then
         if Linked then
            Frames.Set_Tag (Item.Chrome, Ink);
         end if;
         Frames.Set_Tag_Visible (Item.Chrome, Linked);
         Buttons.Set_Selected (Item.Outline_Button, Open);
      end if;
   end Set_Outline_Link;

   function Outline_Box (Item : Window) return Items.Frame is
     ((Left   => Widgets.Left_Of (Item.Outline_Button),
       Top    => Widgets.Top_Of (Item.Outline_Button),
       Width  => Widgets.Width_Of (Item.Outline_Button),
       Height => Widgets.Height_Of (Item.Outline_Button)));

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

   function Shown_Marks_Version (Item : Window) return Natural is
     (if Item.Paged then Views.Marks_Version (Item.Pages)
      else Pomarine.Widgets.Pictures.Marks_Version (Item.Picture));
   --  Of the widget shown, whatever the item is.

   function Marks_Version (Item : Window) return Natural is
     (Shown_Marks_Version (Item));

   function Is_Marking (Item : Window) return Boolean is
     (if Item.Paged then Views.Is_Marking (Item.Pages)
      else Pomarine.Widgets.Pictures.Is_Marking (Item.Picture));

   procedure Get_Marks (Item : Window; Into : out Items.Marks.Mark_List) is
   begin
      if Item.Paged then
         Into.Count := Views.Mark_Count (Item.Pages);
         for Index in 1 .. Into.Count loop
            declare
               Each : constant Views.Mark := Views.Mark_At (Item.Pages, Index);
            begin
               Into.Marks (Index) :=
                 (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => Each.Page);
            end;
         end loop;
         return;
      end if;
      Into.Count := Pomarine.Widgets.Pictures.Mark_Count (Item.Picture);
      for Index in 1 .. Into.Count loop
         declare
            Each : constant Pomarine.Widgets.Pictures.Mark :=
              Pomarine.Widgets.Pictures.Mark_At (Item.Picture, Index);
         begin
            Into.Marks (Index) :=
              (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => 1);
         end;
      end loop;
   end Get_Marks;

   function Status (Item : Window) return String is
     (Labels.Text (Item.Status));

   function Tool (Item : Window) return Pomarine.Widgets.Pictures.Tools is
     (if Item.Paged then Views.Tool (Item.Pages)
      else Pomarine.Widgets.Pictures.Tool (Item.Picture));

   function Mark_Count (Item : Window) return Natural is
     (if Item.Paged then Views.Mark_Count (Item.Pages)
      else Pomarine.Widgets.Pictures.Mark_Count (Item.Picture));

   procedure Select_Tool
     (Item : in out Window; To : Pomarine.Widgets.Pictures.Tools) is
   begin
      Pomarine.Widgets.Pictures.Set_Tool (Item.Picture, To);
      Views.Set_Tool (Item.Pages, To);
      Buttons.Set_Selected
        (Item.Cursor_Button, To = Pomarine.Widgets.Pictures.Pointer);
      Buttons.Set_Selected
        (Item.Marker_Button, To = Pomarine.Widgets.Pictures.Highlighter);
      Buttons.Set_Selected
        (Item.Eraser_Button, To = Pomarine.Widgets.Pictures.Eraser);
   end Select_Tool;

   procedure Set_Marks (Item : in out Window; Kept : Items.Marks.Mark_List) is
      Shown  : Pomarine.Widgets.Pictures.Mark_Array (1 .. Kept.Count);
      Paged  : Views.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Marks.Mark renames Kept.Marks (Index);
         begin
            Shown (Index) :=
              Pomarine.Widgets.Pictures.Clamped_Mark
                (Each.Left, Each.Right, Each.Y);
            Paged (Index) := Views.Clamped_Mark (Each.Left, Each.Right, Each.Y, Each.Page);
         end;
      end loop;
      Pomarine.Widgets.Pictures.Set_Marks (Item.Picture, Shown);
      Views.Set_Marks (Item.Pages, Paged);
      Item.Marks_Saved := Shown_Marks_Version (Item);
   end Set_Marks;

   procedure Set_Recognized
     (Item : in out Window; Found : Vision.Result) is
   begin
      Item.Recognized := Found;
      Pomarine.Widgets.Pictures.Set_Words
        (Item.Picture, Item.Recognized'Unchecked_Access);
   end Set_Recognized;

   procedure Clear_Recognized (Item : in out Window);
   --  Forget the words, as of a picture that is not the one shown.

   procedure Clear_Recognized (Item : in out Window) is
   begin
      Pomarine.Widgets.Pictures.Set_Words (Item.Picture, null);
      Item.Recognized.Count := 0;
      Item.Recognized.Length := 0;
      Item.Recognized.Truncated := False;
   end Clear_Recognized;

   function Is_Paged (Item : Window) return Boolean is
     (Item.Paged);

   function Shows_Picture (Item : Window) return Boolean is
     (Item.Paged or else Pomarine.Widgets.Pictures.File_Name (Item.Picture) /= "");

   function Document_Page (Item : Window) return Natural is
     (if Item.Paged and then Views.Is_Settled (Item.Pages)
      then Views.Current_Page (Item.Pages) else 0);

   procedure Go_To_Page (Item : in out Window; Page : Positive) is
   begin
      Views.Show_Page (Item.Pages, Page);
   end Go_To_Page;

   function Recognized_Count (Item : Window) return Natural is
     (if Item.Paged then Views.Word_Count (Item.Pages) else Item.Recognized.Count);

   function Selected_Text (Item : Window) return String is
     (if Item.Paged then Views.Selected_Text (Item.Pages)
      else Pomarine.Widgets.Pictures.Selected_Text (Item.Picture));

   procedure Set_Title_Text (Item : in out Window; To : String) is
   begin
      Docs.Replace
        (Item.Title_Doc, (Paragraph => 1, Index => 1),
         Docs.Text_End (Item.Title_Doc), To);
      --  Poll shows it, as it does what is typed.
   end Set_Title_Text;

   procedure Set_Progress (Item : in out Window; To : Float) is
   begin
      Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, To);
   end Set_Progress;

   function Is_Unchosen (Item : Window) return Boolean is
     (Item.Details.Kind = Source and then Item.Details.Origin = Unchosen);

   function Is_Text_Source (Item : Window) return Boolean is
     (Item.Details.Kind = Source and then Item.Details.Origin /= Unchosen
      and then Items.Sources.Is_Text (Items.Extensions.To_String (Item.Details.Document)));
   --  Whether the source is to say where it is from, or shows a text
   --  file: not a picture.

   procedure Show_Mode (Item : in out Window);
   --  Show what the source is now: its two buttons, its text or its
   --  picture, and the tools for a picture.

   procedure Show_Fetch (Item : in out Window);
   --  Show the button to take the picture of a source's link, and leave
   --  room for it, while there is none and the link is shown.

   procedure Show_Fetch (Item : in out Window) is
      Wanted : constant Boolean :=
        Item.Details.Kind = Source and then Item.Details.Captured_At = 0
        and then Item.Details.Origin = Remote
        and then Item.Zoom >= Compact_Below;
   begin
      if Wanted /= Widgets.Is_Visible (Item.Fetch_Button) then
         Widgets.Set_Visible (Item.Fetch_Button, Wanted);
         Pomarine.Text_Areas.Set_Trail
           (Editors.Area (Item.Body_Text).all,
            (if Wanted then Fetch_Width + Fetch_Inset else 0.0));
         Widgets.Request_Layout (Item.Body_Text);
      end if;
   end Show_Fetch;

   function Page_Status (Item : Window) return String is
     ("Page" & Item.Details.Page'Image & " of" & Item.Details.Page_Count'Image);

   procedure Show_Pager (Item : in out Window);
   --  Show the buttons to turn the page, if the source has pages to turn.

   procedure Show_Pager (Item : in out Window) is
      Paged : constant Boolean :=
        Item.Details.Kind = Source and then Item.Details.Page_Count > 1
        and then not Is_Text_Source (Item);
   begin
      Widgets.Set_Visible (Item.Pager, Paged);
      Buttons.Set_Enabled (Item.Prev_Button, Paged and then Item.Details.Page > 1);
      Buttons.Set_Enabled
        (Item.Next_Button, Paged and then Item.Details.Page < Item.Details.Page_Count);
   end Show_Pager;

   procedure Set_Pages
     (Item : in out Window; Document : String; Page, Count : Natural) is
   begin
      Item.Details.Document :=
        Items.Extensions.To_Bounded_String (Document, Ada.Strings.Right);
      Item.Details.Page := Page;
      Item.Details.Page_Count := Count;
      Show_Mode (Item);
      --  Turning to another page of a document that is shown.
      if Item.Paged and then Count > 0 and then Item.Details.Captured_At > 0 then
         Labels.Set_Text (Item.Status, Page_Status (Item));
      end if;
   end Set_Pages;

   procedure Set_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0) is
   begin
      Widgets.Set_Visible (Item.Progress, To = Busy);
      if To = Busy then
         Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, 0.0);
      end if;
      case To is
         when Waiting =>
            Labels.Set_Text
              (Item.Status,
               (case Item.Details.Origin is
                   when Unchosen => "Choose where it comes from",
                   when Remote   => "Press Return to capture",
                   when Local    => "Choose a file"));
         when Busy =>
            Labels.Set_Text (Item.Status, "Capturing...");
         when Ready =>
            Item.Details.Captured_At := At_Time;
            Clear_Recognized (Item);
            Pomarine.Widgets.Pictures.Clear_Marks (Item.Picture);
            Views.Clear_Marks (Item.Pages);
            if Item.Details.Page > 0
              and then Items.Sources.Is_Vector (Items.Extensions.To_String (Item.Details.Document))
            then
               declare
                  Message : String (1 .. 160);
                  Last    : Natural;
               begin
                  Items.Vector_Pages.Open
                    (Item.Pages, Item.Doc_Sizes, Item.Doc_Source, File,
                     Item.Details.Page_Count, Message, Last);
                  Item.Paged := Last < Message'First;
                  if not Item.Paged then
                     Labels.Set_Text (Item.Status, Labels.Fitted ("Failed: " & Message (1 .. Last)));
                     return;
                  end if;
                  Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
                  Views.Show_Page (Item.Pages, Item.Details.Page);
               end;
            else
               Item.Paged := False;
               Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
               Pomarine.Widgets.Pictures.Set_File (Item.Picture, File);
            end if;
            Show_Mode (Item);
            Labels.Set_Text
              (Item.Status,
               (if Item.Details.Page_Count > 0
                then Page_Status (Item) else "Captured " & Day (At_Time)));
            Show_Fetch (Item);
         when Failed =>
            Labels.Set_Text
              (Item.Status, Labels.Fitted ("Failed: " & Detail));
      end case;
   end Set_Capture;

   procedure Set_Origin (Item : in out Window; To : Items.Origins) is
      Is_File : constant Boolean := To = Items.Local;
   begin
      Item.Details.Origin := To;
      --  A file's path is chosen, not typed: pressing it asks to choose
      --  another (see Listen).
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Body_Text).all, Is_File);
      Editors.Set_Icon (Item.Body_Text, (if Is_File then Icon_Set.Document else Icon_Set.Link));
      Editors.Set_Placeholder (Item.Body_Text, (if Is_File then "File" else "https://"));
      Show_Mode (Item);
      if Item.Details.Captured_At = 0 then
         Set_Capture (Item, Waiting);
      end if;
   end Set_Origin;

   function Selected_Shown_Text (Item : Window) return String is
     (Pomarine.Text_Areas.Selected_Text
        (Editors.Area (Item.Text_View'Unrestricted_Access.all).all));
   --  (Area takes the editor to change; looking does not.)

   function Shown_Text (Item : Window) return String is
     (Docs.Whole (Item.Text_Doc));

   procedure Set_Link (Item : in out Window; To : String) is
   begin
      Docs.Replace
        (Item.Content_Doc, (Paragraph => 1, Index => 1),
         Docs.Text_End (Item.Content_Doc), To);
      --  Poll shows it, as it does what is typed.
   end Set_Link;

   procedure Show_Text (Item : in out Window; File : String; At_Time : Projects.Seconds) is
   begin
      Item.Details.Captured_At := At_Time;
      Clear_Recognized (Item);
      Pomarine.Widgets.Pictures.Clear_Marks (Item.Picture);
      Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Docs.Load (Item.Text_Doc, Items.Sources.Read_Text (File));
      Widgets.Set_Visible (Item.Progress, False);
      Show_Mode (Item);
      Labels.Set_Text (Item.Status, "Captured " & Day (At_Time));
   end Show_Text;

   procedure Set_Zoom (Item : in out Window; To : Float) is
   begin
      if To /= Item.Details.Zoom then
         Item.Details.Zoom := To;
         Item.Zoom_Dirty := True;
      end if;
      Pomarine.Widgets.Pictures.Set_Zoom (Item.Picture, To);
      Views.Set_Zoom (Item.Pages, To);
      Sliders.Set_Value (Item.Zoom_Slider, Items.Sources.To_Slider (To));
      Buttons.Set_Label (Item.Zoom_Button, Items.Sources.Percent (To));
   end Set_Zoom;

   function Box (Item : Window) return Items.Frame is
     ((Left   => Frames.Left_Of (Item.Chrome),
       Top    => Frames.Top_Of (Item.Chrome),
       Width  => Frames.Width_Of (Item.Chrome),
       Height => Frames.Height_Of (Item.Chrome)));

   function Owns (Item : Window; Hit : Pomarine.Widgets.Widget_Access)
     return Boolean is (Frames.Owns (Item.Chrome, Hit));

   function Text_Contains (Item : Window; X, Y : Float) return Boolean is
     (Widgets.Contains (Item.Body_Text, X, Y));

   function Over_Text_Selection
     (Item : in out Window; X, Y : Float) return Boolean is
     (Pomarine.Text_Areas.Is_Over_Selection
        (Editors.Area (Item.Body_Text).all, X, Y));

   procedure Put_Caret (Item : in out Window; X, Y : Float) is
      Area : Pomarine.Text_Areas.Text_Area renames Editors.Area (Item.Body_Text).all;
   begin
      Widgets.Focus (Item.Body_Text);
      Pomarine.Text_Areas.Click (Area, X, Y);
      Pomarine.Text_Areas.Release (Area);
   end Put_Caret;

   procedure Edit_Text (Item : in out Window; Act : Text_Acts) is
      Area  : Pomarine.Text_Areas.Text_Area renames
        Editors.Area (Item.Body_Text).all;
      Board : constant Widgets.Clipboard_Access :=
        Widgets.Clipboard (Item.Body_Text);
   begin
      if Act = Select_All then
         Pomarine.Text_Areas.Select_All (Area);
      elsif Board /= null then
         case Act is
            when Copy =>
               Pomarine.Text_Areas.Copy (Area, Board.all);
            when Cut =>
               Pomarine.Text_Areas.Cut (Area, Board.all);
            when Paste =>
               Pomarine.Text_Areas.Paste (Area, Board.all);
            when Select_All =>
               null;
         end case;
      end if;
   end Edit_Text;

   function Picture_Contains (Item : Window; X, Y : Float) return Boolean is
     (if Item.Paged then Widgets.Contains (Item.Pages, X, Y) else Widgets.Contains (Item.Picture, X, Y));

   function Over_Picture_Selection
     (Item : Window; X, Y : Float) return Boolean is
     (if Item.Paged then Views.Is_Over_Selection (Item.Pages, X, Y)
      else Pictures.Is_Over_Selection (Item.Picture, X, Y));

   function Has_Words (Item : Window) return Boolean is
     (if Item.Paged then Views.Has_Words (Item.Pages) else Pictures.Has_Words (Item.Picture));

   procedure Select_All_Words (Item : in out Window) is
   begin
      if Item.Paged then
         Views.Select_All (Item.Pages);
      else
         Pictures.Select_All (Item.Picture);
      end if;
   end Select_All_Words;

   procedure Copy_Words (Item : Window) is
   begin
      if Item.Paged then
         Views.Copy (Item.Pages);
      else
         Pictures.Copy (Item.Picture);
      end if;
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
      Pomarine.Text_Areas.Clear_Faint (Editors.Area (Item.Body_Text).all);
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
      Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, 0.0);
      Buttons.Set_Icon
        (Item.Speak_Button,
         (if To in Preparing | Listening
          then Icon_Set.Stop else Icon_Set.Microphone));
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
        and then Pomarine.Widgets.Progress_Bars.Value (Item.Progress) /= Stepped
      then
         Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, Stepped);
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
      Area   : Pomarine.Text_Areas.Text_Area
        renames Editors.Area (Item.Body_Text).all;
      Doc    : Docs.Document renames Item.Content_Doc;
      Spoken : constant String := One_Line_Feeds (Said);
   begin
      if Item.Live_Shown and then Docs.Current (Doc) /= Item.Live_Seen then
         Item.Live_Lost := True;
      end if;
      if Item.Live_Lost then
         Pomarine.Text_Areas.Clear_Faint (Area);
         return;
      end if;
      if not Item.Live_Shown then
         if Spoken = "" then
            return;
         end if;
         if Widgets.Has_Focus (Item.Body_Text) then
            Item.Live_From := Pomarine.Text_Areas.Caret (Area);
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
               Pomarine.Text_Areas.Set_Faint
                 (Area,
                  Texts.End_After
                    (Item.Live_From, Shown (Shown'First .. Shown'Last - (Spoken'Length - Edge))),
                  Item.Live_To);
            else
               Pomarine.Text_Areas.Clear_Faint (Area);
            end if;
         end;
      end;
   end Set_Live_Dictation;

   procedure Add_Dictation (Item : in out Window; Said : String) is
      Area : Pomarine.Text_Areas.Text_Area renames Editors.Area (Item.Body_Text).all;
      Doc  : Docs.Document renames Item.Content_Doc;
      Spoken : constant String := One_Line_Feeds (Said);
   begin
      Take_Back_Live (Item);
      if Spoken = "" then
         return;
      end if;
      if Widgets.Has_Focus (Item.Body_Text) then
         --  At the caret, not over what is selected.
         Pomarine.Text_Areas.Select_Range
           (Area, Pomarine.Text_Areas.Caret (Area), Pomarine.Text_Areas.Caret (Area));
         Pomarine.Text_Areas.Insert (Area, Spoken);
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
         Select_Tool (Item, Pomarine.Widgets.Pictures.Pointer);
         Widgets.Set_Visible (Item.Zoom_Menu, False);
         Pomarine.Widgets.Pictures.Unload (Item.Picture);
         Views.Unload (Item.Pages);
      end if;
      Frames.Set_Shown (Item.Chrome, To = Open, To = Minimized);
      Item.Was_Used := False;
   end Set_State;

   procedure Warm (Item : in out Window) is
   begin
      Pomarine.Widgets.Pictures.Load_Soon
        (Item.Picture, Urgent => Item.Details.State = Open);
   end Warm;

   procedure Fit_Zoom (Item : in out Window);
   --  Show what the zoom leaves room for: compact, the bar is smaller and
   --  there is no status line, nor link in a source.

   procedure Fit_Zoom (Item : in out Window) is
      Chrome : constant Float :=
        Float'Min (1.0, Float'Max (Min_Chrome, Item.Zoom));
      Pixels : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
      Narrow : constant Boolean := Item.Zoom < Compact_Below;
      Of_Source : constant Boolean := Item.Details.Kind = Source;
   begin
      Frames.Set_Status_Visible (Item.Chrome, not Narrow);
      Widgets.Set_Visible
        (Item.Body_Text, not (Narrow and then Of_Source) and then not Is_Unchosen (Item));
      Frames.Set_Scale (Item.Chrome, Chrome);
      Layouts.Set_Layout
        (Item.Fetch_Button,
         Position => (Top => Pomarine.Boxes.Edge (Outline * Pixels)
                             + (Bar_Height * Chrome + (Url_Height - Fetch_Height) / 2.0)
                               * Pixels,
                      others => <>),
         Unit => Layouts.Device_Pixels);
      Show_Fetch (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Fit_Zoom;

   procedure Show_Mode (Item : in out Window) is
      Of_Source : constant Boolean := Item.Details.Kind = Source;
      Pictured  : constant Boolean :=
        Of_Source and then not Is_Unchosen (Item) and then not Is_Text_Source (Item);
   begin
      Widgets.Set_Visible (Item.Tools, Pictured);
      Widgets.Set_Visible (Item.Zoom_Slider, Pictured);
      Widgets.Set_Visible (Item.Zoom_Button, Pictured);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Picture, Pictured and then not Item.Paged);
      Widgets.Set_Visible (Item.Pages, Pictured and then Item.Paged);
      Widgets.Set_Visible (Item.Text_View, Is_Text_Source (Item));
      Widgets.Set_Visible (Item.Wizard, Is_Unchosen (Item));
      Show_Pager (Item);
      Fit_Zoom (Item);
   end Show_Mode;

   procedure Show_Kind (Item : in out Window);
   --  Make the text area the item's text, or its one line, the link; and
   --  show the picture of a source.

   procedure Show_Kind (Item : in out Window) is
      Of_Source : constant Boolean := Item.Details.Kind = Source;
   begin
      --  A note's text is in the serif; a source's link, in the face of
      --  the interface.
      if Item.Face_Of /= Item.Details.Kind then
         Item.Face_Of := Item.Details.Kind;
         if Of_Source then
            Editors.Configure
              (Item.Body_Text, Pomarine.Line_Texts.Interface_Font, Link_Size,
               Measure);
         else
            Editors.Configure
              (Item.Body_Text, Pomarine.Line_Texts.Serif, Text_Size, Measure);
         end if;
      end if;
      Frames.Set_Tag_Visible (Item.Chrome, Of_Source);
      Pomarine.Text_Areas.Set_Single_Line
        (Editors.Area (Item.Body_Text).all, Of_Source);
      if Of_Source then
         Editors.Set_Icon (Item.Body_Text, Icon_Set.Link);
         Editors.Set_Placeholder (Item.Body_Text, "https://");
      else
         Editors.Clear_Icon (Item.Body_Text);
         Editors.Set_Placeholder (Item.Body_Text, "");
      end if;
      Layouts.Set_Layout
        (Item.Body_Text, Grow => (if Of_Source then 0.0 else 1.0),
         Height => (if Of_Source then Url_Height else 0.0));
      Widgets.Set_Visible (Item.Speak_Button, not Of_Source);
      Widgets.Set_Visible (Item.Outline_Button, not Of_Source);
      if not Of_Source then
         Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Body_Text).all, False);
      end if;
      Show_Mode (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Show_Kind;

   function Across_Of (Item : Window) return Float;

   function Scroll_Of (Item : in out Window) return Float;
   --  How far the content is scrolled now (see Items.Info.Scroll).

   function Across_Of (Item : Window) return Float is
     (if Item.Details.Kind = Source
      then (if Item.Paged then Views.Scrolled_Across (Item.Pages)
            else Pomarine.Widgets.Pictures.Scrolled_Across (Item.Picture)) else 0.0);
   --  How far across it is scrolled: only a source's picture is.

   function Scroll_Of (Item : in out Window) return Float is
     (if Item.Details.Kind = Source
      then (if Item.Paged then Views.Scrolled (Item.Pages)
            else Pomarine.Widgets.Pictures.Scrolled (Item.Picture))
      else Pomarine.Text_Areas.Scroll_Top (Editors.Area (Item.Body_Text).all));

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
      Docs.Load (Item.Text_Doc, "");
      Editors.Attach (Item.Text_View, Item.Text_Doc'Unchecked_Access);
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
      Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Pomarine.Widgets.Pictures.Clear_Marks (Item.Picture);
      Item.Marks_Saved := Shown_Marks_Version (Item);
      Select_Tool (Item, Pomarine.Widgets.Pictures.Pointer);
      if Of_Item.Kind = Source then
         Set_Origin (Item, Of_Item.Origin);
         Set_Zoom (Item, Of_Item.Zoom);
         Item.Zoom_Dirty := False;
         Item.Content_Version := Docs.Current (Item.Content_Doc);
         if Of_Item.Captured_At > 0 and then Picture_File /= "" then
            if Is_Text_Source (Item) then
               Show_Text (Item, Picture_File, Of_Item.Captured_At);
            else
               Set_Capture
                 (Item, Ready, Picture_File, At_Time => Of_Item.Captured_At);
            end if;
         else
            Set_Capture (Item, Waiting);
         end if;
         Pomarine.Widgets.Pictures.Scroll_To
           (Item.Picture, Float'Min (1.0, Of_Item.Scroll));
         Pomarine.Widgets.Pictures.Scroll_Across_To
           (Item.Picture, Float'Min (1.0, Of_Item.Scroll_Across));
         if Item.Paged then
            Views.Scroll_To (Item.Pages, Float'Min (1.0, Of_Item.Scroll));
            Views.Scroll_Across_To (Item.Pages, Float'Min (1.0, Of_Item.Scroll_Across));
         end if;
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
      Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Pomarine.Widgets.Pictures.Unload (Item.Picture);
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
      Where  : Items.Frame renames Item.Details.Where;
      Pixels : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
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
            Layouts.Set_Layout
              (Item.Tools,
               Position => (Left => Float'Rounding ((Across - Tools_Width * Pixels) / 2.0),
                            others => <>),
               Unit => Layouts.Device_Pixels);
            Layouts.Set_Layout
              (Item.Pager,
               Position => (Left => Float'Rounding ((Across - Pager_Width * Pixels) / 2.0),
                            Bottom => (Status_Height + Outline + Pager_Lift) * Pixels,
                            others => <>),
               Unit => Layouts.Device_Pixels);
            Layouts.Set_Layout
              (Item.Speak_Button,
               Position => (Left => Float'Rounding ((Across - Button_Size * Pixels) / 2.0),
                            others => <>),
               Unit => Layouts.Device_Pixels);
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

   package Hooks is new Pomarine.Widgets.Callbacks (Window);
   package Frame_Hooks is new Pomarine.Widgets.Frames.Handlers (Window);

   subtype Source_Widget is Widgets.Widget'Class;

   procedure Say (Item : in out Window; Action : Actions);
   --  Tell the application what a button asked for, if it listens.

   procedure Say (Item : in out Window; Action : Actions) is
   begin
      if Item.Said /= null then
         Item.Said (Item.Said_Self, Item.Said_Proc, Item.Said_Which, Action);
      end if;
   end Say;

   --  What the window's widgets say: each is for the window it is of.

   procedure Moved
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The title bar was dragged: move it, in canvas units.

   procedure Moved
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      Item.Details.Where.Left := Item.Details.Where.Left + Event.Across / Item.Zoom;
      Item.Details.Where.Top := Item.Details.Where.Top + Event.Down / Item.Zoom;
      Item.Frame_Dirty := True;
      Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
   end Moved;

   procedure Sized
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The corner was dragged: size it, in canvas units, but not under the
   --  least.

   procedure Sized
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Item.Raw_Width := Item.Raw_Width + Event.Across / Item.Zoom;
      Item.Raw_Height := Item.Raw_Height + Event.Down / Item.Zoom;
      Item.Details.Where := Sized
        ((Item.Details.Where with delta
            Width  => Item.Raw_Width,
            Height => Item.Raw_Height));
      Item.Frame_Dirty := True;
      Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);
   end Sized;

   procedure Title_Pressed_Twice
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Title_Pressed_Twice
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State = Open and then not Frames.Is_Editing_Title (Item.Chrome) then
         Begin_Edit (Item);
      end if;
   end Title_Pressed_Twice;

   procedure Title_Ended
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  Return was pressed in the title's field, or it lost the focus.

   procedure Title_Ended
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Frames.Is_Editing_Title (Item.Chrome) then
         End_Edit (Item);
      end if;
   end Title_Ended;

   function Is_Open_Source (Item : Window) return Boolean is
     (Item.Details.Kind = Source and then Item.Details.State = Open);

   procedure Fetch_Asked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  Return in a source's link, or its Add button.

   procedure Fetch_Asked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open_Source (Item) then
         Say (Item, Capture);
      end if;
   end Fetch_Asked;

   procedure Page_Turned
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The button before or after: its Index says which, 1 or 2.

   procedure Page_Turned
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if Is_Open_Source (Item) and then Item.Details.Page_Count > 1 then
         Say (Item, (if Event.Index = 1 then Previous_Page else Next_Page));
      end if;
   end Page_Turned;

   procedure Way_Chosen
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  One of the two buttons of a source yet to say where it is from
   --  (Index 1, a link; 2, a file), or a file's path that was pressed.

   procedure Way_Chosen
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if Is_Open_Source (Item) then
         case Event.Index is
            when 1 =>
               Say (Item, Choose_Link);
            when others =>
               if Item.Details.Origin /= Remote then
                  Say (Item, Choose_File);
               end if;
         end case;
      end if;
   end Way_Chosen;

   procedure Zoom_Moved
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Zoom_Moved
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open_Source (Item) then
         Set_Zoom (Item, Items.Sources.From_Slider (Sliders.Value (Item.Zoom_Slider)));
      end if;
   end Zoom_Moved;

   procedure Pointer_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   procedure Marker_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   procedure Eraser_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Pointer_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open_Source (Item) then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Pointer);
      end if;
   end Pointer_Clicked;

   procedure Marker_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open_Source (Item) then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Highlighter);
      end if;
   end Marker_Clicked;

   procedure Eraser_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open_Source (Item) then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Eraser);
      end if;
   end Eraser_Clicked;

   procedure Zoom_Menu_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The button that opens the menu of zooms.

   procedure Zoom_Menu_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open_Source (Item) then
         Widgets.Set_Visible (Item.Zoom_Menu, not Widgets.Is_Visible (Item.Zoom_Menu));
         Widgets.Raise_To_Front (Item.Zoom_Menu);
      end if;
   end Zoom_Menu_Clicked;

   procedure Preset_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  A zoom of the menu: its Index.

   procedure Preset_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if Is_Open_Source (Item) then
         Set_Zoom (Item, Preset_Zooms (Event.Index));
         Widgets.Set_Visible (Item.Zoom_Menu, False);
      end if;
   end Preset_Clicked;

   procedure Speak_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Speak_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.Kind = Note and then Item.Details.State = Open then
         Say (Item, Speak);
      end if;
   end Speak_Clicked;

   procedure Outline_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Outline_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.Kind = Note and then Item.Details.State = Open then
         Say (Item, Link_To_Outline);
      end if;
   end Outline_Clicked;

   --  Whichever button, of the window or the bar in the dock

   procedure Minimize_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Minimize_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State = Open then
         Say (Item, Minimize);
      end if;
   end Minimize_Clicked;

   procedure Restore_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Restore_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State = Minimized then
         Say (Item, Restore);
      end if;
   end Restore_Clicked;

   procedure Close_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Close_Clicked
     (Item : in out Window; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State in Open | Minimized then
         Say (Item, Close);
      end if;
   end Close_Clicked;

   procedure Listen (Item : in out Window) is
      use all type Widgets.Event_Kind;
   begin
      Frame_Hooks.On (Item.Chrome, Move, Item'Unrestricted_Access, Moved'Access);
      Frame_Hooks.On (Item.Chrome, Resize, Item'Unrestricted_Access, Sized'Access);
      Frame_Hooks.On (Item.Chrome, Double_Click, Item'Unrestricted_Access, Title_Pressed_Twice'Access);
      Frame_Hooks.On (Item.Chrome, Submit, Item'Unrestricted_Access, Title_Ended'Access);
      Frame_Hooks.On (Item.Chrome, Blur, Item'Unrestricted_Access, Title_Ended'Access);
      Frame_Hooks.On (Item.Chrome, Minimize, Item'Unrestricted_Access, Minimize_Clicked'Access);
      Frame_Hooks.On (Item.Chrome, Restore, Item'Unrestricted_Access, Restore_Clicked'Access);
      Frame_Hooks.On (Item.Chrome, Close, Item'Unrestricted_Access, Close_Clicked'Access);
      Hooks.On (Item.Body_Text, Submit, Item'Unrestricted_Access, Fetch_Asked'Access);
      Hooks.On (Item.Fetch_Button, Click, Item'Unrestricted_Access, Fetch_Asked'Access);
      Widgets.Set_Tag (Item.Link_Button, Widgets.No_Tag, 1);
      Widgets.Set_Tag (Item.File_Button, Widgets.No_Tag, 2);
      Widgets.Set_Tag (Item.Body_Text, Widgets.No_Tag, 2);
      Hooks.On (Item.Link_Button, Click, Item'Unrestricted_Access, Way_Chosen'Access);
      Hooks.On (Item.File_Button, Click, Item'Unrestricted_Access, Way_Chosen'Access);
      Hooks.On (Item.Body_Text, Click, Item'Unrestricted_Access, Way_Chosen'Access);
      Hooks.On (Item.Zoom_Slider, Change, Item'Unrestricted_Access, Zoom_Moved'Access);
      Hooks.On (Item.Cursor_Button, Click, Item'Unrestricted_Access, Pointer_Clicked'Access);
      Hooks.On (Item.Marker_Button, Click, Item'Unrestricted_Access, Marker_Clicked'Access);
      Hooks.On (Item.Eraser_Button, Click, Item'Unrestricted_Access, Eraser_Clicked'Access);
      Widgets.Set_Tag (Item.Prev_Button, Widgets.No_Tag, 1);
      Widgets.Set_Tag (Item.Next_Button, Widgets.No_Tag, 2);
      Hooks.On (Item.Prev_Button, Click, Item'Unrestricted_Access, Page_Turned'Access);
      Hooks.On (Item.Next_Button, Click, Item'Unrestricted_Access, Page_Turned'Access);
      Hooks.On (Item.Zoom_Button, Click, Item'Unrestricted_Access, Zoom_Menu_Clicked'Access);
      for Which in Item.Menu_Buttons'Range loop
         Widgets.Set_Tag (Item.Menu_Buttons (Which), Widgets.No_Tag, Which);
         Hooks.On (Item.Menu_Buttons (Which), Click, Item'Unrestricted_Access, Preset_Clicked'Access);
      end loop;
      Hooks.On (Item.Speak_Button, Click, Item'Unrestricted_Access, Speak_Clicked'Access);
      Hooks.On (Item.Outline_Button, Click, Item'Unrestricted_Access, Outline_Clicked'Access);
   end Listen;

   procedure Update (Item : in out Window) is
      Used : Boolean;
   begin
      if Item.Scroll_Pending
        and then Item.Details.State = Open
        and then Widgets.Width_Of (Item.Body_Text) > 0.0
      then
         Pomarine.Text_Areas.Scroll_To
           (Editors.Area (Item.Body_Text).all, Item.Details.Scroll);
         Widgets.Invalidate (Item.Body_Text);
         Item.Scroll_Pending := False;
         Item.Scroll_Seen := Scroll_Of (Item);
      end if;

      --  What is moved and sized is the handlers' (see Listen); here only
      --  the size the corner asks for, which is the size it has, while it
      --  is not being dragged.
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
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
   end Update;

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
        and then Shown_Marks_Version (Item) /= Item.Marks_Saved
        and then not Is_Marking (Item)
      then
         declare
            Kept : Items.Marks.Mark_List;
         begin
            Get_Marks (Item, Kept);
            Items.Marks.Save_Marks (Store, Item.Details.Key, Kept);
         end;
         Item.Marks_Saved := Shown_Marks_Version (Item);
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
