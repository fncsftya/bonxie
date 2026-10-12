with Ada.Numerics.Elementary_Functions;
with UI.Widgets;

package body Viewer.Zooming is

   package Widgets renames UI.Widgets;
   package Editors renames UI.Widgets.Editors;

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;

   Min_Zoom       : constant Float := 0.25;
   Max_Zoom       : constant Float := 8.0;
   Zoom_Per_Notch : constant Float := 1.1;

   procedure Zoom_By (Item : in out Session; Factor : Float) is
      Zoom : constant Float :=
        Float'Min (Max_Zoom, Float'Max (Min_Zoom, Item.Zoom * Factor));
   begin
      if Zoom /= Item.Zoom then
         Item.Zoom := Zoom;
         Item.Settled := False;
         Widgets.Set_Settled (Item.Widgets, False);
         Editors.Set_Zoom (Item.Area, Zoom);
         --  Before the next event, which may be over the text.
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Zoom_By;

   procedure Handle
     (Item : in out Session; Event : SDL3.Events.Event; Handled : out Boolean)
   is
   begin
      Handled := True;
      Item.Zoomed_At := Event.Time;
      if Event.Kind = SDL3.Events.Mouse_Wheel and then Event.Command then
         Zoom_By
           (Item,
            Ada.Numerics.Elementary_Functions."**"
              (Zoom_Per_Notch, Event.Wheel_Y));
      elsif Event.Kind /= SDL3.Events.Key_Down or else not Event.Command then
         Handled := False;
      elsif Event.Key = SDL3.Events.Key_Equals then
         Zoom_By (Item, Zoom_Per_Notch);
      elsif Event.Key = SDL3.Events.Key_Minus then
         Zoom_By (Item, 1.0 / Zoom_Per_Notch);
      elsif Event.Key = SDL3.Events.Key_0 then
         Zoom_By (Item, 1.0 / Item.Zoom);
      else
         Handled := False;
      end if;
   end Handle;

end Viewer.Zooming;
