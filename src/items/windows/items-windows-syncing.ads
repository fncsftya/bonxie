--  Keeping a window in step with the application, once a frame.
private package Items.Windows.Syncing is

   procedure Sync (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Raise it when it is used, keep the title and word count as edited,
   --  and scroll a note's text to where it was. What the buttons, the
   --  bars and the title say is done as it is said, and what is for the
   --  application is told to it (see Items.Windows.Callbacks).

   procedure Keep
     (Item  : in out Window;
      Store : in out Projects.Store;
      Now   : SDL3.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
     with Pre => Is_Assigned (Item) and then Projects.Is_Open (Store);
   --  Write to the database what has changed: where it has been put, once
   --  it is let go; the title and text, once they are no longer being
   --  typed in, or have not changed for Idle_Delay, or whenever Force.
   --  Wrote says whether anything was written. Now is as
   --  SDL3.Events.Ticks.

end Items.Windows.Syncing;
