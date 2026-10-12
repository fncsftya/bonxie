with Yoga.Nodes;

package body UI.Widgets.Scrollers is

   use type SDL3.Events.Event_Kind;

   function Offset (Item : Scroller) return Float is (Item.Moved);

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

   overriding procedure Handle
     (Item    : in out Scroller;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Event.Kind = SDL3.Events.Mouse_Wheel
        and then Child_Count (Item) = 1
      then
         Scroll_To (Item, Item.Moved - Event.Wheel_Y * Points_Per_Notch);
         Handled := True;
      end if;
   end Handle;

end UI.Widgets.Scrollers;
