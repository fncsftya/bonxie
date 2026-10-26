--  What the window tells the model, and what it does for being used.
private package Items.Windows.Syncing is

   procedure Use_Window (Item : in out Window)
     with Pre => Is_Assigned (Item);

   procedure Tell_Model (Item : in out Window)
     with Pre => Is_Assigned (Item);

end Items.Windows.Syncing;
