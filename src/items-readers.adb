with Ada.Strings;
with SDL3.Cursors;
with UI.Boxes;
with UI.Icons;
with UI.Line_Texts;
with Yoga.Nodes;

package body Items.Readers is

   package Widgets renames UI.Widgets;
   package Panels renames UI.Widgets.Panels;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;
   package Grips renames UI.Widgets.Grips;
   package Sliders renames UI.Widgets.Sliders;
   package Pictures renames UI.Widgets.Pictures;

   --  In points

   Outline       : constant Float := 1.0;
   Bar_Height    : constant Float := 28.0;
   Bar_Pad       : constant Float := 6.0;
   Tag_Size      : constant Float := 9.0;
   Tag_Gap       : constant Float := 7.0;
   Bar_Icon_Size : constant Float := 11.0;
   Button_Size   : constant Float := 18.0;
   Button_Gap    : constant Float := 4.0;
   Label_Height  : constant Float := 20.0;
   Status_Height : constant Float := 26.0;
   Status_Pad    : constant Float := 10.0;
   Corner_Size   : constant Float := 18.0;
   Row_Height    : constant Float := 19.0;
   Slider_Width  : constant Float := 72.0;
   Percent_Width : constant Float := 40.0;
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;
   Pin_Icon_Size : constant Float := 12.0;

   function Unit (Value : Float) return Float is
     (Float'Min (1.0, Float'Max (0.0, Value)));
   --  Within the picture.

   function Fitted (Message : String) return String is
     (Message (Message'First ..
               Message'First - 1
               + Natural'Min (Message'Length, Labels.Text_Capacity)));
   --  As much as a label takes.

   procedure Build
     (Item    : in out Reader;
      Parent  : in out Widgets.Widget'Class;
      Bar     : UI.Themes.Slot;
      Density : Float;
      Pinned  : Boolean := False)
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
      Item.Pinned := Pinned;
      Widgets.Add (Parent, Item.Frame);
      Widgets.Add (Item.Frame, Item.Title_Bar);
      Widgets.Add (Item.Title_Bar, Item.Tag);
      Widgets.Add (Item.Title_Bar, Item.Title_Label);
      Widgets.Add (Item.Title_Bar, Item.Pin_Button);
      Widgets.Add (Item.Title_Bar, Item.Close_Button);
      Widgets.Add (Item.Frame, Item.Picture);
      Widgets.Add (Item.Frame, Item.Status_Bar);
      Widgets.Add (Item.Status_Bar, Item.Tools);
      Widgets.Add (Item.Tools, Item.Cursor_Button);
      Widgets.Add (Item.Tools, Item.Marker_Button);
      Widgets.Add (Item.Tools, Item.Eraser_Button);
      Widgets.Add (Item.Status_Bar, Item.Zoom_Slider);
      Widgets.Add (Item.Status_Bar, Item.Zoom_Label);
      Widgets.Add (Item.Status_Bar, Item.Status);
      Widgets.Add (Item.Status_Bar, Item.Corner);

      --  An outline round a column of the bar, the picture and the status
      --  line: placed by its edges, or filling its parent.
      Panels.Set_Fill (Item.Frame, UI.Themes.Border);
      Set_Flex_Direction (Widgets.Node (Item.Frame), Yoga.Column);
      Set_Padding (Widgets.Node (Item.Frame), Yoga.All_Edges, Edge);
      --  A window casts a shadow, inside its box at the right and foot;
      --  the pane does not.
      if not Pinned then
         Panels.Set_Shadow (Item.Frame, UI.Themes.Shadow);
         Set_Padding
           (Widgets.Node (Item.Frame), Yoga.Right,
            Edge + UI.Boxes.Offset (Pixels));
         Set_Padding
           (Widgets.Node (Item.Frame), Yoga.Bottom,
            Edge + UI.Boxes.Offset (Pixels));
      end if;
      if Pinned then
         Set_Flex_Grow (Widgets.Node (Item.Frame), 1.0);
         Set_Height (Widgets.Node (Item.Frame), 0.0);
      else
         Set_Position_Type (Widgets.Node (Item.Frame), Yoga.Absolute);
      end if;

      Grips.Set_Fill (Item.Title_Bar, Bar);
      Set_Height (Widgets.Node (Item.Title_Bar), Bar_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Title_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Title_Bar), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Title_Bar), Yoga.Horizontal, Bar_Pad * Pixels);
      Set_Gap
        (Widgets.Node (Item.Title_Bar), Yoga.All_Gutters,
         Button_Gap * Pixels);
      if Pinned then
         Grips.Set_Wanted_Cursor (Item.Title_Bar, SDL3.Cursors.Default);
      end if;
      Panels.Set_Fill (Item.Tag, UI.Themes.Bar);
      Size (Item.Tag, Tag_Size, Tag_Size);
      Set_Flex_Shrink (Widgets.Node (Item.Tag), 0.0);
      Set_Margin
        (Widgets.Node (Item.Tag), Yoga.Right, (Tag_Gap - Button_Gap) * Pixels);
      Labels.Set_Style (Item.Title_Label, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Title_Label, UI.Themes.Bar_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Title_Label), 1.0);
      Set_Width (Widgets.Node (Item.Title_Label), 0.0);
      Set_Height (Widgets.Node (Item.Title_Label), Label_Height * Pixels);
      Buttons.Set_Label (Item.Pin_Button, "Pin");
      Buttons.Set_Icon (Item.Pin_Button, UI.Icons.Pin);
      Buttons.Set_Icon_Size (Item.Pin_Button, Pin_Icon_Size);
      Buttons.Set_Selected (Item.Pin_Button, Pinned);
      Buttons.Set_Label (Item.Close_Button, "Close");
      Buttons.Set_Icon (Item.Close_Button, UI.Icons.Close);
      Buttons.Set_Icon_Size (Item.Close_Button, Bar_Icon_Size);
      Size (Item.Pin_Button, Button_Size, Button_Size);
      Size (Item.Close_Button, Button_Size, Button_Size);

      Set_Flex_Grow (Widgets.Node (Item.Picture), 1.0);
      Set_Height (Widgets.Node (Item.Picture), 0.0);

      Panels.Set_Fill (Item.Status_Bar, UI.Themes.Tint);
      Panels.Set_Border (Item.Status_Bar, UI.Themes.Border);
      Set_Margin (Widgets.Node (Item.Status_Bar), Yoga.Horizontal, -Edge);
      Set_Margin (Widgets.Node (Item.Status_Bar), Yoga.Bottom, -Edge);
      Set_Height (Widgets.Node (Item.Status_Bar), Status_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Status_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Status_Bar), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Status_Bar), Yoga.Left, Status_Pad * Pixels);
      Set_Gap
        (Widgets.Node (Item.Status_Bar), Yoga.All_Gutters,
         Button_Gap * Pixels);

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
      Size (Item.Cursor_Button, Button_Size, Row_Height);
      Size (Item.Marker_Button, Button_Size, Row_Height);
      Size (Item.Eraser_Button, Button_Size, Row_Height);
      Size (Item.Tools, Tools_Width, Row_Height);

      Size (Item.Zoom_Slider, Slider_Width, Row_Height);
      Size (Item.Zoom_Label, Percent_Width, Label_Height);
      Set_Flex_Grow (Widgets.Node (Item.Status), 1.0);
      Set_Width (Widgets.Node (Item.Status), 0.0);
      Set_Height (Widgets.Node (Item.Status), Label_Height * Pixels);
      Grips.Set_Shape (Item.Corner, Grips.Corner);
      Grips.Set_Wanted_Cursor (Item.Corner, SDL3.Cursors.Resize);
      Size (Item.Corner, Corner_Size, Status_Height);

      Widgets.Set_Visible (Item.Corner, not Pinned);
      Widgets.Set_Visible (Item.Frame, False);
   end Build;

   function Is_Assigned (Item : Reader) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Reader; To : UI.Themes.Slot) is
   begin
      Panels.Set_Fill (Item.Tag, To);
   end Set_Tag;

   function Details (Item : Reader) return Items.Info is (Item.Details);

   function Recognized_Count (Item : Reader) return Natural is
     (Item.Recognized.Count);

   function Selected_Text (Item : Reader) return String is
     (Pictures.Selected_Text (Item.Picture));

   function Marks_Version (Item : Reader) return Natural is
     (Pictures.Marks_Version (Item.Picture));

   function Is_Marking (Item : Reader) return Boolean is
     (Pictures.Is_Marking (Item.Picture));

   function Tool (Item : Reader) return Pictures.Tools is
     (Pictures.Tool (Item.Picture));

   function Zoom (Item : Reader) return Float is (Item.Details.Zoom);

   function Picture_Contains
     (Item : Reader; X, Y : Float) return Boolean is
     (Widgets.Contains (Item.Picture, X, Y));

   function Is_Over_Selection
     (Item : Reader; X, Y : Float) return Boolean is
     (Pictures.Is_Over_Selection (Item.Picture, X, Y));

   function Has_Words (Item : Reader) return Boolean is
     (Pictures.Has_Words (Item.Picture));

   procedure Select_All (Item : in out Reader) is
   begin
      Pictures.Select_All (Item.Picture);
   end Select_All;

   procedure Copy (Item : Reader) is
   begin
      Pictures.Copy (Item.Picture);
   end Copy;

   function Box (Item : Reader) return Items.Frame is
     ((Left   => Widgets.Left_Of (Item.Frame),
       Top    => Widgets.Top_Of (Item.Frame),
       Width  => Widgets.Width_Of (Item.Frame),
       Height => Widgets.Height_Of (Item.Frame)));

   procedure Get_Marks (Item : Reader; Into : out Items.Mark_List) is
   begin
      Into.Count := Pictures.Mark_Count (Item.Picture);
      for Index in 1 .. Into.Count loop
         declare
            Each : constant Pictures.Mark :=
              Pictures.Mark_At (Item.Picture, Index);
         begin
            Into.Marks (Index) :=
              (Left => Each.Left, Right => Each.Right, Y => Each.Y);
         end;
      end loop;
   end Get_Marks;

   procedure Set_Marks (Item : in out Reader; Kept : Items.Mark_List) is
      Shown : Pictures.Mark_Array (1 .. Kept.Count);
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
      Pictures.Set_Marks (Item.Picture, Shown);
   end Set_Marks;

   procedure Select_Tool (Item : in out Reader; To : Pictures.Tools) is
   begin
      Pictures.Set_Tool (Item.Picture, To);
      Buttons.Set_Selected (Item.Cursor_Button, To = Pictures.Pointer);
      Buttons.Set_Selected (Item.Marker_Button, To = Pictures.Highlighter);
      Buttons.Set_Selected (Item.Eraser_Button, To = Pictures.Eraser);
   end Select_Tool;

   procedure Set_Zoom (Item : in out Reader; To : Float) is
   begin
      Item.Details.Zoom := To;
      Pictures.Set_Zoom (Item.Picture, To);
      Sliders.Set_Value (Item.Zoom_Slider, Items.To_Slider (To));
      Labels.Set_Text (Item.Zoom_Label, Items.Percent (To));
   end Set_Zoom;

   procedure Set_Title (Item : in out Reader; To : String) is
   begin
      Item.Details.Title := Projects.Titles.To_Bounded_String
        (To, Ada.Strings.Right);
      Labels.Set_Text (Item.Title_Label, Fitted (To));
   end Set_Title;

   procedure Show_Status (Item : in out Reader);
   --  Say whether there is a picture to show.

   procedure Show_Status (Item : in out Reader) is
   begin
      Labels.Set_Text
        (Item.Status,
         (if Item.Details.Captured_At > 0 then ""
          else "Not captured yet"));
   end Show_Status;

   procedure Clear_Recognized (Item : in out Reader);
   --  Forget the words, as of a picture that is not the one shown.

   procedure Clear_Recognized (Item : in out Reader) is
   begin
      Pictures.Set_Words (Item.Picture, null);
      Item.Recognized.Count := 0;
      Item.Recognized.Length := 0;
      Item.Recognized.Truncated := False;
   end Clear_Recognized;

   procedure Set_Recognized
     (Item : in out Reader; Found : Vision.Result) is
   begin
      Item.Recognized := Found;
      Pictures.Set_Words (Item.Picture, Item.Recognized'Unchecked_Access);
   end Set_Recognized;

   procedure Set_Picture
     (Item : in out Reader; File : String; At_Time : Projects.Seconds) is
   begin
      Item.Details.Captured_At := At_Time;
      Clear_Recognized (Item);
      Pictures.Clear_Marks (Item.Picture);
      Pictures.Set_File (Item.Picture, File);
      Show_Status (Item);
      if Item.Details.State = Open then
         Pictures.Load_Soon (Item.Picture, Urgent => True);
      end if;
   end Set_Picture;

   procedure Set_State (Item : in out Reader; To : States) is
   begin
      Item.Details.State := To;
      if To /= Open then
         Select_Tool (Item, Pictures.Pointer);
         Pictures.Unload (Item.Picture);
      else
         Pictures.Load_Soon (Item.Picture, Urgent => True);
      end if;
      Widgets.Set_Visible (Item.Frame, To = Open);
      Item.Was_Used := False;
   end Set_State;

   procedure Assign
     (Item         : in out Reader;
      Of_Item      : Items.Info;
      Where        : Items.Frame;
      Picture_File : String := "") is
   begin
      Item.Assigned := True;
      Item.Details := Of_Item;
      Item.Details.Where := Items.Sized
        ((Where with delta
            Width  => Float'Max (Least_Width, Where.Width),
            Height => Float'Max (Least_Height, Where.Height)));
      Item.Details.State := Closed;
      Item.Details.Scroll := 0.0;
      Item.Details.Scroll_Across := 0.0;
      Item.Resizing := False;
      Set_Title (Item, Projects.Titles.To_String (Of_Item.Title));
      Clear_Recognized (Item);
      Pictures.Clear_Marks (Item.Picture);
      Pictures.Set_File (Item.Picture, "");
      Select_Tool (Item, Pictures.Pointer);
      Set_Zoom (Item, Of_Item.Zoom);
      if Of_Item.Captured_At > 0 and then Picture_File /= "" then
         Pictures.Set_File (Item.Picture, Picture_File);
      end if;
      Show_Status (Item);
      Set_State (Item, Closed);
   end Assign;

   procedure Release (Item : in out Reader) is
   begin
      Clear_Recognized (Item);
      Pictures.Unload (Item.Picture);
      Widgets.Set_Visible (Item.Frame, False);
      Item.Assigned := False;
      Item.Was_Used := False;
   end Release;

   procedure Place (Item : in out Reader) is
      use Yoga.Nodes;
      Where  : Items.Frame renames Item.Details.Where;
      Pixels : constant Float := Item.Pixels;
   begin
      if Item.Pinned then
         return;
      end if;
      --  On whole pixels, so that its edges, and the borders in them, are
      --  the same wherever it is.
      Set_Position
        (Widgets.Node (Item.Frame), Yoga.Left,
         Float'Rounding (Where.Left * Pixels));
      Set_Position
        (Widgets.Node (Item.Frame), Yoga.Top,
         Float'Rounding (Where.Top * Pixels));
      Set_Width
        (Widgets.Node (Item.Frame), Float'Rounding (Where.Width * Pixels));
      Set_Height
        (Widgets.Node (Item.Frame), Float'Rounding (Where.Height * Pixels));
      Widgets.Request_Layout (Item.Frame);
   end Place;

   procedure Set_Frame (Item : in out Reader; Where : Items.Frame) is
   begin
      Item.Details.Where := Items.Sized
        ((Where with delta
            Width  => Float'Max (Least_Width, Where.Width),
            Height => Float'Max (Least_Height, Where.Height)));
      Place (Item);
   end Set_Frame;

   procedure Bring_To_Front (Item : in out Reader) is
   begin
      Widgets.Raise_To_Front (Item.Frame);
   end Bring_To_Front;

   function Is_Dragging (Item : Reader) return Boolean is
     (Grips.Is_Dragging (Item.Title_Bar)
      or else Grips.Is_Dragging (Item.Corner));

   procedure Poll (Item : in out Reader; Action : out Actions) is
      Across, Down : Float;
      Clicked      : Boolean;
      Changed      : Boolean;
      Used         : Boolean;
   begin
      Action := None;

      --  Moved and sized, in points.
      Grips.Take_Drag (Item.Title_Bar, Across, Down);
      if not Item.Pinned and then (Across /= 0.0 or else Down /= 0.0) then
         Item.Details.Where.Left := Item.Details.Where.Left + Across;
         Item.Details.Where.Top := Item.Details.Where.Top + Down;
         Place (Item);
      end if;
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Grips.Take_Drag (Item.Corner, Across, Down);
      if Across /= 0.0 or else Down /= 0.0 then
         Item.Raw_Width := Item.Raw_Width + Across;
         Item.Raw_Height := Item.Raw_Height + Down;
         Item.Details.Where := Items.Sized
           ((Item.Details.Where with delta
               Width  => Float'Max (Least_Width, Item.Raw_Width),
               Height => Float'Max (Least_Height, Item.Raw_Height)));
         Place (Item);
      end if;
      Item.Resizing := Grips.Is_Dragging (Item.Corner);

      --  Raised when it starts to be used.
      Used := Is_Dragging (Item)
              or else Sliders.Is_Dragging (Item.Zoom_Slider);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Widgets.Raise_To_Front (Item.Frame);
      end if;
      Item.Was_Used := Used;

      if Item.Details.State /= Open then
         return;
      end if;

      Sliders.Take_Change (Item.Zoom_Slider, Changed);
      if Changed then
         Set_Zoom (Item, Items.From_Slider (Sliders.Value (Item.Zoom_Slider)));
      end if;
      Buttons.Take_Click (Item.Cursor_Button, Clicked);
      if Clicked then
         Select_Tool (Item, Pictures.Pointer);
      end if;
      Buttons.Take_Click (Item.Marker_Button, Clicked);
      if Clicked then
         Select_Tool (Item, Pictures.Highlighter);
      end if;
      Buttons.Take_Click (Item.Eraser_Button, Clicked);
      if Clicked then
         Select_Tool (Item, Pictures.Eraser);
      end if;
      Buttons.Take_Click (Item.Pin_Button, Clicked);
      if Clicked then
         Action := Toggle_Pin;
         return;
      end if;
      Buttons.Take_Click (Item.Close_Button, Clicked);
      if Clicked then
         Action := Close;
      end if;
   end Poll;

end Items.Readers;
