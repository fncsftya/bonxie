with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with SDL3.Cursors;
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

   use type Docs.Version;
   use type Ada.Calendar.Time;
   use type SDL3.Events.Milliseconds;

   --  In points

   Outline       : constant Float := 1.0;
   Bar_Height    : constant Float := 32.0;
   Bar_Pad       : constant Float := 8.0;
   Button_Size   : constant Float := 24.0;
   Button_Gap    : constant Float := 4.0;
   Drag_Room     : constant Float := 32.0;
   --  Left of the title field before the buttons, to take hold of.
   Title_Size    : constant Float := 11.0;
   Title_Height  : constant Float := 26.0;
   Text_Size     : constant Float := 14.0;
   Measure       : constant Float := 2000.0;
   Status_Height : constant Float := 22.0;
   Status_Pad    : constant Float := 8.0;
   Corner_Size   : constant Float := 18.0;
   Mini_Width    : constant Float := 200.0;
   Mini_Height   : constant Float := 28.0;
   Mini_Gap      : constant Float := 4.0;
   Mini_Chars    : constant := 16;
   --  How many characters of a title the bar in the dock shows.
   Label_Height  : constant Float := 20.0;
   Url_Height    : constant Float := 30.0;

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
     (Ada.Calendar.Formatting.Image
        (Ada.Calendar.Formatting.Time_Of (1970, 1, 1, Time_Zone => 0)
         + Duration (Taken),
         Time_Zone => 0) (1 .. 10));
   --  As YYYY-MM-DD, in UTC.

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
      Widgets.Add (Item.Title_Area, Item.Title_Label);
      Widgets.Add (Item.Title_Bar, Item.Title_Field);
      Widgets.Add (Item.Title_Bar, Item.Spacer);
      Widgets.Add (Item.Title_Bar, Item.Minimize_Button);
      Widgets.Add (Item.Title_Bar, Item.Close_Button);
      Widgets.Add (Item.Frame, Item.Body_Text);
      Widgets.Add (Item.Frame, Item.Picture);
      Widgets.Add (Item.Frame, Item.Status_Bar);
      Widgets.Add (Item.Status_Bar, Item.Status);
      Widgets.Add (Item.Status_Bar, Item.Corner);
      Widgets.Add (Dock, Item.Mini);
      Widgets.Add (Item.Mini, Item.Mini_Title);
      Widgets.Add (Item.Mini, Item.Restore_Button);
      Widgets.Add (Item.Mini, Item.Mini_Close);

      --  The window: an outline round a column of the bar, the text and
      --  the status line, placed by its edges on the canvas.
      Panels.Set_Fill (Item.Frame, Colors.Foreground);
      Set_Position_Type (Widgets.Node (Item.Frame), Yoga.Absolute);
      Set_Flex_Direction (Widgets.Node (Item.Frame), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Frame), Yoga.All_Edges, Edge);

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
        (Item.Title_Field, UI.Line_Texts.System_UI, Title_Size);
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
      Labels.Set_Style (Item.Title_Label, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Title_Label, Colors.Background);
      Set_Flex_Grow (Widgets.Node (Item.Title_Label), 1.0);
      Set_Width (Widgets.Node (Item.Title_Label), 0.0);
      Set_Height (Widgets.Node (Item.Title_Label), Label_Height * Pixels);
      --  Nothing: the bar is held there.
      Set_Width (Widgets.Node (Item.Spacer), 0.0);
      Buttons.Set_Label (Item.Minimize_Button, "Min");
      Buttons.Set_Icon (Item.Minimize_Button, UI.Icons.Minimize);
      Buttons.Set_Label (Item.Close_Button, "Close");
      Buttons.Set_Icon (Item.Close_Button, UI.Icons.Close);
      Size (Item.Minimize_Button, Button_Size, Button_Size);
      Size (Item.Close_Button, Button_Size, Button_Size);

      Editors.Configure
        (Item.Body_Text, UI.Line_Texts.System_UI, Text_Size, Measure);
      Set_Flex_Grow (Widgets.Node (Item.Body_Text), 1.0);
      --  Its own outline is the window's at the sides.
      Set_Margin
        (Widgets.Node (Item.Body_Text), Yoga.Horizontal, -Edge);
      Set_Height (Widgets.Node (Item.Body_Text), 0.0);

      Set_Flex_Grow (Widgets.Node (Item.Picture), 1.0);
      Set_Height (Widgets.Node (Item.Picture), 0.0);

      Panels.Set_Fill
        (Item.Status_Bar,
         UI.Themes.Mix (Colors.Background, Colors.Foreground, 0.08));
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

      --  The bar in the dock.
      Panels.Set_Fill (Item.Mini, Bar);
      Size (Item.Mini, Mini_Width, Mini_Height);
      Set_Flex_Direction (Widgets.Node (Item.Mini), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Mini), Yoga.Center);
      Set_Padding (Widgets.Node (Item.Mini), Yoga.Left, Bar_Pad * Pixels);
      Set_Padding (Widgets.Node (Item.Mini), Yoga.Right, Mini_Gap * Pixels);
      Set_Gap (Widgets.Node (Item.Mini), Yoga.All_Gutters, Mini_Gap * Pixels);
      Labels.Set_Style (Item.Mini_Title, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Mini_Title, Colors.Background);
      Set_Flex_Grow (Widgets.Node (Item.Mini_Title), 1.0);
      Set_Width (Widgets.Node (Item.Mini_Title), 0.0);
      Set_Height (Widgets.Node (Item.Mini_Title), Label_Height * Pixels);
      Buttons.Set_Label (Item.Restore_Button, "Show");
      Buttons.Set_Icon (Item.Restore_Button, UI.Icons.Restore);
      Buttons.Set_Label (Item.Mini_Close, "Close");
      Buttons.Set_Icon (Item.Mini_Close, UI.Icons.Close);
      Size (Item.Restore_Button, Button_Size, Button_Size);
      Size (Item.Mini_Close, Button_Size, Button_Size);

      Widgets.Set_Visible (Item.Title_Field, False);
      Widgets.Set_Visible (Item.Picture, False);
      Widgets.Set_Visible (Item.Frame, False);
      Widgets.Set_Visible (Item.Mini, False);
   end Build;

   function Is_Assigned (Item : Window) return Boolean is (Item.Assigned);

   function Details (Item : Window) return Items.Info is (Item.Details);

   function Text (Item : Window) return String is
     (Docs.Whole (Item.Content_Doc));

   function Words (Item : Window) return Natural is (Item.Word_Count);

   function Status (Item : Window) return String is
     (Labels.Text (Item.Status));

   procedure Set_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0) is
   begin
      case To is
         when Waiting =>
            Labels.Set_Text (Item.Status, "Press Return to capture");
         when Busy =>
            Labels.Set_Text (Item.Status, "Capturing...");
         when Ready =>
            Item.Details.Captured_At := At_Time;
            UI.Widgets.Pictures.Set_File (Item.Picture, File);
            Labels.Set_Text (Item.Status, "Captured " & Day (At_Time));
         when Failed =>
            Labels.Set_Text
              (Item.Status, Fitted ("Failed: " & Detail));
      end case;
   end Set_Capture;

   function Box (Item : Window) return Items.Frame is
     ((Left   => Widgets.Left_Of (Item.Frame),
       Top    => Widgets.Top_Of (Item.Frame),
       Width  => Widgets.Width_Of (Item.Frame),
       Height => Widgets.Height_Of (Item.Frame)));

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
         Labels.Set_Text (Item.Status, Status_Text (Item.Word_Count));
      end if;
   end Show_Words;

   procedure Set_State (Item : in out Window; To : States) is
   begin
      Item.Details.State := To;
      if To /= Open then
         UI.Widgets.Pictures.Unload (Item.Picture);
      end if;
      Widgets.Set_Visible (Item.Frame, To = Open);
      Widgets.Set_Visible (Item.Mini, To = Minimized);
      Item.Was_Used := False;
   end Set_State;

   procedure Show_Kind (Item : in out Window);
   --  Make the text area the item's text, or its one line, the link; and
   --  show the picture of a source.

   procedure Show_Kind (Item : in out Window) is
      use Yoga.Nodes;
      Of_Source : constant Boolean := Item.Details.Kind = Source;
      Node : constant Yoga.Nodes.Node := Widgets.Node (Item.Body_Text);
   begin
      UI.Text_Areas.Set_Single_Line
        (Editors.Area (Item.Body_Text).all, Of_Source);
      Set_Flex_Grow (Node, (if Of_Source then 0.0 else 1.0));
      Set_Height (Node, (if Of_Source then Url_Height * Item.Pixels else 0.0));
      Widgets.Set_Visible (Item.Picture, Of_Source);
      Widgets.Request_Layout (Item.Body_Text);
   end Show_Kind;

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
      Text_Fields.Attach (Item.Title_Field, Item.Title_Doc'Unchecked_Access);
      Editors.Attach (Item.Body_Text, Item.Content_Doc'Unchecked_Access);
      Item.Title_Saved := Docs.State (Item.Title_Doc);
      Item.Title_Seen := Item.Title_Saved;
      Item.Content_Saved := Docs.State (Item.Content_Doc);
      Item.Content_Seen := Item.Content_Saved;
      Item.Frame_Dirty := False;
      Item.Editing := False;
      Widgets.Set_Visible (Item.Title_Area, True);
      Widgets.Set_Visible (Item.Title_Field, False);
      Show_Title (Item);
      Show_Kind (Item);
      UI.Widgets.Pictures.Set_File (Item.Picture, "");
      if Of_Item.Kind = Source then
         Item.Content_Version := Docs.Current (Item.Content_Doc);
         if Of_Item.Captured_At > 0 and then Picture_File /= "" then
            Set_Capture
              (Item, Ready, Picture_File, At_Time => Of_Item.Captured_At);
         else
            Set_Capture (Item, Waiting);
         end if;
      else
         Show_Words (Item);
      end if;
      Set_State (Item, Of_Item.State);
      if Item.Placed_Once then
         Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
      end if;
   end Assign;

   procedure Release (Item : in out Window) is
   begin
      UI.Widgets.Pictures.Unload (Item.Picture);
      Widgets.Set_Visible (Item.Frame, False);
      Widgets.Set_Visible (Item.Mini, False);
      Item.Assigned := False;
      Item.Frame_Dirty := False;
      Item.Was_Used := False;
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
        or else Item.Editing
        or else Widgets.Has_Focus (Item.Body_Text);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Widgets.Raise_To_Front (Item.Frame);
      end if;
      Item.Was_Used := Used;

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
         if Entered then
            Action := Capture;
            return;
         end if;
      end if;
      if Item.Editing then
         Text_Fields.Take_Return (Item.Title_Field, Entered);
         if Entered or else not Widgets.Has_Focus (Item.Title_Field) then
            End_Edit (Item);
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
         Buttons.Take_Click (Item.Restore_Button, Clicked);
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
        or else Widgets.Has_Focus (Item.Body_Text);
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
