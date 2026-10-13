with UI.Icons;
with UI.Themes;
with UI.Widgets;
with UI.Widgets.Buttons;
with UI.Widgets.Canvases;
with UI.Widgets.Panels;
with UI.Widgets.Pins;
with Viewer.Canvas_Items;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Links is

   package Widgets renames UI.Widgets;
   package Canvases renames UI.Widgets.Canvases;
   package Pins renames UI.Widgets.Pins;
   package Buttons renames UI.Widgets.Buttons;
   package Windows renames Items.Windows;

   use type Widgets.Widget_Access;
   use type Items.Id;
   use type Items.Sides;
   use type Items.States;
   use type Items.Strokes;
   use type Items.Endings;
   use type Items.Kinds;

   pragma Assert (Canvases.Max_Lines >= Items.Max_Links);

   function Diameter (Item : Session) return Float is
     (Float'Rounding (Pins.Diameter * Widgets.Density (Item.Widgets)));
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
      for Number in 1 .. Item.Link_Set.Count loop
         if Item.Link_Set.Links (Number).Key = Key then
            return Number;
         end if;
      end loop;
      return 0;
   end Index_Of;
   --  Of the link in the set; 0 if there is none.

   type Point is record
      X, Y : Float;
   end record;

   function Middle (Where : Items.Frame; Side : Items.Sides) return Point is
     (case Side is
         when Items.Top    => (Where.Left + Where.Width / 2.0, Where.Top),
         when Items.Right  => (Where.Left + Where.Width,
                               Where.Top + Where.Height / 2.0),
         when Items.Bottom => (Where.Left + Where.Width / 2.0,
                               Where.Top + Where.Height),
         when Items.Left   => (Where.Left, Where.Top + Where.Height / 2.0));
   --  The middle of the side of the window, in canvas units.

   function Pixels_Of (Item : Session; Spot : Point) return Point is
     ((X => Float'Rounding
              ((Item.Shown_X + Spot.X * Item.Shown_Zoom)
               * Widgets.Density (Item.Widgets)),
       Y => Float'Rounding
              ((Item.Shown_Y + Spot.Y * Item.Shown_Zoom)
               * Widgets.Density (Item.Widgets))));
   --  A place on the canvas, in pixels from its top left.

   procedure Move_To
     (Part      : in out Widgets.Widget'Class;
      Across, Down : Float;
      Was_Left, Was_Top : in out Float;
      Changed   : in out Boolean);
   --  Put the widget, which is placed by its edges, there, in pixels, if it
   --  is not.

   procedure Move_To
     (Part      : in out Widgets.Widget'Class;
      Across, Down : Float;
      Was_Left, Was_Top : in out Float;
      Changed   : in out Boolean)
   is
      use Yoga.Nodes;
   begin
      if Across /= Was_Left or else Down /= Was_Top then
         Was_Left := Across;
         Was_Top := Down;
         Set_Position (Widgets.Node (Part), Yoga.Left, Across);
         Set_Position (Widgets.Node (Part), Yoga.Top, Down);
         Widgets.Request_Layout (Part);
         Changed := True;
      end if;
   end Move_To;

   procedure Put_Pin
     (Item    : in out Session;
      Which   : Items.Slot;
      Side    : Items.Sides;
      Changed : in out Boolean) is
   --  Put the pin at the middle of its side of the window, as
   --  Windows.Place has the window.
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
      Spot   : constant Point := Pixels_Of (Item, Middle (Where, Side));
      Half   : constant Float := Diameter (Item) / 2.0;
   begin
      Move_To (Item.Pins (Which, Side), Spot.X - Half, Spot.Y - Half,
               Item.Pin_Left (Which, Side), Item.Pin_Top (Which, Side),
               Changed);
   end Put_Pin;

   procedure Build (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Widgets);

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;

      procedure Tool (Part : in out Buttons.Button; Apart : Boolean) is
      begin
         Widgets.Add (Item.Link_Bar, Part);
         Size (Part, Style.Link_Button_Size, Style.Link_Button_Size);
         if Apart then
            Set_Margin (Widgets.Node (Part), Yoga.Left,
                        Style.Link_Group_Gap * Pixels);
         end if;
      end Tool;
   begin
      Widgets.Add (Item.Canvas_View, Item.Link_Bar);
      UI.Widgets.Panels.Set_Fill (Item.Link_Bar, Style.Toolbar);
      Set_Position_Type (Widgets.Node (Item.Link_Bar), Yoga.Absolute);
      Set_Flex_Direction (Widgets.Node (Item.Link_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Link_Bar), Yoga.Center);
      Set_Padding (Widgets.Node (Item.Link_Bar), Yoga.All_Edges,
                   Style.Link_Bar_Pad * Pixels);
      Set_Gap (Widgets.Node (Item.Link_Bar), Yoga.All_Gutters,
               Style.Link_Bar_Gap * Pixels);
      Size (Item.Link_Bar, Style.Link_Bar_Width, Style.Link_Bar_Height);

      for Each in Items.Strokes loop
         Tool (Item.Stroke_Buttons (Each), Apart => Each = Items.Solid);
      end loop;
      Buttons.Set_Label (Item.Stroke_Buttons (Items.Solid), "Solid");
      Buttons.Set_Icon (Item.Stroke_Buttons (Items.Solid),
                        UI.Icons.Stroke_Solid);
      Buttons.Set_Label (Item.Stroke_Buttons (Items.Dots), "Dots");
      Buttons.Set_Icon (Item.Stroke_Buttons (Items.Dots),
                        UI.Icons.Stroke_Dots);
      Buttons.Set_Label (Item.Stroke_Buttons (Items.Dashed), "Dash");
      Buttons.Set_Icon (Item.Stroke_Buttons (Items.Dashed),
                        UI.Icons.Stroke_Dashed);
      for Each in Items.Endings loop
         Tool (Item.End_Buttons (Each), Apart => Each = Items.Plain);
      end loop;
      Buttons.Set_Label (Item.End_Buttons (Items.Plain), "Plain");
      Buttons.Set_Icon (Item.End_Buttons (Items.Plain), UI.Icons.End_Plain);
      Buttons.Set_Label (Item.End_Buttons (Items.Arrow), "Arrow");
      Buttons.Set_Icon (Item.End_Buttons (Items.Arrow), UI.Icons.End_Arrow);
      for Each in Items.Link_Colors loop
         Tool (Item.Color_Buttons (Each), Apart => Each = 1);
         Buttons.Set_Label (Item.Color_Buttons (Each), "Ink");
         Buttons.Set_Swatch (Item.Color_Buttons (Each),
                             Style.Link_Inks (Each));
      end loop;
      Tool (Item.Delete_Link, Apart => True);
      Buttons.Set_Label (Item.Delete_Link, "Del");
      Buttons.Set_Icon (Item.Delete_Link, UI.Icons.Delete);
      Buttons.Set_Kind (Item.Delete_Link, Buttons.Danger);
      Widgets.Set_Visible (Item.Link_Bar, False);

      for Which in Items.Slot loop
         for Side in Items.Sides loop
            declare
               Pin : Pins.Pin renames Item.Pins (Which, Side);
            begin
               Widgets.Add (Item.Canvas_View, Pin);
               Set_Position_Type (Widgets.Node (Pin), Yoga.Absolute);
               Size (Pin, Pins.Diameter, Pins.Diameter);
               Widgets.Set_Visible (Pin, False);
            end;
         end loop;
      end loop;
      Widgets.Add (Item.Canvas_View, Item.Link_Handle);
      Set_Position_Type (Widgets.Node (Item.Link_Handle), Yoga.Absolute);
      Size (Item.Link_Handle, Pins.Diameter, Pins.Diameter);
      Widgets.Set_Visible (Item.Link_Handle, False);
   end Build;

   procedure Reload (Item : in out Session) is
   begin
      Items.Load_Links (Item.Store, Item.Current, Item.Link_Set);
      if Index_Of (Item, Item.Link_Key) = 0 then
         Item.Link_Key := 0;
      end if;
   end Reload;

   procedure Enter (Item : in out Session) is
   begin
      Item.Link_From := 0;
      Item.Link_Moving := False;
      Item.Link_Key := 0;
      Reload (Item);
   end Enter;

   procedure Set_Accepting (Item : in out Session; Except : Natural);
   --  Say which pins a line being dragged may end on: those of all the
   --  windows but Except, or none, if that is 0.

   procedure Set_Accepting (Item : in out Session; Except : Natural) is
   begin
      for Which in Items.Slot loop
         for Side in Items.Sides loop
            Pins.Set_Accepting
              (Item.Pins (Which, Side),
               Except /= 0 and then Which /= Except);
         end loop;
      end loop;
   end Set_Accepting;

   procedure Leave (Item : in out Session) is
   begin
      for Which in Items.Slot loop
         for Side in Items.Sides loop
            Pins.Cancel (Item.Pins (Which, Side));
            Widgets.Set_Visible (Item.Pins (Which, Side), False);
         end loop;
      end loop;
      Pins.Cancel (Item.Link_Handle);
      Widgets.Set_Visible (Item.Link_Handle, False);
      Widgets.Set_Visible (Item.Link_Bar, False);
      Set_Accepting (Item, 0);
      Item.Link_From := 0;
      Item.Link_Moving := False;
      Item.Link_Key := 0;
      Item.Link_Set.Count := 0;
      Canvases.Set_Selected (Item.Canvas_View, 0);
      Canvases.Clear_Ghost (Item.Canvas_View);
      Canvases.Set_Lines (Item.Canvas_View, []);
   end Leave;

   procedure Make_Link
     (Item : in out Session; To : Items.Slot; To_Side : Items.Sides);
   --  Join the item whose pin was dragged from to the one of this pin.

   procedure Make_Link
     (Item : in out Session; To : Items.Slot; To_Side : Items.Sides)
   is
      Added : Boolean;
   begin
      if Item.Link_From /= 0 and then Item.Link_From /= To
        and then Is_Open (Item, Item.Link_From) and then Is_Open (Item, To)
      then
         Items.Add_Link
           (Item.Store,
            (From      => Windows.Details (Item.Windows (Item.Link_From)).Key,
             To        => Windows.Details (Item.Windows (To)).Key,
             From_Side => Item.Link_From_Side,
             To_Side   => To_Side,
             others    => <>),
            Added);
         if Added then
            Reload (Item);
            Projects.Touch (Item.Store, Item.Current);
         end if;
      end if;
   end Make_Link;

   procedure Move_Link
     (Item : in out Session; To : Items.Slot; To_Side : Items.Sides);
   --  Make the selected link end at this pin.

   procedure Move_Link
     (Item : in out Session; To : Items.Slot; To_Side : Items.Sides)
   is
      Moved : Boolean;
   begin
      if Item.Link_Key /= 0 and then Is_Open (Item, To) then
         Items.Move_Link
           (Item.Store, Item.Link_Key,
            Windows.Details (Item.Windows (To)).Key, To_Side, Moved);
         if Moved then
            Reload (Item);
            Projects.Touch (Item.Store, Item.Current);
         end if;
      end if;
   end Move_Link;

   function Dragger (Item : Session) return access Pins.Pin is
     (if Item.Link_Moving then Item.Link_Handle'Unrestricted_Access
      else Item.Pins (Item.Link_From, Item.Link_From_Side)'Unrestricted_Access)
   with Pre => Item.Link_From /= 0;
   --  The pin that is held while a line is dragged.

   procedure Take_Drags (Item : in out Session);
   --  Start a drag from a pin that was pressed, and end it where the
   --  button was let go.

   procedure Take_Drags (Item : in out Session) is
      Pressed, Released : Boolean;
   begin
      if Item.Link_From = 0 then
         for Which in Items.Slot loop
            for Side in Items.Sides loop
               Pins.Take_Press (Item.Pins (Which, Side), Pressed);
               if Pressed and then Item.Link_From = 0 then
                  Item.Link_From := Which;
                  Item.Link_From_Side := Side;
                  Item.Link_Moving := False;
                  Set_Accepting (Item, Which);
               end if;
            end loop;
         end loop;
         Pins.Take_Press (Item.Link_Handle, Pressed);
         if Pressed and then Item.Link_From = 0 then
            declare
               Number : constant Natural := Index_Of (Item, Item.Link_Key);
               From   : constant Natural :=
                 (if Number = 0 then 0
                  else Slot_Of (Item, Item.Link_Set.Links (Number).From));
            begin
               if From /= 0 then
                  Item.Link_From := From;
                  Item.Link_From_Side :=
                    Item.Link_Set.Links (Number).From_Side;
                  Item.Link_Moving := True;
                  Set_Accepting (Item, From);
               else
                  Pins.Cancel (Item.Link_Handle);
               end if;
            end;
         end if;
      else
         Pins.Take_Release (Dragger (Item).all, Released);
         if Released then
            --  The pointer is over the pin it was let go on, if any.
            for Which in Items.Slot loop
               for Side in Items.Sides loop
                  if Which /= Item.Link_From
                    and then Widgets.Is_Shown (Item.Pins (Which, Side))
                    and then Widgets.Is_Hovered (Item.Pins (Which, Side))
                  then
                     if Item.Link_Moving then
                        Move_Link (Item, Which, Side);
                     else
                        Make_Link (Item, Which, Side);
                     end if;
                  end if;
               end loop;
            end loop;
            Item.Link_From := 0;
            Item.Link_Moving := False;
            Set_Accepting (Item, 0);
         end if;
      end if;
   end Take_Drags;

   procedure Take_Clicks (Item : in out Session);
   --  Do what the toolbar's buttons were clicked for, to the link
   --  selected.

   procedure Take_Clicks (Item : in out Session) is
      Number  : constant Natural := Index_Of (Item, Item.Link_Key);
      Clicked : Boolean;
   begin
      if Number = 0 then
         return;
      end if;
      declare
         Was    : constant Items.Link := Item.Link_Set.Links (Number);
         Stroke : Items.Strokes := Was.Stroke;
         Ending : Items.Endings := Was.Ending;
         Color  : Items.Link_Colors := Was.Color;
      begin
         for Each in Items.Strokes loop
            Buttons.Take_Click (Item.Stroke_Buttons (Each), Clicked);
            if Clicked then
               Stroke := Each;
            end if;
         end loop;
         for Each in Items.Endings loop
            Buttons.Take_Click (Item.End_Buttons (Each), Clicked);
            if Clicked then
               Ending := Each;
            end if;
         end loop;
         for Each in Items.Link_Colors loop
            Buttons.Take_Click (Item.Color_Buttons (Each), Clicked);
            if Clicked then
               Color := Each;
            end if;
         end loop;
         if Stroke /= Was.Stroke or else Ending /= Was.Ending
           or else Color /= Was.Color
         then
            Items.Set_Link_Style (Item.Store, Was.Key, Stroke, Ending, Color);
            Reload (Item);
            Projects.Touch (Item.Store, Item.Current);
         end if;
         Buttons.Take_Click (Item.Delete_Link, Clicked);
         if Clicked then
            Items.Delete_Link (Item.Store, Was.Key);
            Reload (Item);
            Projects.Touch (Item.Store, Item.Current);
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
         Item.Link_Key :=
           (if Tag in 1 .. Item.Link_Set.Count
            then Item.Link_Set.Links (Tag).Key else 0);
         if Item.Link_Key /= 0 then
            --  So that Backspace is not for the text being typed in.
            Widgets.Clear_Focus (Item.Widgets);
         end if;
      end if;
      Canvases.Take_Delete (Item.Canvas_View, Asked);
      if Asked and then Item.Link_Key /= 0 then
         Items.Delete_Link (Item.Store, Item.Link_Key);
         Reload (Item);
         Projects.Touch (Item.Store, Item.Current);
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
               for Side in Items.Sides loop
                  Near := Near or else Widgets.Is_Hovered
                            (Item.Pins (Which, Side));
               end loop;
            end if;
            for Side in Items.Sides loop
               declare
                  Want : constant Boolean :=
                    Is_Open (Item, Which)
                    and then
                      (if Item.Link_From = 0 then Near
                       elsif Item.Link_Moving then Which /= Item.Link_From
                       else Which /= Item.Link_From
                            or else Side = Item.Link_From_Side);
                  Pin : Pins.Pin renames Item.Pins (Which, Side);
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

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Details (Item.Windows (Which)).Kind = Items.Source);

   procedure Draw_Lines (Item : in out Session; Changed : in out Boolean) is

      function Ink_Of
        (Each : Items.Link; From, To : Items.Slot) return UI.Themes.Color is
        (if Is_Source (Item, From) then Canvas_Items.Source_Ink (Item, From)
         elsif Is_Source (Item, To) then Canvas_Items.Source_Ink (Item, To)
         else Style.Link_Inks (Each.Color));
      --  A link to a source is in the source's colour, that the documents
      --  citing it are seen to; others, in the colour chosen for them.

      Lines : Canvases.Line_Array (1 .. Items.Max_Links);
      Count : Natural := 0;
      Chosen : Natural := 0;
      --  The tag of the selected link, if it is drawn.
      Target, Mid : Point := (0.0, 0.0);
   begin
      for Number in 1 .. Item.Link_Set.Count loop
         declare
            Each : Items.Link renames Item.Link_Set.Links (Number);
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
                                   when Items.Solid  => Canvases.Solid,
                                   when Items.Dots   => Canvases.Dotted,
                                   when Items.Dashed => Canvases.Dashed),
                     Arrow  => Each.Ending = Items.Arrow,
                     Ink    => Ink_Of (Each, From, To));
                  if Each.Key = Item.Link_Key then
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
         Pixels : constant Float := Widgets.Density (Item.Widgets);
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
         if Shown /= Widgets.Is_Visible (Item.Link_Handle) then
            if not Shown then
               Pins.Cancel (Item.Link_Handle);
            end if;
            Widgets.Set_Visible (Item.Link_Handle, Shown);
            Widgets.Set_Visible (Item.Link_Bar, Shown);
            Changed := True;
         end if;
         if Shown then
            Move_To (Item.Link_Handle, Spot.X - Half, Spot.Y - Half,
                     Item.Handle_Left, Item.Handle_Top, Changed);
            Move_To (Item.Link_Bar, Float'Rounding (Left),
                     Float'Rounding (Top),
                     Item.Bar_Left, Item.Bar_Top, Changed);
            declare
               Was : constant Items.Link := Item.Link_Set.Links (Chosen);
            begin
               for Each in Items.Strokes loop
                  Buttons.Set_Selected
                    (Item.Stroke_Buttons (Each), Each = Was.Stroke);
               end loop;
               for Each in Items.Endings loop
                  Buttons.Set_Selected
                    (Item.End_Buttons (Each), Each = Was.Ending);
               end loop;
               for Each in Items.Link_Colors loop
                  Buttons.Set_Selected
                    (Item.Color_Buttons (Each), Each = Was.Color);
               end loop;
            end;
         end if;
      end;

      if Item.Link_From /= 0 and then Is_Open (Item, Item.Link_From) then
         declare
            Source : constant Point :=
              Middle (Windows.Details (Item.Windows (Item.Link_From)).Where,
                      Item.Link_From_Side);
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
        Widgets.Widget_Access'(Item.Link_Handle'Unrestricted_Access);
      Count : constant Natural := Widgets.Child_Count (Item.Canvas_View);
   begin
      if Count > 0
        and then Widgets.Child_At (Item.Canvas_View, Count) /= Last
        and then (Widgets.Is_Visible (Item.Link_Handle)
                  or else Widgets.Is_Visible (Item.Link_Bar)
                  or else Shown_Pins (Item) > 0)
      then
         Widgets.Raise_To_Front (Item.Link_Bar);
         for Which in Items.Slot loop
            for Side in Items.Sides loop
               Widgets.Raise_To_Front (Item.Pins (Which, Side));
            end loop;
         end loop;
         Widgets.Raise_To_Front (Item.Link_Handle);
      end if;
   end Raise_Over;

   function Shown_Pins (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Pins loop
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
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Update;

end Viewer.Links;
