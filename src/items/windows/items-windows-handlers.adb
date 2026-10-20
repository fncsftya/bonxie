with Items.Sources;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Frames.Handlers;
with Items.Windows.Displays;
with Items.Windows.Metrics;
with Items.Windows.Parts;

package body Items.Windows.Handlers is

   package Widgets renames Pomarine.Widgets;
   package Frames renames Pomarine.Widgets.Frames;
   package Sliders renames Pomarine.Widgets.Sliders;

   package Hooks is new Pomarine.Widgets.Callbacks (Window);

   package Frame_Hooks is new Pomarine.Widgets.Frames.Handlers (Window);

   procedure Say (Item : in out Window; Action : Actions);
   --  Tell the application what a button asked for, if it listens.

   procedure Say (Item : in out Window; Action : Actions) is
   begin
      if Item.Said /= null then
         Item.Said (Item.Said_Self, Item.Said_Proc, Item.Said_Which, Action);
      end if;
   end Say;

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
      Displays.Show_Title (Item);
      Frames.End_Title_Edit (Item.Chrome);
   end End_Edit;

   procedure Moved
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The title bar was dragged: move it, in canvas units.

   procedure Moved
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      Item.Details.Where.Left := Item.Details.Where.Left + Event.Across / Item.Zoom;
      Item.Details.Where.Top := Item.Details.Where.Top + Event.Down / Item.Zoom;
      Item.Frame_Dirty := True;
      Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
   end Moved;

   procedure Sized
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The corner was dragged: size it, in canvas units, but not under the
   --  least.

   procedure Sized
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
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
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Title_Pressed_Twice
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State = Open and then not Frames.Is_Editing_Title (Item.Chrome) then
         Begin_Edit (Item);
      end if;
   end Title_Pressed_Twice;

   procedure Title_Ended
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  Return was pressed in the title's field, or it lost the focus.

   procedure Title_Ended
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Frames.Is_Editing_Title (Item.Chrome) then
         End_Edit (Item);
      end if;
   end Title_Ended;

   procedure Fetch_Asked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  Return in a source's link, or its Add button.

   procedure Fetch_Asked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Parts.Is_Open_Source (Item) then
         Say (Item, Capture);
      end if;
   end Fetch_Asked;

   procedure Page_Turned
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The button before or after: its Index says which, 1 or 2.

   procedure Page_Turned
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if Parts.Is_Open_Source (Item) and then Item.Details.Page_Count > 1 then
         Say (Item, (if Event.Index = 1 then Previous_Page else Next_Page));
      end if;
   end Page_Turned;

   procedure Way_Chosen
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  One of the two buttons of a source yet to say where it is from
   --  (Index 1, a link; 2, a file), or a file's path that was pressed.

   procedure Way_Chosen
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if Parts.Is_Open_Source (Item) then
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
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Zoom_Moved
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Parts.Is_Open_Source (Item) then
         Set_Zoom (Item, Items.Sources.From_Slider (Sliders.Value (Item.Zoom_Slider)));
      end if;
   end Zoom_Moved;

   procedure Pointer_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Pointer_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Parts.Is_Open_Source (Item) then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Pointer);
      end if;
   end Pointer_Clicked;

   procedure Marker_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Marker_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Parts.Is_Open_Source (Item) then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Highlighter);
      end if;
   end Marker_Clicked;

   procedure Eraser_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Eraser_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Parts.Is_Open_Source (Item) then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Eraser);
      end if;
   end Eraser_Clicked;

   procedure Zoom_Menu_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The button that opens the menu of zooms.

   procedure Zoom_Menu_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Parts.Is_Open_Source (Item) then
         Widgets.Set_Visible (Item.Zoom_Menu, not Widgets.Is_Visible (Item.Zoom_Menu));
         Widgets.Raise_To_Front (Item.Zoom_Menu);
      end if;
   end Zoom_Menu_Clicked;

   procedure Preset_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A zoom of the menu: its Index.

   procedure Preset_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if Parts.Is_Open_Source (Item) then
         Set_Zoom (Item, Metrics.Preset_Zooms (Event.Index));
         Widgets.Set_Visible (Item.Zoom_Menu, False);
      end if;
   end Preset_Clicked;

   procedure Speak_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Speak_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.Kind = Note and then Item.Details.State = Open then
         Say (Item, Speak);
      end if;
   end Speak_Clicked;

   procedure Outline_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Outline_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.Kind = Note and then Item.Details.State = Open then
         Say (Item, Link_To_Outline);
      end if;
   end Outline_Clicked;

   procedure Minimize_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Minimize_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State = Open then
         Say (Item, Minimize);
      end if;
   end Minimize_Clicked;

   procedure Restore_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Restore_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      if Item.Details.State = Minimized then
         Say (Item, Restore);
      end if;
   end Restore_Clicked;

   procedure Close_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Close_Clicked
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
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

end Items.Windows.Handlers;
