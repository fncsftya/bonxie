with Items.Sources;
with Ada.Strings;
with Icon_Set;
with Yoga.Nodes;

package body Items.Readers is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Sliders renames Pomarine.Widgets.Sliders;
   package Pictures renames Pomarine.Widgets.Pictures;

   --  In points

   Button_Size   : constant Float := Frames.Button_Size;
   Button_Gap    : constant Float := Frames.Button_Gap;
   Label_Height  : constant Float := Frames.Label_Height;
   Row_Height    : constant Float := 19.0;
   Slider_Width  : constant Float := 72.0;
   Percent_Width : constant Float := 40.0;
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;
   Pin_Icon_Size : constant Float := 12.0;

   procedure Build
     (Item    : in out Reader;
      Parent  : in out Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float;
      Pinned  : Boolean := False)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Density;

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;
   begin
      Item.Pixels := Pixels;
      Item.Pinned := Pinned;
      Frames.Build
        (Item.Chrome, Parent, Bar, Pixels,
         Placement => (if Pinned then Frames.Filling else Frames.Floating));
      Frames.Add_Title_Button (Item.Chrome, Item.Pin_Button);
      Frames.Add_Content (Item.Chrome, Item.Picture);
      Frames.Add_Status_Item (Item.Chrome, Item.Tools);
      Widgets.Add (Item.Tools, Item.Cursor_Button);
      Widgets.Add (Item.Tools, Item.Marker_Button);
      Widgets.Add (Item.Tools, Item.Eraser_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Slider);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Label);
      Frames.Add_Status_Item (Item.Chrome, Item.Status);

      Buttons.Set_Label (Item.Pin_Button, "Pin");
      Buttons.Set_Icon (Item.Pin_Button, Icon_Set.Pin);
      Buttons.Set_Icon_Size (Item.Pin_Button, Pin_Icon_Size);
      Buttons.Set_Selected (Item.Pin_Button, Pinned);
      Size (Item.Pin_Button, Button_Size, Button_Size);

      Set_Flex_Grow (Widgets.Node (Item.Picture), 1.0);
      Set_Height (Widgets.Node (Item.Picture), 0.0);

      Set_Flex_Direction (Widgets.Node (Item.Tools), Yoga.Row);
      Set_Gap
        (Widgets.Node (Item.Tools), Yoga.All_Gutters, Button_Gap * Pixels);
      Buttons.Set_Label (Item.Cursor_Button, "Ptr");
      Buttons.Set_Icon (Item.Cursor_Button, Icon_Set.Cursor);
      Buttons.Set_Label (Item.Marker_Button, "Mark");
      Buttons.Set_Icon (Item.Marker_Button, Icon_Set.Highlighter);
      Buttons.Set_Label (Item.Eraser_Button, "Rub");
      Buttons.Set_Icon (Item.Eraser_Button, Icon_Set.Eraser);
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
   end Build;

   function Is_Assigned (Item : Reader) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Reader; To : Pomarine.Themes.Slot) is
   begin
      Frames.Set_Tag (Item.Chrome, To);
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
     ((Left   => Frames.Left_Of (Item.Chrome),
       Top    => Frames.Top_Of (Item.Chrome),
       Width  => Frames.Width_Of (Item.Chrome),
       Height => Frames.Height_Of (Item.Chrome)));

   procedure Get_Marks (Item : Reader; Into : out Items.Marks.Mark_List) is
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

   procedure Set_Marks (Item : in out Reader; Kept : Items.Marks.Mark_List) is
      Shown : Pictures.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Marks.Mark renames Kept.Marks (Index);
         begin
            Shown (Index) :=
              Pictures.Clamped_Mark
                (Each.Left, Each.Right, Each.Y);
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
      Sliders.Set_Value (Item.Zoom_Slider, Items.Sources.To_Slider (To));
      Labels.Set_Text (Item.Zoom_Label, Items.Sources.Percent (To));
   end Set_Zoom;

   procedure Set_Title (Item : in out Reader; To : String) is
   begin
      Item.Details.Title := Projects.Titles.To_Bounded_String
        (To, Ada.Strings.Right);
      Frames.Set_Title (Item.Chrome, To);
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
      Frames.Set_Shown (Item.Chrome, To = Open, False);
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
      Frames.Set_Shown (Item.Chrome, False, False);
      Item.Assigned := False;
      Item.Was_Used := False;
   end Release;

   procedure Place (Item : in out Reader) is
      Where  : Items.Frame renames Item.Details.Where;
      Pixels : constant Float := Item.Pixels;
   begin
      if Item.Pinned then
         return;
      end if;
      --  On whole pixels, so that its edges, and the borders in them, are
      --  the same wherever it is.
      Frames.Place
        (Item.Chrome,
         Float'Rounding (Where.Left * Pixels),
         Float'Rounding (Where.Top * Pixels),
         Float'Rounding (Where.Width * Pixels),
         Float'Rounding (Where.Height * Pixels));
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
      Frames.Raise_To_Front (Item.Chrome);
   end Bring_To_Front;

   function Is_Dragging (Item : Reader) return Boolean is
     (Frames.Is_Dragging (Item.Chrome));

   procedure Poll (Item : in out Reader; Action : out Actions) is
      Across, Down : Float;
      Clicked      : Boolean;
      Changed      : Boolean;
      Used         : Boolean;
   begin
      Action := None;

      --  Moved and sized, in points.
      Frames.Take_Move (Item.Chrome, Across, Down);
      if not Item.Pinned and then (Across /= 0.0 or else Down /= 0.0) then
         Item.Details.Where.Left := Item.Details.Where.Left + Across;
         Item.Details.Where.Top := Item.Details.Where.Top + Down;
         Place (Item);
      end if;
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Frames.Take_Size (Item.Chrome, Across, Down);
      if Across /= 0.0 or else Down /= 0.0 then
         Item.Raw_Width := Item.Raw_Width + Across;
         Item.Raw_Height := Item.Raw_Height + Down;
         Item.Details.Where := Items.Sized
           ((Item.Details.Where with delta
               Width  => Float'Max (Least_Width, Item.Raw_Width),
               Height => Float'Max (Least_Height, Item.Raw_Height)));
         Place (Item);
      end if;
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);

      --  Raised when it starts to be used.
      Used := Is_Dragging (Item)
              or else Sliders.Is_Dragging (Item.Zoom_Slider);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Frames.Raise_To_Front (Item.Chrome);
      end if;
      Item.Was_Used := Used;

      if Item.Details.State /= Open then
         return;
      end if;

      Sliders.Take_Change (Item.Zoom_Slider, Changed);
      if Changed then
         Set_Zoom
           (Item,
            Items.Sources.From_Slider (Sliders.Value (Item.Zoom_Slider)));
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
      Frames.Take_Close (Item.Chrome, Clicked);
      if Clicked then
         Action := Close;
      end if;
   end Poll;

end Items.Readers;
