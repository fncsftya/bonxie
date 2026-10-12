package body UI.Widgets is

   package Renderers renames SDL3.Windows.Renderers;

   use type SDL3.Events.Event_Kind;

   --  Boxes

   function Around (Across, Down, Wide, High : Float) return Pixel_Box;
   --  The pixels that any of the box touches.

   function Around (Across, Down, Wide, High : Float) return Pixel_Box is
      First  : constant Integer := Integer (Float'Floor (Across));
      Above  : constant Integer := Integer (Float'Floor (Down));
      Last   : constant Integer := Integer (Float'Ceiling (Across + Wide));
      Below  : constant Integer := Integer (Float'Ceiling (Down + High));
   begin
      return (First, Above, Last - First, Below - Above);
   end Around;

   function Union (A, B : Pixel_Box) return Pixel_Box is
   begin
      if Is_Empty (A) then
         return B;
      elsif Is_Empty (B) then
         return A;
      end if;
      declare
         First  : constant Integer := Integer'Min (A.Left, B.Left);
         Above  : constant Integer := Integer'Min (A.Top, B.Top);
         Last   : constant Integer :=
           Integer'Max (A.Left + A.Width, B.Left + B.Width);
         Below  : constant Integer :=
           Integer'Max (A.Top + A.Height, B.Top + B.Height);
      begin
         return (First, Above, Last - First, Below - Above);
      end;
   end Union;

   function Intersection (A, B : Pixel_Box) return Pixel_Box is
      First  : constant Integer := Integer'Max (A.Left, B.Left);
      Above  : constant Integer := Integer'Max (A.Top, B.Top);
      Last   : constant Integer :=
        Integer'Min (A.Left + A.Width, B.Left + B.Width);
      Below  : constant Integer :=
        Integer'Min (A.Top + A.Height, B.Top + B.Height);
   begin
      return (First, Above,
              Integer'Max (0, Last - First), Integer'Max (0, Below - Above));
   end Intersection;

   function Box_Of (Item : Widget'Class) return Pixel_Box is
     (Around (Item.Box_Left, Item.Box_Top, Item.Box_Width, Item.Box_Height));

   --  The widgets

   function Is_Attached (Item : Widget'Class) return Boolean is
     (Item.Owner /= null);

   function Node (Item : Widget'Class) return Yoga.Nodes.Node is
     (Item.Yoga_Node);

   function Parent_Of (Item : Widget'Class) return Widget_Access is
     (Item.Parent);

   function Child_Count (Item : Widget'Class) return Natural is (Item.Count);

   function Child_At (Item : Widget'Class; Index : Positive)
      return Widget_Access
   is
      Result : Widget_Access := Item.First;
   begin
      for Skipped in 2 .. Index loop
         Result := Result.Next;
      end loop;
      return Result;
   end Child_At;

   function Left_Of (Item : Widget'Class) return Float is (Item.Box_Left);
   function Top_Of (Item : Widget'Class) return Float is (Item.Box_Top);
   function Width_Of (Item : Widget'Class) return Float is (Item.Box_Width);
   function Height_Of (Item : Widget'Class) return Float is
     (Item.Box_Height);
   function Is_Placed (Item : Widget'Class) return Boolean is
     (Item.Placed_Box);

   function Contains (Item : Widget'Class; X, Y : Float) return Boolean is
     (X >= Item.Box_Left and then X < Item.Box_Left + Item.Box_Width
      and then Y >= Item.Box_Top and then Y < Item.Box_Top + Item.Box_Height);

   function Is_Hovered (Item : Widget'Class) return Boolean is
     (Item.Hovered);

   function Painting_Part (Item : Widget'Class) return Pixel_Box is
     (Item.Paint_Box);

   function Is_Visible (Item : Widget'Class) return Boolean is
     (Item.Visible);

   function Is_Shown (Item : Widget'Class) return Boolean is
      Climbing : Widget_Access := Item.Parent;
   begin
      if not Item.Visible then
         return False;
      end if;
      while Climbing /= null loop
         if not Climbing.Visible then
            return False;
         end if;
         Climbing := Climbing.Parent;
      end loop;
      return True;
   end Is_Shown;

   function Has_Focus (Item : Widget'Class) return Boolean is
     (Item.Focused);

   function Density (Item : Widget'Class) return Float is
     (Item.Owner.Density);

   function Is_Settled (Item : Widget'Class) return Boolean is
     (Item.Owner.Settled);

   function Clipboard (Item : Widget'Class) return Clipboard_Access is
     (Item.Owner.Board);

   procedure Handle
     (Item    : in out Widget;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      pragma Unreferenced (Item, Event);
   begin
      Handled := False;
   end Handle;

   --  Building

   function Has_Root (Item : Tree) return Boolean is (Item.Root /= null);

   procedure Set_Root (Item : in out Tree; Root : in out Widget'Class) is
   begin
      Root.Owner := Item'Unchecked_Access;
      Root.Yoga_Node := Yoga.Nodes.Root (Item.Yoga_Tree);
      Item.Root := Root'Unchecked_Access;
   end Set_Root;

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class) is
      Added : constant Widget_Access := Child'Unchecked_Access;
   begin
      Child.Owner := Parent.Owner;
      Child.Parent := Parent'Unchecked_Access;
      Child.Yoga_Node := Yoga.Nodes.New_Child (Parent.Yoga_Node);
      if Parent.Last = null then
         Parent.First := Added;
      else
         Parent.Last.Next := Added;
      end if;
      Parent.Last := Added;
      Parent.Count := Parent.Count + 1;
   end Add;

   --  Walking the tree: parents before their children, and children in
   --  order.

   function Following_Shown (Item : Widget_Access) return Widget_Access;
   --  As Following, but not into widgets that are hidden.

   function Following_Shown (Item : Widget_Access) return Widget_Access is
      Climbing : Widget_Access := Item;
   begin
      if Item.First /= null and then Item.Visible then
         return Item.First;
      end if;
      while Climbing /= null loop
         if Climbing.Next /= null then
            return Climbing.Next;
         end if;
         Climbing := Climbing.Parent;
      end loop;
      return null;
   end Following_Shown;

   --  What a tree shares

   procedure Set_Density (Item : in out Tree; To : Float) is
   begin
      if To /= Item.Density then
         Item.Density := To;
         Item.Replace_All := True;
         Item.Layout_Pending := True;
         Item.Lost := True;
      end if;
   end Set_Density;

   function Density (Item : Tree) return Float is (Item.Density);

   procedure Set_Settled (Item : in out Tree; To : Boolean) is
   begin
      if To /= Item.Settled then
         Item.Settled := To;
         if Item.Root /= null then
            Invalidate (Item.Root.all);
         end if;
      end if;
   end Set_Settled;

   function Is_Settled (Item : Tree) return Boolean is (Item.Settled);

   procedure Set_Clipboard
     (Item : in out Tree; Board : in out Clipboards.Clipboard'Class) is
   begin
      Item.Board := Board'Unchecked_Access;
   end Set_Clipboard;

   procedure Set_Line_Texts
     (Item : in out Tree; Lines : aliased in out Line_Texts.Drawer) is
   begin
      Item.Lines := Lines'Unchecked_Access;
   end Set_Line_Texts;

   procedure Set_Icons
     (Item : in out Tree; Library : aliased in out Icons.Library) is
   begin
      Item.Pictures := Library'Unchecked_Access;
   end Set_Icons;

   function Icon_Library (Item : Widget'Class) return Icons_Access is
     (Item.Owner.Pictures);

   function Text_Lines (Item : Widget'Class) return Line_Texts_Access is
     (Item.Owner.Lines);

   --  Damage

   procedure Damage_Box (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      Item.Owner.Damaged := Union (Item.Owner.Damaged, Part);
   end Damage_Box;

   procedure Invalidate (Item : in out Widget'Class) is
   begin
      --  A widget that has not been placed is damaged when it is.
      if Item.Placed_Box then
         Damage_Box (Item, Box_Of (Item));
      end if;
   end Invalidate;

   procedure Invalidate (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      if Item.Placed_Box then
         Damage_Box (Item, Intersection (Part, Box_Of (Item)));
      end if;
   end Invalidate;

   procedure Invalidate_All (Item : in out Tree) is
   begin
      Item.Lost := True;
   end Invalidate_All;

   procedure Request_Layout (Item : in out Widget'Class) is
   begin
      Item.Owner.Layout_Pending := True;
   end Request_Layout;

   function Needs_Paint (Item : Tree) return Boolean is
     (Item.Lost or else Item.Layout_Pending
      or else not Is_Empty (Item.Damaged));

   function Damage (Item : Tree) return Pixel_Box is (Item.Damaged);

   --  Layout

   procedure Place
     (Item    : in out Tree;
      Placing : Widget_Access;
      Across, Down : Float);
   --  Place Placing, whose parent is at Across, Down, and its children.

   procedure Place
     (Item    : in out Tree;
      Placing : Widget_Access;
      Across, Down : Float)
   is
      Own_Left : constant Float :=
        Across + Yoga.Nodes.Left (Placing.Yoga_Node);
      Own_Top  : constant Float :=
        Down + Yoga.Nodes.Top (Placing.Yoga_Node);
      Wide     : constant Float := Yoga.Nodes.Width (Placing.Yoga_Node);
      High     : constant Float := Yoga.Nodes.Height (Placing.Yoga_Node);
      Child    : Widget_Access := Placing.First;
   begin
      if Item.Replace_All or else not Placing.Placed_Box
        or else Own_Left /= Placing.Box_Left
        or else Own_Top /= Placing.Box_Top
        or else Wide /= Placing.Box_Width
        or else High /= Placing.Box_Height
      then
         if Placing.Placed_Box then
            Item.Damaged := Union (Item.Damaged, Box_Of (Placing.all));
         end if;
         Placing.Placed_Box := True;
         Placing.Box_Left := Own_Left;
         Placing.Box_Top := Own_Top;
         Placing.Box_Width := Wide;
         Placing.Box_Height := High;
         Item.Damaged := Union (Item.Damaged, Box_Of (Placing.all));
         Placed (Placing.all, Own_Left, Own_Top, Wide, High);
      end if;
      while Child /= null loop
         Place (Item, Child, Own_Left, Own_Top);
         Child := Child.Next;
      end loop;
   end Place;

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Windows.Renderers.Renderer)
   is
      Pixels_Wide, Pixels_High : Natural;
   begin
      Renderers.Output_Size (Target, Pixels_Wide, Pixels_High);
      Yoga.Nodes.Calculate_Layout
        (Item.Yoga_Tree, Float (Pixels_Wide), Float (Pixels_High));
      Place (Item, Item.Root, 0.0, 0.0);
      Item.Replace_All := False;
      Item.Layout_Pending := False;
   end Layout;

   --  Drawing

   procedure Paint_Widget
     (Painting : in out Widget'Class;
      Target   : Renderers.Renderer;
      Colors   : Themes.Theme;
      Region   : Pixel_Box);
   --  Draw Painting and its children, if they are in Region, which is
   --  the clip.

   procedure Paint_Widget
     (Painting : in out Widget'Class;
      Target   : Renderers.Renderer;
      Colors   : Themes.Theme;
      Region   : Pixel_Box)
   is
      Box : constant Pixel_Box := Intersection (Box_Of (Painting), Region);
   begin
      if Is_Empty (Box) or else not Painting.Visible then
         return;
      end if;
      declare
         Outer : constant Renderers.Clip := Renderers.Current_Clip (Target);
         Child : Widget_Access := Painting.First;
      begin
         Renderers.Narrow_Clip
           (Target, Box.Left, Box.Top, Box.Width, Box.Height);
         Painting.Paint_Box := Box;
         Draw (Painting, Target, Colors);
         while Child /= null loop
            Paint_Widget (Child.all, Target, Colors, Box);
            Child := Child.Next;
         end loop;
         Renderers.Restore_Clip (Target, Outer);
      end;
   end Paint_Widget;

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Windows.Renderers.Renderer;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
   is
      Pixels_Wide, Pixels_High : Natural;
   begin
      Renderers.Output_Size (Target, Pixels_Wide, Pixels_High);
      Layout (Item, Target);
      declare
         Everything : constant Pixel_Box := (0, 0, Pixels_Wide, Pixels_High);
         Whole      : constant Boolean :=
           not Retained or else Item.Lost
           or else Pixels_Wide /= Item.Painted_Width
           or else Pixels_High /= Item.Painted_Height;
         Region     : constant Pixel_Box :=
           (if Whole then Everything
            else Intersection (Item.Damaged, Everything));
         Outer      : constant Renderers.Clip :=
           Renderers.Current_Clip (Target);
      begin
         if not Is_Empty (Region) then
            Renderers.Narrow_Clip
              (Target, Region.Left, Region.Top, Region.Width, Region.Height);
            if Whole then
               Renderers.Clear (Target, Colors.Background);
            else
               Renderers.Fill_Rect
                 (Target, Colors.Background,
                  Float (Region.Left), Float (Region.Top),
                  Float (Region.Width), Float (Region.Height));
            end if;
            Paint_Widget (Item.Root.all, Target, Colors, Region);
            Renderers.Restore_Clip (Target, Outer);
         end if;
      end;
      Item.Damaged := (others => 0);
      Item.Lost := False;
      Item.Painted_Width := Pixels_Wide;
      Item.Painted_Height := Pixels_High;
   end Paint;

   --  Focus and the pointer

   procedure Set_Focus (Item : in out Tree; To : Widget_Access);
   --  Take the focus from the widget that has it, and give it to To, if
   --  it is not null.

   procedure Set_Focus (Item : in out Tree; To : Widget_Access) is
      Was : constant Widget_Access := Item.Focus;
   begin
      if To /= Was then
         Item.Focus := To;
         if Was /= null then
            Was.Focused := False;
            Focus_Changed (Was.all, False);
         end if;
         if To /= null then
            To.Focused := True;
            Focus_Changed (To.all, True);
         end if;
      end if;
   end Set_Focus;

   procedure Focus (Item : in out Widget'Class) is
   begin
      Set_Focus (Item.Owner.all, Item'Unchecked_Access);
   end Focus;

   procedure Release_Focus (Item : in out Widget'Class) is
   begin
      if Item.Focused then
         Set_Focus (Item.Owner.all, null);
      end if;
   end Release_Focus;

   procedure Clear_Focus (Item : in out Tree) is
   begin
      Set_Focus (Item, null);
   end Clear_Focus;

   function Focus_Of (Item : Tree) return Widget_Access is (Item.Focus);

   function Within (Item, Inside : Widget_Access) return Boolean;
   --  Whether Item is Inside or in it.

   function Within (Item, Inside : Widget_Access) return Boolean is
      Climbing : Widget_Access := Item;
   begin
      while Climbing /= null loop
         if Climbing = Inside then
            return True;
         end if;
         Climbing := Climbing.Parent;
      end loop;
      return False;
   end Within;

   procedure Set_Hover (Item : in out Tree; To : Widget_Access);
   --  The pointer is over To, or nothing.

   procedure Set_Hover (Item : in out Tree; To : Widget_Access) is
      Was      : constant Widget_Access := Item.Hover;
      Climbing : Widget_Access;
   begin
      if To = Was then
         return;
      end if;
      Item.Hover := To;
      --  Those the pointer has left, and then those it has come over: not
      --  those it moved between.
      Climbing := Was;
      while Climbing /= null loop
         if not Within (To, Climbing) then
            Climbing.Hovered := False;
            Hover_Changed (Climbing.all, False);
         end if;
         Climbing := Climbing.Parent;
      end loop;
      Climbing := To;
      while Climbing /= null loop
         if not Climbing.Hovered then
            Climbing.Hovered := True;
            Hover_Changed (Climbing.all, True);
         end if;
         Climbing := Climbing.Parent;
      end loop;
   end Set_Hover;

   --  Showing, hiding and removing

   procedure Let_Go (Item : in out Tree; Of_Widget : Widget_Access);
   --  Take what the tree gives to Of_Widget or what is in it, as the
   --  focus, the pointer and a press, away, as it goes.

   procedure Let_Go (Item : in out Tree; Of_Widget : Widget_Access) is
   begin
      if Within (Item.Focus, Of_Widget) then
         Set_Focus (Item, null);
      end if;
      if Within (Item.Hover, Of_Widget) then
         --  The pointer is over what the widget was in, if anything.
         Set_Hover (Item, Of_Widget.Parent);
      end if;
      if Within (Item.Capture, Of_Widget) then
         Item.Capture := null;
      end if;
   end Let_Go;

   procedure Set_Visible (Item : in out Widget'Class; To : Boolean) is
      Hiding : constant Widget_Access := Item'Unchecked_Access;
   begin
      if To = Item.Visible then
         return;
      end if;
      if not To then
         Let_Go (Item.Owner.all, Hiding);
         Invalidate (Item);
      end if;
      Item.Visible := To;
      Yoga.Nodes.Set_Display
        (Item.Yoga_Node, (if To then Yoga.Flex else Yoga.None));
      Request_Layout (Item);
   end Set_Visible;

   procedure Detach (Item : Widget_Access);
   --  Make Item, and all in it, as they were before they were added.

   procedure Detach (Item : Widget_Access) is
      Child   : Widget_Access := Item.First;
      Next    : Widget_Access;
      No_Node : Yoga.Nodes.Node;
   begin
      while Child /= null loop
         Next := Child.Next;
         Detach (Child);
         Child := Next;
      end loop;
      Item.Owner := null;
      Item.Parent := null;
      Item.First := null;
      Item.Last := null;
      Item.Next := null;
      Item.Count := 0;
      Item.Yoga_Node := No_Node;
      Item.Placed_Box := False;
      Item.Box_Left := 0.0;
      Item.Box_Top := 0.0;
      Item.Box_Width := 0.0;
      Item.Box_Height := 0.0;
      Item.Hovered := False;
      Item.Focused := False;
      Item.Visible := True;
      Item.Paint_Box := (others => 0);
   end Detach;

   procedure Remove (Item : in out Widget'Class) is
      Removing : constant Widget_Access := Item'Unchecked_Access;
      Owner    : constant Tree_Access := Item.Owner;
      Above    : constant Widget_Access := Item.Parent;
      Before   : Widget_Access := Above.First;
   begin
      Let_Go (Owner.all, Removing);
      Invalidate (Item);
      Request_Layout (Item);

      --  Out of its parent's children.
      if Before = Removing then
         Above.First := Item.Next;
         if Above.Last = Removing then
            Above.Last := null;
         end if;
      else
         while Before.Next /= Removing loop
            Before := Before.Next;
         end loop;
         Before.Next := Item.Next;
         if Above.Last = Removing then
            Above.Last := Before;
         end if;
      end if;
      Above.Count := Above.Count - 1;

      Yoga.Nodes.Delete (Above.Yoga_Node, Item.Yoga_Node);
      Detach (Removing);
   end Remove;

   procedure Raise_To_Front (Item : in out Widget'Class) is
      Raising : constant Widget_Access := Item'Unchecked_Access;
      Above   : constant Widget_Access := Item.Parent;
      Before  : Widget_Access := Above.First;
   begin
      if Above.Last = Raising then
         return;
      end if;
      if Before = Raising then
         Above.First := Item.Next;
      else
         while Before.Next /= Raising loop
            Before := Before.Next;
         end loop;
         Before.Next := Item.Next;
      end if;
      Above.Last.Next := Raising;
      Above.Last := Raising;
      Item.Next := null;
      Invalidate (Item);
   end Raise_To_Front;

   function Hit (Item : Tree; X, Y : Float) return Widget_Access is
      Found : Widget_Access := null;
      Level : Widget_Access := Item.Root;
   begin
      --  Down through the last child that has the point, at each level.
      while Level /= null and then Level.Visible
        and then Contains (Level.all, X, Y)
      loop
         Found := Level;
         declare
            Child : Widget_Access := Level.First;
         begin
            Level := null;
            while Child /= null loop
               if Child.Visible and then Contains (Child.all, X, Y) then
                  Level := Child;
               end if;
               Child := Child.Next;
            end loop;
         end;
      end loop;
      return Found;
   end Hit;

   --  Events

   procedure Bubble
     (From    : Widget_Access;
      Event   : SDL3.Events.Event;
      Taker   : out Widget_Access);
   --  Offer Event to From, and then its parents, until one takes it.

   procedure Bubble
     (From    : Widget_Access;
      Event   : SDL3.Events.Event;
      Taker   : out Widget_Access)
   is
      Offered : Widget_Access := From;
      Handled : Boolean;
   begin
      Taker := null;
      while Offered /= null loop
         Handle (Offered.all, Event, Handled);
         if Handled then
            Taker := Offered;
            return;
         end if;
         Offered := Offered.Parent;
      end loop;
   end Bubble;

   function Accepting (From : Widget_Access) return Widget_Access;
   --  From, or the nearest of its parents, that accepts the focus.

   function Accepting (From : Widget_Access) return Widget_Access is
      Climbing : Widget_Access := From;
   begin
      while Climbing /= null and then not Accepts_Focus (Climbing.all) loop
         Climbing := Climbing.Parent;
      end loop;
      return Climbing;
   end Accepting;

   procedure Dispatch_Press
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Over    : Widget_Access;
      Handled : out Boolean);

   procedure Dispatch_Press
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Over    : Widget_Access;
      Handled : out Boolean)
   is
      Accepts : constant Widget_Access := Accepting (Over);
      Taker   : Widget_Access;
   begin
      if Accepts /= null then
         Set_Focus (Item, Accepts);
      end if;
      Bubble (Over, Event, Taker);
      Handled := Taker /= null;
      if Taker /= null then
         Item.Capture := Taker;
         Item.Capture_Button := Event.Button;
      elsif Accepts = null and then Item.Focus /= null then
         --  A click elsewhere takes the focus away.
         Set_Focus (Item, null);
         Handled := True;
      end if;
   end Dispatch_Press;

   procedure Dispatch_Keys
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   procedure Dispatch_Keys
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Taker   : Widget_Access;
      Offered : Widget_Access;
   begin
      Bubble (Item.Focus, Event, Taker);
      Handled := Taker /= null;
      if not Handled and then Event.Kind = SDL3.Events.Key_Down then
         Offered := Item.Root;
         while Offered /= null and then not Handled loop
            if Offered.Visible then
               Handle (Offered.all, Event, Handled);
            end if;
            Offered := Following_Shown (Offered);
         end loop;
      end if;
   end Dispatch_Keys;

   procedure Dispatch
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Over  : Widget_Access;
      Taker : Widget_Access;
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            Over := Hit (Item, Event.Mouse_X * Item.Density,
                         Event.Mouse_Y * Item.Density);
            Dispatch_Press (Item, Event, Over, Handled);

         when SDL3.Events.Mouse_Move | SDL3.Events.Mouse_Up =>
            Over := Hit (Item, Event.Mouse_X * Item.Density,
                         Event.Mouse_Y * Item.Density);
            Set_Hover (Item, Over);
            if Item.Capture /= null then
               Handle (Item.Capture.all, Event, Handled);
               if Event.Kind = SDL3.Events.Mouse_Up
                 and then Event.Button = Item.Capture_Button
               then
                  Item.Capture := null;
               elsif Event.Kind = SDL3.Events.Mouse_Move
                 and then Item.Capture_Button = 1
                 and then not Event.Left_Held
               then
                  Item.Capture := null;  --  let go where it was not seen
               end if;
            else
               Bubble (Over, Event, Taker);
               Handled := Taker /= null;
            end if;

         when SDL3.Events.Mouse_Wheel | SDL3.Events.Pinch =>
            Over := Hit (Item, Event.Mouse_X * Item.Density,
                         Event.Mouse_Y * Item.Density);
            Bubble (Over, Event, Taker);
            Handled := Taker /= null;

         when SDL3.Events.Key_Down | SDL3.Events.Text_Input
            | SDL3.Events.Text_Editing =>
            Dispatch_Keys (Item, Event, Handled);

         when SDL3.Events.Quit | SDL3.Events.Redraw | SDL3.Events.Other =>
            null;
      end case;
   end Dispatch;

   function Wanted_Cursor (Item : Tree) return SDL3.Cursors.Kind is
      use type SDL3.Cursors.Kind;
      Asking : Widget_Access :=
        (if Item.Capture /= null then Item.Capture else Item.Hover);
   begin
      while Asking /= null loop
         if Cursor (Asking.all) /= SDL3.Cursors.Default then
            return Cursor (Asking.all);
         end if;
         Asking := (if Item.Capture /= null then null else Asking.Parent);
      end loop;
      return SDL3.Cursors.Default;
   end Wanted_Cursor;

   --  Time

   procedure Update (Item : in out Tree; Now : SDL3.Events.Milliseconds) is
      Updating : Widget_Access := Item.Root;
   begin
      while Updating /= null loop
         if Updating.Visible then
            Update (Updating.all, Now);
         end if;
         Updating := Following_Shown (Updating);
      end loop;
   end Update;

   function Until_Update (Item : Tree) return Integer is
      Asking : Widget_Access := Item.Root;
      Result : Integer := -1;
   begin
      while Asking /= null loop
         if Asking.Visible then
            declare
               Wait : constant Integer := Until_Update (Asking.all);
            begin
               if Wait >= 0 and then (Result < 0 or else Wait < Result) then
                  Result := Wait;
               end if;
            end;
         end if;
         Asking := Following_Shown (Asking);
      end loop;
      return Result;
   end Until_Update;

end UI.Widgets;
