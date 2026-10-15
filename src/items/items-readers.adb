with Items.Sources;
with Ada.Strings;
with Pomarine.Line_Texts;
with Pomarine.Text_Areas;
with Icon_Set;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Frames.Handlers;
with Pomarine.Widgets.Layouts;

package body Items.Readers is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Sliders renames Pomarine.Widgets.Sliders;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Editors renames Pomarine.Widgets.Editors;
   package Docs renames Texts.Documents;

   function Is_Texty (Item : Reader) return Boolean is
     (Item.Details.Origin /= Unchosen
      and then Items.Sources.Is_Text (Items.Extensions.To_String (Item.Details.Document)));
   --  Whether the source is shown as text, not as a picture.

   procedure Show_Mode (Item : in out Reader);
   --  Show the text of a text file, or the picture and its tools.

   --  In points

   Button_Size   : constant Float := Frames.Button_Size;
   Button_Gap    : constant Float := Frames.Button_Gap;
   Label_Height  : constant Float := Frames.Label_Height;
   Row_Height    : constant Float := 19.0;
   Slider_Width  : constant Float := 72.0;
   Percent_Width : constant Float := 40.0;
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;
   Pin_Icon_Size : constant Float := 12.0;
   Text_Size     : constant Float := 15.0;

   procedure Listen (Item : in out Reader);
   --  Give the reader's widgets the procedures they call (see Update).

   procedure Build
     (Item    : in out Reader;
      Parent  : in out Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float;
      Pinned  : Boolean := False)
   is
      Pixels : constant Float := Density;

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Layouts.Set_Layout (Part, Width => Wide, Height => High);
      end Size;
   begin
      Item.Pixels := Pixels;
      Item.Pinned := Pinned;
      Frames.Build
        (Item.Chrome, Parent, Bar, Pixels,
         Placement => (if Pinned then Frames.Filling else Frames.Floating));
      Frames.Add_Title_Button (Item.Chrome, Item.Pin_Button);
      Frames.Add_Content (Item.Chrome, Item.Picture);
      Frames.Add_Content (Item.Chrome, Item.Text_View);
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

      Layouts.Set_Layout (Item.Picture, Grow => 1.0, Height => 0.0);
      Editors.Configure
        (Item.Text_View, Pomarine.Line_Texts.Serif, Text_Size, 2000.0);
      Editors.Set_Paper (Item.Text_View, Pomarine.Themes.Page);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Text_View).all);
      Layouts.Set_Layout (Item.Text_View, Grow => 1.0, Height => 0.0);
      Widgets.Set_Visible (Item.Text_View, False);

      Layouts.Set_Layout (Item.Tools, Flow => Layouts.Row, Gap => Button_Gap);
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
      Layouts.Set_Layout (Item.Status, Grow => 1.0, Width => 0.0, Height => Label_Height);
      Listen (Item);
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
         (if Item.Details.Captured_At = 0 then "Not captured yet"
          elsif Item.Details.Page_Count > 0
          then "Page" & Item.Details.Page'Image & " of" & Item.Details.Page_Count'Image
          else ""));
   end Show_Status;

   procedure Show_Mode (Item : in out Reader) is
      Texty : constant Boolean := Is_Texty (Item);
   begin
      Widgets.Set_Visible (Item.Text_View, Texty);
      Widgets.Set_Visible (Item.Picture, not Texty);
      Widgets.Set_Visible (Item.Tools, not Texty);
      Widgets.Set_Visible (Item.Zoom_Slider, not Texty);
      Widgets.Set_Visible (Item.Zoom_Label, not Texty);
   end Show_Mode;

   procedure Set_Document
     (Item : in out Reader; Document : String; Page, Count : Natural) is
   begin
      Item.Details.Document :=
        Items.Extensions.To_Bounded_String (Document, Ada.Strings.Right);
      Item.Details.Page := Page;
      Item.Details.Page_Count := Count;
      Show_Mode (Item);
      Show_Status (Item);
   end Set_Document;

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
      if Is_Texty (Item) then
         Pictures.Set_File (Item.Picture, "");
         Docs.Load (Item.Text_Doc, Items.Sources.Read_Text (File));
      else
         Pictures.Set_File (Item.Picture, File);
      end if;
      Show_Mode (Item);
      Show_Status (Item);
      if Item.Details.State = Open and then not Is_Texty (Item) then
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
      Docs.Load (Item.Text_Doc, "");
      Editors.Attach (Item.Text_View, Item.Text_Doc'Unchecked_Access);
      if Of_Item.Captured_At > 0 and then Picture_File /= "" then
         if Is_Texty (Item) then
            Docs.Load (Item.Text_Doc, Items.Sources.Read_Text (Picture_File));
         else
            Pictures.Set_File (Item.Picture, Picture_File);
         end if;
      end if;
      Show_Mode (Item);
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

   package Hooks is new Pomarine.Widgets.Callbacks (Reader);
   package Frame_Hooks is new Pomarine.Widgets.Frames.Handlers (Reader);

   subtype Source_Widget is Widgets.Widget'Class;

   procedure Say (Item : in out Reader; Action : Actions);
   --  Tell the application what a button asked for, if it listens.

   procedure Say (Item : in out Reader; Action : Actions) is
   begin
      if Item.Said /= null then
         Item.Said (Item.Said_Self, Item.Said_Proc, Item.Said_Which, Action);
      end if;
   end Say;

   procedure Moved
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The title bar was dragged, in points: move it, but not while pinned.

   procedure Moved
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if not Item.Pinned then
         Item.Details.Where.Left := Item.Details.Where.Left + Event.Across;
         Item.Details.Where.Top := Item.Details.Where.Top + Event.Down;
         Place (Item);
      end if;
   end Moved;

   procedure Sized
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The corner was dragged, in points: size it, but not under the least.

   procedure Sized
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Item.Raw_Width := Item.Raw_Width + Event.Across;
      Item.Raw_Height := Item.Raw_Height + Event.Down;
      Item.Details.Where := Items.Sized
        ((Item.Details.Where with delta
            Width  => Float'Max (Least_Width, Item.Raw_Width),
            Height => Float'Max (Least_Height, Item.Raw_Height)));
      Place (Item);
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);
   end Sized;

   function Is_Open (Item : Reader) return Boolean is (Item.Details.State = Open);

   procedure Zoom_Moved
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Zoom_Moved
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open (Item) then
         Set_Zoom (Item, Items.Sources.From_Slider (Sliders.Value (Item.Zoom_Slider)));
      end if;
   end Zoom_Moved;

   procedure Pointer_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);
   procedure Marker_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);
   procedure Eraser_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Pointer_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open (Item) then
         Select_Tool (Item, Pictures.Pointer);
      end if;
   end Pointer_Clicked;

   procedure Marker_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open (Item) then
         Select_Tool (Item, Pictures.Highlighter);
      end if;
   end Marker_Clicked;

   procedure Eraser_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open (Item) then
         Select_Tool (Item, Pictures.Eraser);
      end if;
   end Eraser_Clicked;

   procedure Pin_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Pin_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open (Item) then
         Say (Item, Toggle_Pin);
      end if;
   end Pin_Clicked;

   procedure Close_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Close_Clicked
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Is_Open (Item) then
         Say (Item, Close);
      end if;
   end Close_Clicked;

   procedure Listen (Item : in out Reader) is
      use all type Widgets.Event_Kind;
   begin
      Frame_Hooks.On (Item.Chrome, Move, Item'Unrestricted_Access, Moved'Access);
      Frame_Hooks.On (Item.Chrome, Resize, Item'Unrestricted_Access, Sized'Access);
      Frame_Hooks.On (Item.Chrome, Close, Item'Unrestricted_Access, Close_Clicked'Access);
      Hooks.On (Item.Zoom_Slider, Change, Item'Unrestricted_Access, Zoom_Moved'Access);
      Hooks.On (Item.Cursor_Button, Click, Item'Unrestricted_Access, Pointer_Clicked'Access);
      Hooks.On (Item.Marker_Button, Click, Item'Unrestricted_Access, Marker_Clicked'Access);
      Hooks.On (Item.Eraser_Button, Click, Item'Unrestricted_Access, Eraser_Clicked'Access);
      Hooks.On (Item.Pin_Button, Click, Item'Unrestricted_Access, Pin_Clicked'Access);
   end Listen;

   procedure Update (Item : in out Reader) is
      Used : Boolean;
   begin
      --  What is moved and sized is the handlers' (see Listen); here only
      --  the size the corner asks for, which is the size it has while it
      --  is not being dragged.
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
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
   end Update;

end Items.Readers;
