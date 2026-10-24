--  The items on the project's canvas: their windows, which are loaded
--  from the database when the project is entered, kept in step with the
--  canvas as it is panned and zoomed, and written back as they change.
with Items.Models;
with Canvas_VM;
with Pomarine.Themes;
with View_Parts.Common;

private package View.Canvas_Items is

   subtype Slot_List is View_Parts.Common.Slot_Array;

   procedure Enter (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Load the items of the current project, and put their windows on the
   --  canvas. Do it once the project screen is shown and laid out.

   procedure Leave (Item : in out Session);
   --  Write what has not been, and clear the windows.

   Untitled : constant String := Canvas_VM.Untitled;

   Untitled_Source : constant String := Canvas_VM.Untitled_Source;

   Untitled_Document : constant String := "Untitled document";

   procedure Add
     (Item : in out Session;
      Name : String := Untitled;
      Kind : Items.Kinds := Items.Note)
     with Pre => Screen (Item) = Project;
   --  Make an item called Name in the middle of the canvas.

   procedure Add_Linked_Source (Item : in out Session; To : Items.Slot)
     with Pre => Screen (Item) = Project
                 and then Items.Windows.Is_Assigned (Item.Windows (To));
   --  Make a source, as Add does, linked to the item of the window To,
   --  from its right to the source's left.

   procedure Add_Found_Source
     (Item      : in out Session;
      Linked_To : Natural;
      Page_Title, Address, File : String;
      Added     : out Boolean;
      Document  : Boolean := False)
     with Pre => Screen (Item) = Project
                 and then (Linked_To = 0 or else Items.Windows.Is_Assigned (Item.Windows (Linked_To)));
   --  Make a source for a page that was found: called Page_Title, a link to
   --  Address, and showing the picture in File, a PNG file, which is moved
   --  to where a source's picture is kept; or, if Document, the PDF in File, which
   --  is moved to where a source's document is kept and drawn, a page at a time,
   --  as one that was fetched is. If Linked_To is not 0 the item of
   --  that window is linked to it, as Add_Linked_Source does. Added is False
   --  if the tree of widgets has no room for another item's (File is left).

   procedure Choose_Origin
     (Item : in out Session; Which : Items.Slot; To : Items.Origins)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  Say whether the window's source is a link or a file (the window's
   --  two buttons do), and keep that.

   procedure File_Picked (Item : in out Session; Which : Items.Slot; Path : String)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  A file was chosen for the window's source, in the dialog: it is a
   --  file, its path is its text, and the file is shown.

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

   procedure Listen (Item : in out Session; Which : Items.Slot);
   --  Give the window the procedure it calls when its buttons ask for
   --  something: once it is built.

   procedure Pressed
     (Item : in out Session; X, Y : Float)
     with Pre => Screen (Item) = Project;
   --  The pointer was pressed at X, Y, in points of the window: the
   --  highlighter of a source's window is put away if that is outside it.

   procedure Sync (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Put the windows where the canvas has them, if it has been panned
   --  or zoomed.

   procedure Update (Item : in out Session; Now : Pomarine.Events.Milliseconds)
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
                            (Items.Models.Details (Item.Models (Which)).Kind,
                             Items.Source);
   --  The colour of the source, which its window, its row in the writing
   --  view and its links are shown in: by its place among the project's
   --  sources, the earliest made first (see Style.Source_Ink).

   function Capture_Time (Item : Session) return Projects.Seconds;
   --  The time a picture taken now is said to be taken at: now, in seconds
   --  since the epoch, or the time a test has pinned (see Pin_Capture_Time).

   function Count (Item : Session) return Natural;
   --  How many items there are.

   procedure Order (Item : Session; Slots : in out Slot_List);
   --  The windows of the items, the earliest made first, as Slots (1 .. Slots.Count).

   function Nth (Item : Session; Row : Positive) return Items.Slot
     with Pre => Row <= Count (Item);
   --  The window of the Rowth item, in that order.

end View.Canvas_Items;
