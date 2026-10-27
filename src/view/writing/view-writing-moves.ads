--  Putting a page elsewhere in the order, or in another directory.

private package View.Writing.Moves is

   procedure Move_Page (Item : in out Session; From, To : Positive)
   with Pre => From <= Trees.Page_Count (Item.Docs.Ordering) and then To <= Trees.Page_Count (Item.Docs.Ordering);
   --  Put the From-th page at the To-th, and keep the order.

   procedure Move_Page_To_Directory (Item : in out Session; Rank : Positive; Directory : Natural)
   with Pre => Rank <= Trees.Page_Count (Item.Docs.Ordering) and then Directory <= Item.Docs.Dirs.Count;
   --  Put the Rankth page last in the directory (none, if 0), and keep it.

   procedure Drop_Row (Item : in out Session; Row : Positive; Target : Drop_Target);
   --  Put the row where it was dropped.

end View.Writing.Moves;
