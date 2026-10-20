--  Linking the project's items: a round pin in the middle of each side of
--  a window, shown while the pointer is over it. A drag from a pin shows
--  the pins of the other windows and a faint line to the pointer; let go
--  on one of them, it makes a link between the two items, which is kept
--  in the database and drawn as a line from pin to pin.
--
--  A link can be selected, by a press on its line: it is drawn with a
--  halo, a pin shows over its target end, which can be dragged to another
--  pin of any window but the one it starts from, and a small toolbar beside
--  it chooses how it is drawn (stroke, end, colour, all kept) and deletes
--  it, as Backspace does.
private package Viewer.Links is

   procedure Build (Item : in out Session);
   --  Add the pins and the toolbar to the canvas, hidden, once the windows
   --  have been built, with the density known.

   procedure Make_Pins (Item : in out Session; Which : Items.Slot);
   --  Add the pins of the window in the slot to the canvas, hidden, and
   --  have them listened to.

   procedure Enter (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Load the project's links, once its windows are on the canvas.

   procedure Leave (Item : in out Session);
   --  Put the pins and lines away.

   procedure Reload (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Read the links again, as of an item that was removed with its
   --  links.

   procedure Update (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Show the pins where the pointer is, put them at the windows' edges,
   --  take what has been dragged from them and let go on, and clicked on
   --  the toolbar, and draw the links and the line being dragged. Do it
   --  when the windows have been put where the canvas has them.

   function Shown_Pins (Item : Session) return Natural;
   --  How many pins are shown, of those on the windows.

end Viewer.Links;
