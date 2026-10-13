with UI.Widgets;
with UI.Widgets.Canvases;
with UI.Widgets.Pins;
with Yoga.Nodes;

package body Viewer.Links is

   package Widgets renames UI.Widgets;
   package Canvases renames UI.Widgets.Canvases;
   package Pins renames UI.Widgets.Pins;
   package Windows renames Items.Windows;

   use type Widgets.Widget_Access;
   use type Items.Id;
   use type Items.Sides;
   use type Items.States;

   pragma Assert (Canvases.Max_Lines >= Items.Max_Links);

   function Diameter (Item : Session) return Float is
     (Float'Rounding (Pins.Diameter * Widgets.Density (Item.Widgets)));
   --  Of a pin, in pixels.

   function Is_Open (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).State = Items.Open);

   function Middle
     (Where : Items.Frame; Side : Items.Sides) return Canvases.Line
   is
      Across : constant Float := Where.Left + Where.Width / 2.0;
      Down   : constant Float := Where.Top + Where.Height / 2.0;
      Right  : constant Float := Where.Left + Where.Width;
      Bottom : constant Float := Where.Top + Where.Height;
   begin
      --  Only the place, in From_X, From_Y.
      return (case Side is
                 when Items.Top    => (Across, Where.Top, 0.0, 0.0),
                 when Items.Right  => (Right, Down, 0.0, 0.0),
                 when Items.Bottom => (Across, Bottom, 0.0, 0.0),
                 when Items.Left   => (Where.Left, Down, 0.0, 0.0));
   end Middle;
   --  The middle of the side of the window, in canvas units.

   procedure Put_Pin
     (Item    : in out Session;
      Which   : Items.Slot;
      Side    : Items.Sides;
      Changed : in out Boolean);
   --  Put the pin at the middle of its side of the window, in pixels, as
   --  Windows.Place has the window. Changed is set if it was not there.

   procedure Put_Pin
     (Item    : in out Session;
      Which   : Items.Slot;
      Side    : Items.Sides;
      Changed : in out Boolean)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Zoom   : constant Float := Item.Shown_Zoom;
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
      Left   : constant Float :=
        Float'Rounding ((Item.Shown_X + Where.Left * Zoom) * Pixels);
      Top    : constant Float :=
        Float'Rounding ((Item.Shown_Y + Where.Top * Zoom) * Pixels);
      Wide   : constant Float := Float'Rounding (Where.Width * Zoom * Pixels);
      High   : constant Float := Float'Rounding (Where.Height * Zoom * Pixels);
      Half   : constant Float := Diameter (Item) / 2.0;
      Across : constant Float := Float'Rounding (Left + Wide / 2.0);
      Down   : constant Float := Float'Rounding (Top + High / 2.0);
      Centre_X : constant Float :=
        (case Side is
            when Items.Top | Items.Bottom => Across,
            when Items.Left  => Left,
            when Items.Right => Left + Wide);
      Centre_Y : constant Float :=
        (case Side is
            when Items.Left | Items.Right => Down,
            when Items.Top  => Top,
            when Items.Bottom => Top + High);
      Pin    : Pins.Pin renames Item.Pins (Which, Side);
   begin
      if Item.Pin_Left (Which, Side) /= Centre_X - Half
        or else Item.Pin_Top (Which, Side) /= Centre_Y - Half
      then
         Item.Pin_Left (Which, Side) := Centre_X - Half;
         Item.Pin_Top (Which, Side) := Centre_Y - Half;
         Set_Position (Widgets.Node (Pin), Yoga.Left, Centre_X - Half);
         Set_Position (Widgets.Node (Pin), Yoga.Top, Centre_Y - Half);
         Widgets.Request_Layout (Pin);
         Changed := True;
      end if;
   end Put_Pin;

   procedure Build (Item : in out Session) is
      use Yoga.Nodes;
   begin
      for Which in Items.Slot loop
         for Side in Items.Sides loop
            declare
               Pin : Pins.Pin renames Item.Pins (Which, Side);
            begin
               Widgets.Add (Item.Canvas_View, Pin);
               Set_Position_Type (Widgets.Node (Pin), Yoga.Absolute);
               Set_Width (Widgets.Node (Pin), Diameter (Item));
               Set_Height (Widgets.Node (Pin), Diameter (Item));
               Widgets.Set_Visible (Pin, False);
            end;
         end loop;
      end loop;
   end Build;

   procedure Reload (Item : in out Session) is
   begin
      Items.Load_Links (Item.Store, Item.Current, Item.Link_Set);
   end Reload;

   procedure Enter (Item : in out Session) is
   begin
      Item.Link_From := 0;
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
      Set_Accepting (Item, 0);
      Item.Link_From := 0;
      Item.Link_Set.Count := 0;
      Canvases.Clear_Ghost (Item.Canvas_View);
      Canvases.Set_Lines (Item.Canvas_View, []);
   end Leave;

   procedure Make_Link (Item : in out Session; To : Items.Slot;
                        To_Side : Items.Sides);
   --  Join the item whose pin was dragged from to the one of this pin.

   procedure Make_Link (Item : in out Session; To : Items.Slot;
                        To_Side : Items.Sides)
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
             To_Side   => To_Side),
            Added);
         if Added then
            Reload (Item);
            Projects.Touch (Item.Store, Item.Current);
         end if;
      end if;
   end Make_Link;

   procedure Take_Drags (Item : in out Session);
   --  Start a drag from a pin that was pressed, and end it where the
   --  button was let go.

   procedure Take_Drags (Item : in out Session) is
      Pressed, Released : Boolean;
   begin
      for Which in Items.Slot loop
         for Side in Items.Sides loop
            Pins.Take_Press (Item.Pins (Which, Side), Pressed);
            if Pressed and then Item.Link_From = 0 then
               Item.Link_From := Which;
               Item.Link_From_Side := Side;
               Set_Accepting (Item, Which);
            end if;
         end loop;
      end loop;
      if Item.Link_From /= 0 then
         Pins.Take_Release
           (Item.Pins (Item.Link_From, Item.Link_From_Side), Released);
         if Released then
            --  The pointer is over the pin it was let go on, if any.
            for Which in Items.Slot loop
               for Side in Items.Sides loop
                  if Which /= Item.Link_From
                    and then Widgets.Is_Shown (Item.Pins (Which, Side))
                    and then Widgets.Is_Hovered (Item.Pins (Which, Side))
                  then
                     Make_Link (Item, Which, Side);
                  end if;
               end loop;
            end loop;
            Item.Link_From := 0;
            Set_Accepting (Item, 0);
         end if;
      end if;
   end Take_Drags;

   procedure Show_Pins (Item : in out Session);
   --  Show the pins of the window the pointer is over, or, in a drag, of
   --  all the others; and put them where they go.

   procedure Show_Pins (Item : in out Session) is
      Any     : Boolean := False;
      Changed : Boolean := False;
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
                      (if Item.Link_From /= 0
                       then Which /= Item.Link_From
                            or else Side = Item.Link_From_Side
                       else Near);
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
                     Any := True;
                     Put_Pin (Item, Which, Side, Changed);
                  end if;
               end;
            end loop;
         end;
      end loop;
      --  Over the windows, whichever was used last.
      if Any then
         declare
            Last : constant Widgets.Widget_Access :=
              Widgets.Widget_Access'
                (Item.Pins (Items.Slot'Last, Items.Sides'Last)
                   'Unrestricted_Access);
            Count : constant Natural := Widgets.Child_Count (Item.Canvas_View);
         begin
            if Count > 0 and then Widgets.Child_At (Item.Canvas_View, Count)
                                  /= Last
            then
               for Which in Items.Slot loop
                  for Side in Items.Sides loop
                     Widgets.Raise_To_Front (Item.Pins (Which, Side));
                  end loop;
               end loop;
            end if;
         end;
      end if;
      --  So that the next event finds them where they are.
      if Changed then
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Show_Pins;

   procedure Draw_Lines (Item : in out Session);
   --  Set the lines of the links and of the drag.

   procedure Draw_Lines (Item : in out Session) is
      Lines : Canvases.Line_Array (1 .. Items.Max_Links);
      Count : Natural := 0;

      function Slot_Of (Key : Items.Id) return Natural is
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
   begin
      for Each of Item.Link_Set.Links (1 .. Item.Link_Set.Count) loop
         declare
            From : constant Natural := Slot_Of (Each.From);
            To   : constant Natural := Slot_Of (Each.To);
         begin
            if From /= 0 and then To /= 0 then
               declare
                  A : constant Canvases.Line :=
                    Middle (Windows.Details (Item.Windows (From)).Where,
                            Each.From_Side);
                  B : constant Canvases.Line :=
                    Middle (Windows.Details (Item.Windows (To)).Where,
                            Each.To_Side);
               begin
                  Count := Count + 1;
                  Lines (Count) := (A.From_X, A.From_Y, B.From_X, B.From_Y);
               end;
            end if;
         end;
      end loop;
      Canvases.Set_Lines (Item.Canvas_View, Lines (1 .. Count));
      if Item.Link_From /= 0 and then Is_Open (Item, Item.Link_From) then
         declare
            Source : constant Canvases.Line :=
              Middle (Windows.Details (Item.Windows (Item.Link_From)).Where,
                      Item.Link_From_Side);
            Pin : Pins.Pin renames
              Item.Pins (Item.Link_From, Item.Link_From_Side);
         begin
            Canvases.Set_Ghost
              (Item.Canvas_View, Source.From_X, Source.From_Y,
               Pins.Pointer_X (Pin), Pins.Pointer_Y (Pin));
         end;
      else
         Canvases.Clear_Ghost (Item.Canvas_View);
      end if;
   end Draw_Lines;

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
   begin
      Take_Drags (Item);
      Show_Pins (Item);
      Draw_Lines (Item);
   end Update;

end Viewer.Links;
