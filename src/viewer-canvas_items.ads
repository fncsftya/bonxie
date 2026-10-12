--  The items on the project's canvas: their windows, which are loaded
--  from the database when the project is entered, kept in step with the
--  canvas as it is panned and zoomed, and written back as they change.
private package Viewer.Canvas_Items is

   type Slot_List is array (Positive range <>) of Items.Slot;

   procedure Enter (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Load the items of the current project, and put their windows on the
   --  canvas. Do it once the project screen is shown and laid out.

   procedure Leave (Item : in out Session);
   --  Write what has not been, and clear the windows.

   Untitled : constant String := "Untitled item";

   Untitled_Source : constant String := "Untitled source";

   procedure Add
     (Item : in out Session;
      Name : String := Untitled;
      Kind : Items.Kinds := Items.Note)
     with Pre => Screen (Item) = Project
                 and then Name'Length <= Projects.Title_Capacity;
   --  Make an item called Name in the middle of the canvas, if there is
   --  room for one.

   function Capturing (Item : Session) return Boolean;
   --  Whether a source's picture is being taken: the loop is to look at
   --  it again soon.

   procedure Take (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Do what the windows' buttons were clicked for, and keep what has
   --  been dragged and typed.

   procedure Sync (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Put the windows where the canvas has them, if it has been panned
   --  or zoomed.

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds)
     with Pre => Screen (Item) = Project;
   --  Sync, and write what has changed (see Items.Windows.Flush) as of
   --  Now.

   procedure Save_All (Item : in out Session);
   --  Write everything that has changed, whatever is being typed.

   procedure Set_State (Item : in out Session; Which : Items.Slot;
                        To : Items.States)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  Show the item as a window, as a bar in the dock, or not at all, and
   --  keep it so.

   procedure Reveal (Item : in out Session; Which : Items.Slot)
     with Pre => Screen (Item) = Project
                 and then Items.Windows.Is_Assigned (Item.Windows (Which));
   --  Show the item, opening it if it is not, in the middle of the canvas's
   --  view, over the others.

   procedure Remove (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  Remove the item for good.

   function Count (Item : Session) return Natural;
   --  How many items there are.

   procedure Order
     (Item : Session; Slots : out Slot_List; Found : out Natural)
     with Pre => Slots'Length >= Items.Capacity;
   --  The windows of the items, the earliest made first, in
   --  Slots (Slots'First .. Slots'First + Found - 1).

end Viewer.Canvas_Items;
