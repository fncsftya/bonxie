--  What the window's buttons and frame say: each is for the window it is of.
private package Items.Windows.Handlers is

   procedure Perform (Item : in out Window; What : Item_Window_VM.Command; Index : Natural);
   --  Effects that need the view or the application, after the model has checked the command.

   procedure Listen (Item : in out Window);
   --  Give the window's widgets the procedures they call (see Update).

end Items.Windows.Handlers;
