with Pomarine.Widgets;

--  What the buttons, checks and menus are for: what is done when each says
--  that it was clicked (see Viewer.Build, which gives each its Command).
private package Viewer.Responses is

   procedure Respond
     (Item  : in out Session;
      Event : Pomarine.Widgets.Widget_Event);
   --  Do what the widget that said Event was for. Events of widgets that
   --  were given no Command are not for this.

end Viewer.Responses;
