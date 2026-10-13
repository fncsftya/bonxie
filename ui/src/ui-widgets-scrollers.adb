with Yoga.Nodes;

package body UI.Widgets.Scrollers is

   use type SDL3.Events.Event_Kind;

   function Offset (Item : Scroller) return Float is (Item.Moved);

   function Bar_Metrics (Item : Scroller) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   => Item.Moved * Density (Item),
      Shown   => Height_Of (Item),
      Total   => (if Child_Count (Item) = 1
                  then Height_Of (Child_At (Item, 1).all) else 0.0),
      Horizontal => False);

   procedure Scroll_To (Item : in out Scroller; To : Float) is
      Child  : constant Widget_Access := Child_At (Item, 1);
      Pixels : constant Float := Density (Item);
      Hidden : constant Float :=
        Float'Max (0.0, (Height_Of (Child.all) - Height_Of (Item)) / Pixels);
      --  How much of the child is out of the box.
      Wanted : constant Float := Float'Min (Hidden, Float'Max (0.0, To));
   begin
      if Wanted /= Item.Moved then
         Item.Moved := Wanted;
         Yoga.Nodes.Set_Position
           (Node (Child.all), Yoga.Top, -Wanted * Pixels);
         Request_Layout (Item);
      end if;
   end Scroll_To;

   overriding procedure Draw_Over
     (Item   : in out Scroller;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme) is
   begin
      if Child_Count (Item) = 1 then
         Scrollbars.Draw (Item.Bar, Target, Colors, Bar_Metrics (Item));
      end if;
   end Draw_Over;

   overriding procedure Hover_Changed
     (Item : in out Scroller; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Bar, Hovered);
      Invalidate (Item);
   end Hover_Changed;

   overriding procedure Handle
     (Item    : in out Scroller;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Child_Count (Item) = 1
        and then Event.Kind in SDL3.Events.Mouse_Down
                             | SDL3.Events.Mouse_Move
                             | SDL3.Events.Mouse_Up
      then
         declare
            Moved, Changed : Boolean;
            To : Float;
         begin
            Scrollbars.Handle
              (Item.Bar, Event, Bar_Metrics (Item), Handled, Moved, To,
               Changed);
            if Moved then
               Scroll_To (Item, To / Density (Item));
            end if;
            if Changed or else Moved then
               Invalidate (Item);
            end if;
            if Handled then
               return;
            end if;
         end;
      end if;
      if Event.Kind = SDL3.Events.Mouse_Wheel
        and then Child_Count (Item) = 1
      then
         Scroll_To (Item, Item.Moved - Event.Wheel_Y * Points_Per_Notch);
         Handled := True;
      end if;
   end Handle;

end UI.Widgets.Scrollers;
