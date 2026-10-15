--  The items on the project's canvas: their windows, which are loaded
--  from the database when the project is entered, kept in step with the
--  canvas as it is panned and zoomed, and written back as they change.
with Pomarine.Themes;

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

   Untitled_Document : constant String := "Untitled document";

   procedure Add
     (Item : in out Session;
      Name : String := Untitled;
      Kind : Items.Kinds := Items.Note)
     with Pre => Screen (Item) = Project
                 and then Name'Length <= Projects.Title_Capacity;
   --  Make an item called Name in the middle of the canvas, if there is
   --  room for one.

   procedure Add_Linked_Source (Item : in out Session; To : Items.Slot)
     with Pre => Screen (Item) = Project
                 and then Items.Windows.Is_Assigned (Item.Windows (To));
   --  Make a source, as Add does, linked to the item of the window To,
   --  from its right to the source's left.

   function Capturing (Item : Session) return Boolean;
   --  Whether a source's picture is being taken, or a note's dictation is
   --  being heard, readied or made text: the loop is to look at it again soon.
   --  (Not whether its words are being found, which says when it is done: see
   --  Busy, and Vision.Jobs.)

   function Busy (Item : Session) return Boolean
     with Pre => Screen (Item) = Project;
   --  Whether anything is going on in the background for a window: as
   --  Capturing, and the words of a picture being found.

   procedure Toggle_Dictation (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The note's button was clicked, here or in the writing view: start
   --  listening, in the background, or stop, so that what was heard is
   --  made text and put in the note.

   procedure Listen (Item : in out Session);
   --  Give the windows the procedure they call when their buttons ask for
   --  something: once they are built.

   procedure Pressed
     (Item : in out Session; X, Y : Float)
     with Pre => Screen (Item) = Project;
   --  The pointer was pressed at X, Y, in points of the window: the
   --  highlighter of a source's window is put away if that is outside it.

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

   procedure Show_Dock (Item : in out Session);
   --  Show the dock if any item is minimised, and the canvas is shown.

   function Source_Ink
     (Item : Session; Which : Items.Slot) return Pomarine.Themes.Slot
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which))
                 and then Items."="
                            (Items.Windows.Details (Item.Windows (Which)).Kind,
                             Items.Source);
   --  The colour of the source, which its window, its row in the writing
   --  view and its links are shown in: by its place among the project's
   --  sources, the earliest made first (see Style.Source_Ink).

   function Count (Item : Session) return Natural;
   --  How many items there are.

   procedure Order
     (Item : Session; Slots : out Slot_List; Found : out Natural)
     with Pre => Slots'Length >= Items.Capacity;
   --  The windows of the items, the earliest made first, in
   --  Slots (Slots'First .. Slots'First + Found - 1).

   function Nth (Item : Session; Row : Positive) return Items.Slot
     with Pre => Row <= Count (Item);
   --  The window of the Rowth item, in that order.

end Viewer.Canvas_Items;
