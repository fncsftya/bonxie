--  What the rest of the canvas's items share: the time, the kind of an item, and marking the project as touched.

private package View.Canvas_Items.Basics is

   function Epoch_Now (Item : Session) return Projects.Seconds;
   --  As SQLite's unixepoch.

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean;

   procedure Touch (Item : in out Session);
   --  Say the project has been changed, so that it is listed first.

end View.Canvas_Items.Basics;
