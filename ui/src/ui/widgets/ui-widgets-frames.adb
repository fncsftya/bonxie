with SDL3.Cursors;
with System;
with UI.Boxes;
with UI.Icons;
with UI.Line_Texts;
with UI.Text_Areas;
with Yoga.Nodes;

package body UI.Widgets.Frames is

   use type System.Address;

   --  In points

   Bar_Pad       : constant Float := 6.0;
   Bar_Icon_Size : constant Float := 11.0;
   Tag_Size      : constant Float := 9.0;
   Tag_Gap       : constant Float := 7.0;
   --  The square of a colour before the title, and after it.
   Drag_Room     : constant Float := 32.0;
   --  Left of the title field before the buttons, to take hold of.
   Title_Size    : constant Float := 12.0;
   Title_Height  : constant Float := 20.0;
   Status_Pad    : constant Float := 10.0;
   Mini_Width    : constant Float := 200.0;
   Mini_Height   : constant Float := 28.0;
   Mini_Gap      : constant Float := 4.0;
   Mini_Chars    : constant := 16;
   --  How many characters of a title the bar in the dock shows.

   function Edge (Item : Frame) return Float is
     (UI.Boxes.Edge (Item.Pixels * Outline));
   --  Whole pixels: a border that is not is a pixel more or less where it
   --  is drawn, or none.

   function Shortened (Title : String) return String is
     (if Title'Length <= Mini_Chars then Title
      else Title (Title'First .. Title'First + Mini_Chars - 1) & "..");
   --  For the bar in the dock.

   procedure Size
     (Part : in out Widget'Class; Wide, High : Float; Pixels : Float) is
   begin
      Yoga.Nodes.Set_Width (Node (Part), Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Part), High * Pixels);
   end Size;

   procedure Build
     (Item           : in out Frame;
      Parent         : in out Widget'Class;
      Bar            : Themes.Slot;
      Pixels         : Float;
      Placement      : Placements := Floating;
      Editable_Title : Boolean := False;
      Dock           : access Widget'Class := null)
   is
      use Yoga.Nodes;
   begin
      Item.Pixels := Pixels;
      Item.Scale := 1.0;
      Item.Editable := Editable_Title;
      Item.Docked := Dock /= null;
      Item.Floating := Placement = Floating;
      Item.Editing := False;

      Add (Parent, Item.Outline_Panel);
      Add (Item.Outline_Panel, Item.Title_Bar);
      if Editable_Title then
         Add (Item.Title_Bar, Item.Title_Area);
         Add (Item.Title_Area, Item.Tag);
         Add (Item.Title_Area, Item.Title_Label);
         Add (Item.Title_Bar, Item.Title_Field);
         Add (Item.Title_Bar, Item.Spacer);
      else
         Add (Item.Title_Bar, Item.Tag);
         Add (Item.Title_Bar, Item.Title_Label);
      end if;
      if Item.Docked then
         Add (Item.Title_Bar, Item.Minimize_Button);
      end if;
      Add (Item.Title_Bar, Item.Close_Button);
      Add (Item.Outline_Panel, Item.Status_Bar);
      Add (Item.Status_Bar, Item.Corner);
      if Item.Docked then
         Add (Dock.all, Item.Mini);
         Add (Item.Mini, Item.Mini_Area);
         Add (Item.Mini_Area, Item.Mini_Title);
         Add (Item.Mini, Item.Mini_Close);
      end if;

      --  An outline round a column of the bar, the content and the status
      --  line: placed by its edges, or filling its parent. Its outline is
      --  its fill, round what is in it; a window casts a shadow, inside
      --  its box at the right and the foot.
      Panels.Set_Fill (Item.Outline_Panel, Themes.Border);
      Set_Flex_Direction (Node (Item.Outline_Panel), Yoga.Column);
      Set_Padding (Node (Item.Outline_Panel), Yoga.All_Edges, Edge (Item));
      if Item.Floating then
         Panels.Set_Shadow (Item.Outline_Panel, Themes.Shadow);
         Set_Position_Type (Node (Item.Outline_Panel), Yoga.Absolute);
         Set_Padding
           (Node (Item.Outline_Panel), Yoga.Right,
            Edge (Item) + UI.Boxes.Offset (Pixels));
         Set_Padding
           (Node (Item.Outline_Panel), Yoga.Bottom,
            Edge (Item) + UI.Boxes.Offset (Pixels));
      else
         Set_Flex_Grow (Node (Item.Outline_Panel), 1.0);
         Set_Height (Node (Item.Outline_Panel), 0.0);
      end if;

      Grips.Set_Fill (Item.Title_Bar, Bar);
      Set_Flex_Direction (Node (Item.Title_Bar), Yoga.Row);
      Set_Align_Items (Node (Item.Title_Bar), Yoga.Center);
      Set_Gap
        (Node (Item.Title_Bar), Yoga.All_Gutters, Button_Gap * Pixels);
      if not Item.Floating then
         Grips.Set_Wanted_Cursor (Item.Title_Bar, SDL3.Cursors.Default);
      end if;
      Panels.Set_Fill (Item.Tag, Themes.Bar);
      Set_Flex_Shrink (Node (Item.Tag), 0.0);
      Labels.Set_Style (Item.Title_Label, Line_Texts.Strong);
      Labels.Set_Ink (Item.Title_Label, Themes.Bar_Ink);
      Set_Flex_Grow (Node (Item.Title_Label), 1.0);
      Set_Width (Node (Item.Title_Label), 0.0);
      if Editable_Title then
         Text_Fields.Configure
           (Item.Title_Field, Line_Texts.Interface_Font, Title_Size);
         Set_Flex_Grow (Node (Item.Title_Field), 1.0);
         Set_Width (Node (Item.Title_Field), 0.0);
         --  The title is text, in the field's place, until it is to be
         --  edited.
         Grips.Set_Hover_Outline (Item.Title_Area, Themes.Background);
         Set_Flex_Grow (Node (Item.Title_Area), 1.0);
         Set_Width (Node (Item.Title_Area), 0.0);
         Set_Flex_Direction (Node (Item.Title_Area), Yoga.Row);
         Set_Align_Items (Node (Item.Title_Area), Yoga.Center);
         --  Nothing: the bar is held there.
         Set_Width (Node (Item.Spacer), 0.0);
      end if;
      if Item.Docked then
         Buttons.Set_Label (Item.Minimize_Button, "Min");
         Buttons.Set_Icon (Item.Minimize_Button, Icons.Minimize);
         Buttons.Set_Icon_Size (Item.Minimize_Button, Bar_Icon_Size);
      end if;
      Buttons.Set_Label (Item.Close_Button, "Close");
      Buttons.Set_Icon (Item.Close_Button, Icons.Close);
      Buttons.Set_Icon_Size (Item.Close_Button, Bar_Icon_Size);
      Set_Scale (Item, 1.0);

      --  Its outline over the window's at the sides and the foot, a line
      --  between it and what is above.
      Panels.Set_Fill (Item.Status_Bar, Themes.Tint);
      Panels.Set_Border (Item.Status_Bar, Themes.Border);
      Set_Margin (Node (Item.Status_Bar), Yoga.Horizontal, -Edge (Item));
      Set_Margin (Node (Item.Status_Bar), Yoga.Bottom, -Edge (Item));
      Set_Height (Node (Item.Status_Bar), Status_Height * Pixels);
      Set_Flex_Direction (Node (Item.Status_Bar), Yoga.Row);
      Set_Align_Items (Node (Item.Status_Bar), Yoga.Center);
      Set_Padding (Node (Item.Status_Bar), Yoga.Left, Status_Pad * Pixels);
      Set_Gap
        (Node (Item.Status_Bar), Yoga.All_Gutters, Button_Gap * Pixels);
      Grips.Set_Shape (Item.Corner, Grips.Corner);
      Grips.Set_Wanted_Cursor (Item.Corner, SDL3.Cursors.Resize);
      Size (Item.Corner, Corner_Size, Status_Height, Pixels);
      Set_Visible (Item.Corner, Item.Floating);

      if Item.Docked then
         --  The bar in the dock.
         Panels.Set_Fill (Item.Mini, Bar);
         Size (Item.Mini, Mini_Width, Mini_Height, Pixels);
         Set_Flex_Direction (Node (Item.Mini), Yoga.Row);
         Set_Align_Items (Node (Item.Mini), Yoga.Center);
         Set_Padding (Node (Item.Mini), Yoga.Right, Mini_Gap * Pixels);
         Set_Gap (Node (Item.Mini), Yoga.All_Gutters, Mini_Gap * Pixels);
         --  The whole title is to click, to bring the window back.
         Grips.Set_Hover_Outline (Item.Mini_Area, Themes.Background);
         Grips.Set_Wanted_Cursor (Item.Mini_Area, SDL3.Cursors.Pointer);
         Set_Flex_Grow (Node (Item.Mini_Area), 1.0);
         Set_Width (Node (Item.Mini_Area), 0.0);
         Set_Height (Node (Item.Mini_Area), Mini_Height * Pixels);
         Set_Flex_Direction (Node (Item.Mini_Area), Yoga.Row);
         Set_Align_Items (Node (Item.Mini_Area), Yoga.Center);
         Set_Padding (Node (Item.Mini_Area), Yoga.Left, Bar_Pad * Pixels);
         Labels.Set_Style (Item.Mini_Title, Line_Texts.Strong);
         Labels.Set_Ink (Item.Mini_Title, Themes.Bar_Ink);
         Set_Flex_Grow (Node (Item.Mini_Title), 1.0);
         Set_Width (Node (Item.Mini_Title), 0.0);
         Set_Height (Node (Item.Mini_Title), Label_Height * Pixels);
         Buttons.Set_Label (Item.Mini_Close, "Close");
         Buttons.Set_Icon (Item.Mini_Close, Icons.Close);
         Buttons.Set_Icon_Size (Item.Mini_Close, Bar_Icon_Size);
         Size (Item.Mini_Close, Button_Size, Button_Size, Pixels);
         Set_Visible (Item.Mini, False);
      end if;

      if Editable_Title then
         Set_Visible (Item.Title_Field, False);
      end if;
      Set_Visible (Item.Outline_Panel, False);
   end Build;

   procedure Add_Title_Button
     (Item : in out Frame; Button : in out Widget'Class) is
   begin
      Add_Before (Item.Title_Bar, Button, Item.Close_Button);
   end Add_Title_Button;

   procedure Add_Content
     (Item : in out Frame; Part : in out Widget'Class) is
   begin
      Add_Before (Item.Outline_Panel, Part, Item.Status_Bar);
   end Add_Content;

   procedure Add_Status_Item
     (Item : in out Frame; Part : in out Widget'Class) is
   begin
      Add_Before (Item.Status_Bar, Part, Item.Corner);
   end Add_Status_Item;

   procedure Add_Over_Content
     (Item : in out Frame; Part : in out Widget'Class) is
   begin
      Add (Item.Outline_Panel, Part);
   end Add_Over_Content;

   procedure Add_Over_Status
     (Item : in out Frame; Part : in out Widget'Class) is
   begin
      Add (Item.Status_Bar, Part);
   end Add_Over_Status;

   procedure Set_Title (Item : in out Frame; To : String) is
   begin
      Labels.Set_Text (Item.Title_Label, Labels.Fitted (To));
      if Item.Docked then
         Labels.Set_Text (Item.Mini_Title, Labels.Fitted (Shortened (To)));
      end if;
   end Set_Title;

   procedure Set_Tag (Item : in out Frame; To : Themes.Slot) is
   begin
      Panels.Set_Fill (Item.Tag, To);
   end Set_Tag;

   procedure Set_Tag_Visible (Item : in out Frame; To : Boolean) is
   begin
      Set_Visible (Item.Tag, To);
   end Set_Tag_Visible;

   procedure Set_Scale (Item : in out Frame; To : Float) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Pixels * To;
   begin
      Item.Scale := To;
      Set_Height (Node (Item.Title_Bar), Bar_Height * Pixels);
      Set_Padding (Node (Item.Title_Bar), Yoga.Horizontal, Bar_Pad * Pixels);
      Set_Height (Node (Item.Title_Label), Label_Height * Pixels);
      Size (Item.Close_Button, Button_Size, Button_Size, Pixels);
      Size (Item.Tag, Tag_Size, Tag_Size, Pixels);
      Set_Margin
        (Node (Item.Tag), Yoga.Right,
         (if Item.Editable then Tag_Gap else Tag_Gap - Button_Gap) * Pixels);
      Labels.Set_Scale (Item.Title_Label, To);
      if Item.Editable then
         Set_Height (Node (Item.Title_Field), Title_Height * Pixels);
         Set_Height (Node (Item.Title_Area), Title_Height * Pixels);
         Set_Margin (Node (Item.Title_Field), Yoga.Right, Drag_Room * Pixels);
         Set_Margin (Node (Item.Title_Area), Yoga.Right, Drag_Room * Pixels);
         Set_Padding (Node (Item.Title_Area), Yoga.Left, Bar_Pad * Pixels);
      end if;
      if Item.Docked then
         Size (Item.Minimize_Button, Button_Size, Button_Size, Pixels);
      end if;
   end Set_Scale;

   procedure Set_Status_Visible (Item : in out Frame; To : Boolean) is
   begin
      Set_Visible (Item.Status_Bar, To);
   end Set_Status_Visible;

   procedure Set_Ring (Item : in out Frame; To : Boolean) is
   begin
      if To then
         Panels.Set_Ring (Item.Outline_Panel, Themes.Accent);
      else
         Panels.Clear_Ring (Item.Outline_Panel);
      end if;
   end Set_Ring;

   procedure Set_Shown (Item : in out Frame; Window, Docked : Boolean) is
   begin
      Set_Visible (Item.Outline_Panel, Window);
      if Item.Docked then
         Set_Visible (Item.Mini, Docked);
      end if;
   end Set_Shown;

   procedure Raise_To_Front (Item : in out Frame) is
   begin
      Widgets.Raise_To_Front (Item.Outline_Panel);
   end Raise_To_Front;

   procedure Place
     (Item : in out Frame; At_Left, At_Top, Wide, High : Float)
   is
      use Yoga.Nodes;
   begin
      Set_Position (Node (Item.Outline_Panel), Yoga.Left, At_Left);
      Set_Position (Node (Item.Outline_Panel), Yoga.Top, At_Top);
      Set_Width (Node (Item.Outline_Panel), Wide);
      Set_Height (Node (Item.Outline_Panel), High);
      Request_Layout (Item.Outline_Panel);
   end Place;

   function Status_Width (Item : Frame; Wide : Float) return Float is
     (Wide - 2.0 * Edge (Item) - UI.Boxes.Offset (Item.Pixels));

   function Left_Of (Item : Frame) return Float is
     (Widgets.Left_Of (Item.Outline_Panel));

   function Top_Of (Item : Frame) return Float is
     (Widgets.Top_Of (Item.Outline_Panel));

   function Width_Of (Item : Frame) return Float is
     (Widgets.Width_Of (Item.Outline_Panel));

   function Height_Of (Item : Frame) return Float is
     (Widgets.Height_Of (Item.Outline_Panel));

   function Owns (Item : Frame; Part : Widget_Access) return Boolean is
      Up : Widget_Access := Part;
   begin
      while Up /= null loop
         if Up.all'Address = Item.Outline_Panel'Address then
            return True;
         end if;
         Up := Parent_Of (Up.all);
      end loop;
      return False;
   end Owns;

   function Is_Hovered (Item : Frame) return Boolean is
     (Widgets.Is_Hovered (Item.Outline_Panel));

   function Is_Dragging (Item : Frame) return Boolean is
     (Grips.Is_Dragging (Item.Title_Bar)
      or else (Item.Editable and then Grips.Is_Dragging (Item.Title_Area))
      or else Grips.Is_Dragging (Item.Corner));

   function Is_Sizing (Item : Frame) return Boolean is
     (Grips.Is_Dragging (Item.Corner));

   procedure Take_Move (Item : in out Frame; Across, Down : out Float) is
      Area_Across, Area_Down : Float := 0.0;
   begin
      Grips.Take_Drag (Item.Title_Bar, Across, Down);
      if Item.Editable then
         Grips.Take_Drag (Item.Title_Area, Area_Across, Area_Down);
      end if;
      Across := Across + Area_Across;
      Down := Down + Area_Down;
   end Take_Move;

   procedure Take_Size (Item : in out Frame; Across, Down : out Float) is
   begin
      Grips.Take_Drag (Item.Corner, Across, Down);
   end Take_Size;

   procedure Take_Close (Item : in out Frame; Clicked : out Boolean) is
      Docked : Boolean := False;
   begin
      Buttons.Take_Click (Item.Close_Button, Clicked);
      if Item.Docked then
         Buttons.Take_Click (Item.Mini_Close, Docked);
      end if;
      Clicked := Clicked or else Docked;
   end Take_Close;

   procedure Take_Minimize (Item : in out Frame; Clicked : out Boolean) is
   begin
      Clicked := False;
      if Item.Docked then
         Buttons.Take_Click (Item.Minimize_Button, Clicked);
      end if;
   end Take_Minimize;

   procedure Take_Restore (Item : in out Frame; Clicked : out Boolean) is
   begin
      Clicked := False;
      if Item.Docked then
         Grips.Take_Click (Item.Mini_Area, Clicked);
      end if;
   end Take_Restore;

   procedure Attach_Title
     (Item : in out Frame; Doc : not null Texts.Documents.Document_Access) is
   begin
      Text_Fields.Attach (Item.Title_Field, Doc);
   end Attach_Title;

   procedure Share_Title
     (Item   : in out Frame;
      Shared : not null Editors.Shared_Access) is
   begin
      Text_Fields.Set_Shared (Item.Title_Field, Shared);
   end Share_Title;

   function Is_Editing_Title (Item : Frame) return Boolean is
     (Item.Editing);

   function Title_Has_Focus (Item : Frame) return Boolean is
     (Item.Editable and then Has_Focus (Item.Title_Field));

   procedure Begin_Title_Edit (Item : in out Frame) is
   begin
      Item.Editing := True;
      Set_Visible (Item.Title_Area, False);
      --  The press that began it is not let go on what is hidden.
      Grips.Cancel_Drag (Item.Title_Area);
      Set_Visible (Item.Title_Field, True);
      Text_Areas.Select_All (Text_Fields.Area (Item.Title_Field).all);
      Focus (Item.Title_Field);
   end Begin_Title_Edit;

   procedure End_Title_Edit (Item : in out Frame) is
   begin
      Item.Editing := False;
      Set_Visible (Item.Title_Field, False);
      Set_Visible (Item.Title_Area, True);
   end End_Title_Edit;

   procedure Reset_Title_Edit (Item : in out Frame) is
   begin
      Item.Editing := False;
      if Item.Editable then
         Set_Visible (Item.Title_Area, True);
         Set_Visible (Item.Title_Field, False);
      end if;
   end Reset_Title_Edit;

   procedure Take_Title_Double_Click
     (Item : in out Frame; Doubled : out Boolean) is
   begin
      Doubled := False;
      if Item.Editable then
         Grips.Take_Double_Click (Item.Title_Area, Doubled);
      end if;
   end Take_Title_Double_Click;

   procedure Take_Title_Return (Item : in out Frame; Entered : out Boolean) is
   begin
      Text_Fields.Take_Return (Item.Title_Field, Entered);
   end Take_Title_Return;

end UI.Widgets.Frames;
