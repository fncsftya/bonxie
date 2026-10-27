--  The home screen, the project screen's header, tray and publish view.
private package View.Build.Shell_Views is

   procedure Build_Header (Item : in out Session);
   --  Add and style the bar across the top of a window.

   procedure Build_Home (Item : in out Session);
   --  Add and style the home screen's widgets.

   procedure Build_Project (Item : in out Session);
   --  Add and style the project screen's widgets.

   procedure Make_Window (Item : in out Session; Which : Items.Slot);
   --  Add and style the window of the item in the slot: on the canvas, or
   --  as a bar in the dock.

   procedure Build_Tray (Item : in out Session);
   --  Add and style the tray of the canvas's tools: over it, after the
   --  writing view, so over that too, at the foot (see
   --  Canvas_Items.Sync, which puts it in the middle).

   procedure Build_Publish (Item : in out Session);

end View.Build.Shell_Views;
