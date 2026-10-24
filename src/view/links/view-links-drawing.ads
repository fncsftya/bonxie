--  Putting the pins and drawing the lines between them.
private package View.Links.Drawing is

   procedure Show_Pins (Item : in out Session; Changed : in out Boolean);
   --  Show the pins of the window the pointer is over, or, in a drag, of
   --  all the others (but, to move a link, not of the window it starts
   --  from); and put them where they go.

   procedure Draw_Lines (Item : in out Session; Changed : in out Boolean);
   --  Set the lines of the links and of the drag, and show the handle and
   --  the toolbar of the link selected, where it is.

   procedure Raise_Over (Item : in out Session);
   --  Put the toolbar, the pins and the handle over the windows, in that
   --  order, if a window has been raised over them.

end View.Links.Drawing;
