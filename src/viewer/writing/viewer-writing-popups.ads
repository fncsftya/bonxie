--  The menu of a page's sources.
private package Viewer.Writing.Popups is

   Rows_Before : constant := 1;
   --  The heading, before the boxes of the sources.

   procedure Close_Menu (Item : in out Session);
   --  Put the menu of sources away.

   procedure Close_Context (Item : in out Session);
   --  Put the menu of a row away.

   function Add_Row (Item : Session) return Positive;
   --  After the boxes (or the note that there are none), and a line.

   procedure Open_Menu (Item : in out Session; Rank : Positive);
   --  Show the menu of the sources the Rankth page's document is linked
   --  to, under its button, which looks pressed in while it is shown; or
   --  put it away, if it is shown already.

end Viewer.Writing.Popups;
