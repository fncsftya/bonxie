--  Putting a page elsewhere in the order, or in another directory.
private package Viewer.Writing.Moves is

   procedure Move_Page (Item : in out Session; From, To : Positive)
     with Pre => From <= Item.Reading.Write_Count
      and then To <= Item.Reading.Write_Count;
   --  Put the From-th page at the To-th, and keep the order.

   procedure Move_Page_To_Directory
     (Item : in out Session; Rank : Positive; Directory : Natural)
     with Pre => Rank <= Item.Reading.Write_Count
                 and then Directory <= Item.Docs.Dirs.Count;
   --  Put the Rankth page last in the directory (none, if 0), and keep it.

   procedure Drop_Row
     (Item : in out Session; Row : Positive; Target : Drop_Target);
   --  Put the row where it was dropped.

end Viewer.Writing.Moves;
