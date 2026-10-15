--  What is done by the pointer's and the keys' gestures, which are asked of
--  the widgets as they go on, rather than said when they end: an item's
--  window dragged, a field left, a title pressed twice. A button's click is
--  said as it happens, and is done by Viewer.Responses.
private package Viewer.Gestures is

   procedure Take (Item : in out Session);
   --  Do what the gestures asked.

end Viewer.Gestures;
