with Items.Links;
with UI.Boxes;
with UI.Icons;
with UI.Widgets;
with UI.Widgets.Buttons;
with UI.Widgets.Canvases;
with UI.Widgets.Panels;
with UI.Widgets.Pins;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Links is

   package Widgets renames UI.Widgets;
   package Boxes renames UI.Boxes;
   package Canvases renames UI.Widgets.Canvases;
   package Pins renames UI.Widgets.Pins;
   package Buttons renames UI.Widgets.Buttons;
   package Windows renames Items.Windows;
   package Item_Links renames Items.Links;

   use type Widgets.Widget_Access;
   subtype Point is Boxes.Spot;

   use type Items.Id;
   use type Item_Links.Sides;
   use type Items.States;
   use type Item_Links.Strokes;
   use type Item_Links.Endings;

   pragma Assert (Canvases.Max_Lines >= Item_Links.Max_Links);

   function Diameter (Item : Session) return Float is
     (Float'Rounding (Pins.Diameter * Widgets.Density (Item.Root.Widgets)));
   --  Of a pin, in pixels.

   function Is_Open (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).State = Items.Open);

   function Slot_Of (Item : Session; Key : Items.Id) return Natural is
   begin
      for Which in Items.Slot loop
         if Is_Open (Item, Which)
           and then Windows.Details (Item.Windows (Which)).Key = Key
         then
            return Which;
         end if;
      end loop;
      return 0;
   end Slot_Of;
   --  The window of the item, if it is open; 0 if not.

   function Index_Of (Item : Session; Key : Items.Id) return Natural is
   begin
      for Number in 1 .. Item.Linking.Link_Set.Count loop
         if Item.Linking.Link_Set.Links (Number).Key = Key then
            return Number;
         end if;
      end loop;
      return 0;
   end Index_Of;
   --  Of the link in the set; 0 if there is none.

   function Middle
     (Where : Items.Frame; Side : Item_Links.Sides) return Point is
     (Boxes.Side_Midpoint
        (Where.Left, Where.Top, Where.Width, Where.Height,
         Boxes.Sides'Val (Item_Links.Sides'Pos (Side))));
   --  The middle of the side of the window, in canvas units.

   function Pixels_Of (Item : Session; Spot : Point) return Point is
     ((X => Float'Rounding
              (Canvases.To_Screen (Spot.X, Item.Nav.Shown_Zoom,
                                   Item.Nav.Shown_X)
               * Widgets.Density (Item.Root.Widgets)),
       Y => Float'Rounding
              (Canvases.To_Screen (Spot.Y, Item.Nav.Shown_Zoom,
                                   Item.Nav.Shown_Y)
               * Widgets.Density (Item.Root.Widgets))));
   --  A place on the canvas, in pixels from its top left.

   procedure Put_Pin
     (Item    : in out Session;
      Which   : Items.Slot;
      Side    : Item_Links.Sides;
      Changed : in out Boolean) is
   --  Put the pin at the middle of its side of the window, as
   --  Windows.Place has the window.
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
      Spot   : constant Point := Pixels_Of (Item, Middle (Where, Side));
      Half   : constant Float := Diameter (Item) / 2.0;
   begin
      Widgets.Move_To (Item.Linking.Pins (Which, Side), Spot.X - Half, Spot.Y - Half,
               Item.Linking.Pin_Left (Which, Side),
                  Item.Linking.Pin_Top (Which, Side),
               Changed);
   end Put_Pin;

   procedure Build (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;

      procedure Tool (Part : in out Buttons.Button; Apart : Boolean) is
      begin
         Widgets.Add (Item.Linking.Link_Bar, Part);
         Size (Part, Style.Link_Button_Size, Style.Link_Button_Size);
         if Apart then
            Set_Margin (Widgets.Node (Part), Yoga.Left,
                        Style.Link_Group_Gap * Pixels);
         end if;
      end Tool;
   begin
      Widgets.Add (Item.Canvas_View, Item.Linking.Link_Bar);
      UI.Widgets.Panels.Set_Fill (Item.Linking.Link_Bar, Style.Toolbar);
      Set_Position_Type (Widgets.Node (Item.Linking.Link_Bar), Yoga.Absolute);
      Set_Flex_Direction (Widgets.Node (Item.Linking.Link_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Linking.Link_Bar), Yoga.Center);
      Set_Padding (Widgets.Node (Item.Linking.Link_Bar), Yoga.All_Edges,
                   Style.Link_Bar_Pad * Pixels);
      Set_Gap (Widgets.Node (Item.Linking.Link_Bar), Yoga.All_Gutters,
               Style.Link_Bar_Gap * Pixels);
      Size (Item.Linking.Link_Bar, Style.Link_Bar_Width,
            Style.Link_Bar_Height);

      for Each in Item_Links.Strokes loop
         Tool (Item.Linking.Stroke_Buttons (Each),
               Apart => Each = Item_Links.Solid);
      end loop;
      Buttons.Set_Label
        (Item.Linking.Stroke_Buttons (Item_Links.Solid), "Solid");
      Buttons.Set_Icon (Item.Linking.Stroke_Buttons (Item_Links.Solid),
                        UI.Icons.Stroke_Solid);
      Buttons.Set_Label
        (Item.Linking.Stroke_Buttons (Item_Links.Dots), "Dots");
      Buttons.Set_Icon (Item.Linking.Stroke_Buttons (Item_Links.Dots),
                        UI.Icons.Stroke_Dots);
      Buttons.Set_Label
        (Item.Linking.Stroke_Buttons (Item_Links.Dashed), "Dash");
      Buttons.Set_Icon (Item.Linking.Stroke_Buttons (Item_Links.Dashed),
                        UI.Icons.Stroke_Dashed);
      for Each in Item_Links.Endings loop
         Tool
           (Item.Linking.End_Buttons (Each),
            Apart => Each = Item_Links.Plain);
      end loop;
      Buttons.Set_Label (Item.Linking.End_Buttons (Item_Links.Plain), "Plain");
      Buttons.Set_Icon (Item.Linking.End_Buttons (Item_Links.Plain),
                        UI.Icons.End_Plain);
      Buttons.Set_Label (Item.Linking.End_Buttons (Item_Links.Arrow), "Arrow");
      Buttons.Set_Icon (Item.Linking.End_Buttons (Item_Links.Arrow),
                        UI.Icons.End_Arrow);
      for Each in Item_Links.Link_Colors loop
         Tool (Item.Linking.Color_Buttons (Each), Apart => Each = 1);
         Buttons.Set_Label (Item.Linking.Color_Buttons (Each), "Ink");
         Buttons.Set_Swatch (Item.Linking.Color_Buttons (Each),
                             Style.Link_Inks (Each));
      end loop;
      Tool (Item.Linking.Delete_Link, Apart => True);
      Buttons.Set_Label (Item.Linking.Delete_Link, "Del");
      Buttons.Set_Icon (Item.Linking.Delete_Link, UI.Icons.Delete);
      Buttons.Set_Kind (Item.Linking.Delete_Link, Buttons.Danger);
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);

      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            declare
               Pin : Pins.Pin renames Item.Linking.Pins (Which, Side);
            begin
               Widgets.Add (Item.Canvas_View, Pin);
               Set_Position_Type (Widgets.Node (Pin), Yoga.Absolute);
               Size (Pin, Pins.Diameter, Pins.Diameter);
               Widgets.Set_Visible (Pin, False);
            end;
         end loop;
      end loop;
      Widgets.Add (Item.Canvas_View, Item.Linking.Link_Handle);
      Set_Position_Type (Widgets.Node (Item.Linking.Link_Handle),
                         Yoga.Absolute);
      Size (Item.Linking.Link_Handle, Pins.Diameter, Pins.Diameter);
      Widgets.Set_Visible (Item.Linking.Link_Handle, False);
   end Build;

   procedure Reload (Item : in out Session) is
   begin
      Item_Links.Load_Links (Item.Nav.Store, Item.Opened.Current,
                        Item.Linking.Link_Set);
      if Index_Of (Item, Item.Linking.Link_Key) = 0 then
         Item.Linking.Link_Key := 0;
      end if;
   end Reload;

   procedure Enter (Item : in out Session) is
   begin
      Item.Linking.Link_From := 0;
      Item.Linking.Link_Moving := False;
      Item.Linking.Link_Key := 0;
      Reload (Item);
   end Enter;

   procedure Set_Accepting (Item : in out Session; Except : Natural);
   --  Say which pins a line being dragged may end on: those of all the
   --  windows but Except, or none, if that is 0.

   procedure Set_Accepting (Item : in out Session; Except : Natural) is
   begin
      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            Pins.Set_Accepting
              (Item.Linking.Pins (Which, Side),
               Except /= 0 and then Which /= Except);
         end loop;
      end loop;
   end Set_Accepting;

   procedure Leave (Item : in out Session) is
   begin
      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            Pins.Cancel (Item.Linking.Pins (Which, Side));
            Widgets.Set_Visible (Item.Linking.Pins (Which, Side), False);
         end loop;
      end loop;
      Pins.Cancel (Item.Linking.Link_Handle);
      Widgets.Set_Visible (Item.Linking.Link_Handle, False);
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);
      Set_Accepting (Item, 0);
      Item.Linking.Link_From := 0;
      Item.Linking.Link_Moving := False;
      Item.Linking.Link_Key := 0;
      Item.Linking.Link_Set.Count := 0;
      Canvases.Set_Selected (Item.Canvas_View, 0);
      Canvases.Clear_Ghost (Item.Canvas_View);
      Canvases.Set_Lines (Item.Canvas_View, []);
   end Leave;

   procedure Make_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides);
   --  Join the item whose pin was dragged from to the one of this pin.

   procedure Make_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides)
   is
      Added : Boolean;
   begin
      if Item.Linking.Link_From /= 0 and then Item.Linking.Link_From /= To
        and then Is_Open (Item, Item.Linking.Link_From) and then Is_Open (Item,
           To)
      then
         Item_Links.Add_Link
           (Item.Nav.Store,
            (From
             => Windows.Details (Item.Windows (Item.Linking.Link_From)).Key,
             To        => Windows.Details (Item.Windows (To)).Key,
             From_Side => Item.Linking.Link_From_Side,
             To_Side   => To_Side,
             others    => <>),
            Added);
         if Added then
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      end if;
   end Make_Link;

   procedure Move_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides);
   --  Make the selected link end at this pin.

   procedure Move_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides)
   is
      Moved : Boolean;
   begin
      if Item.Linking.Link_Key /= 0 and then Is_Open (Item, To) then
         Item_Links.Move_Link
           (Item.Nav.Store, Item.Linking.Link_Key,
            Windows.Details (Item.Windows (To)).Key, To_Side, Moved);
         if Moved then
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      end if;
   end Move_Link;

   function Dragger (Item : Session) return access Pins.Pin is
     (if Item.Linking.Link_Moving
      then Item.Linking.Link_Handle'Unrestricted_Access
      else Item.Linking.Pins (Item.Linking.Link_From,
                              Item.Linking.Link_From_Side)'Unrestricted_Access)
   with Pre => Item.Linking.Link_From /= 0;
   --  The pin that is held while a line is dragged.

   procedure Take_Drags (Item : in out Session);
   --  Start a drag from a pin that was pressed, and end it where the
   --  button was let go.

   procedure Take_Drags (Item : in out Session) is
      Pressed, Released : Boolean;
   begin
      if Item.Linking.Link_From = 0 then
         for Which in Items.Slot loop
            for Side in Item_Links.Sides loop
               Pins.Take_Press (Item.Linking.Pins (Which, Side), Pressed);
               if Pressed and then Item.Linking.Link_From = 0 then
                  Item.Linking.Link_From := Which;
                  Item.Linking.Link_From_Side := Side;
                  Item.Linking.Link_Moving := False;
                  Set_Accepting (Item, Which);
               end if;
            end loop;
         end loop;
         Pins.Take_Press (Item.Linking.Link_Handle, Pressed);
         if Pressed and then Item.Linking.Link_From = 0 then
            declare
               Number : constant Natural := Index_Of (Item,
                  Item.Linking.Link_Key);
               From   : constant Natural :=
                 (if Number = 0 then 0
                  else Slot_Of (Item,
                                Item.Linking.Link_Set.Links (Number).From));
            begin
               if From /= 0 then
                  Item.Linking.Link_From := From;
                  Item.Linking.Link_From_Side :=
                    Item.Linking.Link_Set.Links (Number).From_Side;
                  Item.Linking.Link_Moving := True;
                  Set_Accepting (Item, From);
               else
                  Pins.Cancel (Item.Linking.Link_Handle);
               end if;
            end;
         end if;
      else
         Pins.Take_Release (Dragger (Item).all, Released);
         if Released then
            --  The pointer is over the pin it was let go on, if any.
            for Which in Items.Slot loop
               for Side in Item_Links.Sides loop
                  if Which /= Item.Linking.Link_From
                    and then Widgets.Is_Shown (Item.Linking.Pins (Which, Side))
                    and then Widgets.Is_Hovered (Item.Linking.Pins (Which,
                       Side))
                  then
                     if Item.Linking.Link_Moving then
                        Move_Link (Item, Which, Side);
                     else
                        Make_Link (Item, Which, Side);
                     end if;
                  end if;
               end loop;
            end loop;
            Item.Linking.Link_From := 0;
            Item.Linking.Link_Moving := False;
            Set_Accepting (Item, 0);
         end if;
      end if;
   end Take_Drags;

   procedure Take_Clicks (Item : in out Session);
   --  Do what the toolbar's buttons were clicked for, to the link
   --  selected.

   procedure Take_Clicks (Item : in out Session) is
      Number  : constant Natural := Index_Of (Item, Item.Linking.Link_Key);
      Clicked : Boolean;
   begin
      if Number = 0 then
         return;
      end if;
      declare
         Was    : constant Item_Links.Link :=
           Item.Linking.Link_Set.Links (Number);
         Stroke : Item_Links.Strokes := Was.Stroke;
         Ending : Item_Links.Endings := Was.Ending;
         Color  : Item_Links.Link_Colors := Was.Color;
      begin
         for Each in Item_Links.Strokes loop
            Buttons.Take_Click (Item.Linking.Stroke_Buttons (Each), Clicked);
            if Clicked then
               Stroke := Each;
            end if;
         end loop;
         for Each in Item_Links.Endings loop
            Buttons.Take_Click (Item.Linking.End_Buttons (Each), Clicked);
            if Clicked then
               Ending := Each;
            end if;
         end loop;
         for Each in Item_Links.Link_Colors loop
            Buttons.Take_Click (Item.Linking.Color_Buttons (Each), Clicked);
            if Clicked then
               Color := Each;
            end if;
         end loop;
         if Stroke /= Was.Stroke or else Ending /= Was.Ending
           or else Color /= Was.Color
         then
            Item_Links.Set_Link_Style (Item.Nav.Store, Was.Key, Stroke, Ending,
                                  Color);
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
         Buttons.Take_Click (Item.Linking.Delete_Link, Clicked);
         if Clicked then
            Item_Links.Delete_Link (Item.Nav.Store, Was.Key);
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      end;
   end Take_Clicks;

   procedure Take_Selection (Item : in out Session);
   --  Select the link that was pressed on, or none, and delete the one
   --  selected if Backspace was pressed.

   procedure Take_Selection (Item : in out Session) is
      Changed, Asked : Boolean;
      Tag            : Natural;
   begin
      Canvases.Take_Selection (Item.Canvas_View, Changed, Tag);
      if Changed then
         Item.Linking.Link_Key :=
           (if Tag in 1 .. Item.Linking.Link_Set.Count
            then Item.Linking.Link_Set.Links (Tag).Key else 0);
         if Item.Linking.Link_Key /= 0 then
            --  So that Backspace is not for the text being typed in.
            Widgets.Clear_Focus (Item.Root.Widgets);
         end if;
      end if;
      Canvases.Take_Delete (Item.Canvas_View, Asked);
      if Asked and then Item.Linking.Link_Key /= 0 then
         Item_Links.Delete_Link (Item.Nav.Store, Item.Linking.Link_Key);
         Reload (Item);
         Projects.Touch (Item.Nav.Store, Item.Opened.Current);
      end if;
   end Take_Selection;

   procedure Show_Pins (Item : in out Session; Changed : in out Boolean);
   --  Show the pins of the window the pointer is over, or, in a drag, of
   --  all the others (but, to move a link, not of the window it starts
   --  from); and put them where they go.

   procedure Show_Pins (Item : in out Session; Changed : in out Boolean) is
   begin
      for Which in Items.Slot loop
         declare
            Near : Boolean := False;
         begin
            if Is_Open (Item, Which) then
               Near := Windows.Is_Hovered (Item.Windows (Which));
               for Side in Item_Links.Sides loop
                  Near := Near or else Widgets.Is_Hovered
                            (Item.Linking.Pins (Which, Side));
               end loop;
            end if;
            for Side in Item_Links.Sides loop
               declare
                  Want : constant Boolean :=
                    Is_Open (Item, Which)
                    and then
                      (if Item.Linking.Link_From = 0 then Near
                       elsif Item.Linking.Link_Moving
                          then Which /= Item.Linking.Link_From
                       else Which /= Item.Linking.Link_From
                            or else Side = Item.Linking.Link_From_Side);
                  Pin : Pins.Pin renames Item.Linking.Pins (Which, Side);
               begin
                  if Want /= Widgets.Is_Visible (Pin) then
                     if not Want then
                        Pins.Cancel (Pin);
                     end if;
                     Widgets.Set_Visible (Pin, Want);
                     Changed := True;
                  end if;
                  if Want then
                     Put_Pin (Item, Which, Side, Changed);
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Show_Pins;

   procedure Draw_Lines (Item : in out Session; Changed : in out Boolean);
   --  Set the lines of the links and of the drag, and show the handle and
   --  the toolbar of the link selected, where it is.

   procedure Draw_Lines (Item : in out Session; Changed : in out Boolean) is

      Lines : Canvases.Line_Array (1 .. Item_Links.Max_Links);
      Count : Natural := 0;
      Chosen : Natural := 0;
      --  The tag of the selected link, if it is drawn.
      Target, Mid : Point := (0.0, 0.0);
   begin
      for Number in 1 .. Item.Linking.Link_Set.Count loop
         declare
            Each : Item_Links.Link renames
              Item.Linking.Link_Set.Links (Number);
            From : constant Natural := Slot_Of (Item, Each.From);
            To   : constant Natural := Slot_Of (Item, Each.To);
         begin
            if From /= 0 and then To /= 0 then
               declare
                  A : constant Point :=
                    Middle (Windows.Details (Item.Windows (From)).Where,
                            Each.From_Side);
                  B : constant Point :=
                    Middle (Windows.Details (Item.Windows (To)).Where,
                            Each.To_Side);
               begin
                  Count := Count + 1;
                  Lines (Count) :=
                    (From_X => A.X, From_Y => A.Y, To_X => B.X, To_Y => B.Y,
                     Tag    => Number,
                     Dash   => (case Each.Stroke is
                                   when Item_Links.Solid  => Canvases.Solid,
                                   when Item_Links.Dots   => Canvases.Dotted,
                                   when Item_Links.Dashed => Canvases.Dashed),
                     Arrow  => Each.Ending = Item_Links.Arrow,
                     Ink    => Style.Link_Inks (Each.Color));
                  if Each.Key = Item.Linking.Link_Key then
                     Chosen := Number;
                     Target := B;
                     Mid := (X => (A.X + B.X) / 2.0,
                             Y => Float'Max (A.Y, B.Y));
                  end if;
               end;
            end if;
         end;
      end loop;
      Canvases.Set_Selected (Item.Canvas_View, Chosen);
      Canvases.Set_Lines (Item.Canvas_View, Lines (1 .. Count));

      --  The handle over the target end, and the toolbar by the middle.
      declare
         Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
         Shown  : constant Boolean := Chosen /= 0;
         Half   : constant Float := Diameter (Item) / 2.0;
         Spot   : constant Point := Pixels_Of (Item, Target);
         Centre : constant Point := Pixels_Of (Item, Mid);
         Wide   : constant Float := Style.Link_Bar_Width * Pixels;
         High   : constant Float := Style.Link_Bar_Height * Pixels;
         Left   : constant Float :=
           Float'Max (0.0, Float'Min (Centre.X - Wide / 2.0,
                                      Widgets.Width_Of (Item.Canvas_View)
                                      - Wide));
         Top    : constant Float :=
           Float'Max (0.0, Float'Min
                        (Centre.Y + Style.Link_Bar_Offset * Pixels,
                         Widgets.Height_Of (Item.Canvas_View) - High));
      begin
         if Shown /= Widgets.Is_Visible (Item.Linking.Link_Handle) then
            if not Shown then
               Pins.Cancel (Item.Linking.Link_Handle);
            end if;
            Widgets.Set_Visible (Item.Linking.Link_Handle, Shown);
            Widgets.Set_Visible (Item.Linking.Link_Bar, Shown);
            Changed := True;
         end if;
         if Shown then
            Widgets.Move_To (Item.Linking.Link_Handle, Spot.X - Half, Spot.Y - Half,
                     Item.Linking.Handle_Left, Item.Linking.Handle_Top,
                        Changed);
            Widgets.Move_To (Item.Linking.Link_Bar, Float'Rounding (Left),
                     Float'Rounding (Top),
                     Item.Linking.Bar_Left, Item.Linking.Bar_Top, Changed);
            declare
               Was : constant Item_Links.Link
                  := Item.Linking.Link_Set.Links (Chosen);
            begin
               for Each in Item_Links.Strokes loop
                  Buttons.Set_Selected
                    (Item.Linking.Stroke_Buttons (Each), Each = Was.Stroke);
               end loop;
               for Each in Item_Links.Endings loop
                  Buttons.Set_Selected
                    (Item.Linking.End_Buttons (Each), Each = Was.Ending);
               end loop;
               for Each in Item_Links.Link_Colors loop
                  Buttons.Set_Selected
                    (Item.Linking.Color_Buttons (Each), Each = Was.Color);
               end loop;
            end;
         end if;
      end;

      if Item.Linking.Link_From /= 0
        and then Is_Open (Item, Item.Linking.Link_From)
      then
         declare
            Source : constant Point :=
              Middle
                (Windows.Details
                   (Item.Windows (Item.Linking.Link_From)).Where,
                 Item.Linking.Link_From_Side);
            Pin : constant access Pins.Pin := Dragger (Item);
         begin
            Canvases.Set_Ghost
              (Item.Canvas_View, Source.X, Source.Y,
               Pins.Pointer_X (Pin.all), Pins.Pointer_Y (Pin.all));
         end;
      else
         Canvases.Clear_Ghost (Item.Canvas_View);
      end if;
   end Draw_Lines;

   procedure Raise_Over (Item : in out Session);
   --  Put the toolbar, the pins and the handle over the windows, in that
   --  order, if a window has been raised over them.

   procedure Raise_Over (Item : in out Session) is
      Last  : constant Widgets.Widget_Access :=
        Widgets.Widget_Access'(Item.Linking.Link_Handle'Unrestricted_Access);
      Count : constant Natural := Widgets.Child_Count (Item.Canvas_View);
   begin
      if Count > 0
        and then Widgets.Child_At (Item.Canvas_View, Count) /= Last
        and then (Widgets.Is_Visible (Item.Linking.Link_Handle)
                  or else Widgets.Is_Visible (Item.Linking.Link_Bar)
                  or else Shown_Pins (Item) > 0)
      then
         Widgets.Raise_To_Front (Item.Linking.Link_Bar);
         for Which in Items.Slot loop
            for Side in Item_Links.Sides loop
               Widgets.Raise_To_Front (Item.Linking.Pins (Which, Side));
            end loop;
         end loop;
         Widgets.Raise_To_Front (Item.Linking.Link_Handle);
      end if;
   end Raise_Over;

   function Shown_Pins (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Linking.Pins loop
         if Widgets.Is_Shown (Each) then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Shown_Pins;

   procedure Update (Item : in out Session) is
      Changed : Boolean := False;
   begin
      Take_Selection (Item);
      Take_Clicks (Item);
      Take_Drags (Item);
      Show_Pins (Item, Changed);
      Draw_Lines (Item, Changed);
      Raise_Over (Item);
      --  So that the next event finds them where they are.
      if Changed then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Update;

end Viewer.Links;
