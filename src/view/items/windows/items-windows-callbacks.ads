--  Who hears what a window's buttons ask for, apart from what the window
--  does itself (move and size, zoom, mark, rename): to minimise, restore
--  or close it, to take a source's picture, or to start or stop dictating.
--
--     package Mine is new Items.Windows.Callbacks (Session);
--     Mine.On (Window, Which, Session'Access, Asked'Access);

generic
   type Context is limited private;
package Items.Windows.Callbacks is

   type Handler is access procedure (Self : in out Context; Which : Slot; Action : Actions);
   --  Which is the window's slot, as given to On.

   procedure On (Item : in out Window; Which : Slot; Self : not null access Context; Do_This : not null Handler);
   --  When Item's buttons ask for an Action, call Do_This with Self and
   --  Which. Self must be there as long as Item is in use.

end Items.Windows.Callbacks;
