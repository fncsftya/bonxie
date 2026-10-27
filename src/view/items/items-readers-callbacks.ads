--  Who hears what a reader's buttons ask for, apart from what the reader
--  does itself (move and size, zoom, mark): to close it, or to pin it, or
--  let go of the pinned one.
--
--     package Mine is new Items.Readers.Callbacks (Session);
--     Mine.On (Reader, Which, Session'Access, Asked'Access);

generic
   type Context is limited private;
package Items.Readers.Callbacks is

   type Handler is access procedure (Self : in out Context; Which : Natural; Action : Actions);
   --  Which is as given to On: a window's slot, or 0 for the pinned one.

   procedure On (Item : in out Reader; Which : Natural; Self : not null access Context; Do_This : not null Handler);
   --  When Item's buttons ask for an Action, call Do_This with Self and
   --  Which. Self must be there as long as Item is in use.

end Items.Readers.Callbacks;
