with Growing;
with Items.Links;
with Items.Marks;
with Items.Models.Tables;
with Pomarine.Events;
with Pomarine.View_Models;

--  The view-model of a project's canvas: the items on it (each an Items.Models.Item), where it is looked at from,
--  what is being done to the items (moved, sized, shown, taken away, linked), and what is written for it and when.
--  It names no widget, so the tests run it without a window.
--
--  The canvas widget is the person's hand on the camera (it pans and zooms as they drag and pinch); it tells this what
--  it came to (Set_Camera), and it is asked to go where this wants it (Steering). The windows of the items show their
--  models, in the camera's place (see View.Canvas_Items).
package Canvas_VM is

   package Parts renames Pomarine.View_Models;

   Untitled : constant String := "Untitled item";

   Untitled_Source : constant String := "Untitled source";

   Cascade_Step  : constant Float := 24.0;

   Cascade_Count : constant := 6;
   --  Each new item is put this far down and right of the last, for so many, so that they are not all on top of each
   --  other.

   type Command is
     (Add_Note,
      Add_Source,
      --  An item in the middle of what is shown, as Add does.
      Open_Item,
      Minimize_Item,
      Close_Item,
      --  Index: the slot of the item. Shown as a window, as a bar in the dock, or not at all; and kept.
      Show_Item,
      --  Index: the slot. Open, in the middle of what is shown, over the others.
      Remove_Item,
      --  Index: the slot. For good. The window has been let go of: see View.Canvas_Items.
      Delete_Link,
      --  The link selected.
      Cancel_Link);
      --  Put away the line being dragged from a pin.

   package Commands is new Parts.Command_Models (Command);

   --  What is kept, and the world's part of it (the database, the project the canvas is of).

   type Library is limited interface;

   procedure Load (Self : in out Library; Into : out Items.Info_List) is abstract;
   --  The items of the project, the earliest made first.

   function Create (Self : in out Library; Name : String; Where : Items.Frame; Kind : Items.Kinds) return Items.Id
     is abstract;

   function Stored_Content (Self : in out Library; Key : Items.Id) return String is abstract;

   function Shown_File (Self : in out Library; Of_Item : Items.Info) return String is abstract;
   --  What its window shows: the text file of a source that is a text, else its picture; "" if it has none.

   procedure Load_Marks (Self : in out Library; Key : Items.Id; Into : out Items.Marks.Mark_List) is abstract;

   procedure Keep_State (Self : in out Library; Key : Items.Id; To : Items.States) is abstract;

   procedure Keep_Origin (Self : in out Library; Key : Items.Id; To : Items.Origins) is abstract;

   procedure Delete (Self : in out Library; Key : Items.Id) is abstract;

   procedure Flush
     (Self  : in out Library;
      Model : in out Items.Models.Item;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean) is abstract;

   procedure Touch (Self : in out Library) is abstract;
   --  The project has been changed.

   procedure Get_View (Self : in out Library; Found : out Boolean; Zoom, Centre_X, Centre_Y : out Float) is abstract;

   procedure Set_View (Self : in out Library; Zoom, Centre_X, Centre_Y : Float) is abstract;

   procedure Load_Links (Self : in out Library; Into : out Items.Links.Link_List) is abstract;

   procedure Add_Link (Self : in out Library; Fresh : Items.Links.Link; Added : out Boolean) is abstract;

   procedure Move_Link
     (Self : in out Library; Key : Items.Id; To : Items.Id; Side : Items.Links.Sides; Moved : out Boolean)
     is abstract;

   procedure Delete_Link (Self : in out Library; Key : Items.Id) is abstract;

   procedure Set_Link_Style
     (Self   : in out Library;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors) is abstract;

   --  What shows the items.

   type Surface is limited interface;

   procedure Make_Room (Self : in out Surface; Slots : Positive) is abstract;
   --  Have windows, and what goes with them, for at least so many items.

   package Slot_Lists is new Growing (Items.Slot);

   type View_Model is limited new Commands.Model with private;

   procedure Initialize
     (Self   : in out View_Model;
      Kept   : not null access Library'Class;
      Room   : not null access Surface'Class;
      Slots  : not null access Items.Models.Tables.Table);
   --  All must be there as long as the view-model is. Slots has the items, as many slots as there are windows.

   procedure Enter (Self : in out View_Model)
     with Post => Is_Entered (Self);
   --  Take the items and the links of the project from the library, and give each its model. The windows are for the
   --  view to show.

   procedure Leave (Self : in out View_Model)
     with Post => not Is_Entered (Self) and then Count (Self) = 0;
   --  Let go of the items: the view has written what was not (Flush_All) and put the windows away.

   function Is_Entered (Self : View_Model) return Boolean;

   --  The items

   function Count (Self : View_Model) return Natural;
   --  How many there are, whether shown or not.

   function Is_Item (Self : View_Model; Slot : Items.Slot) return Boolean;

   procedure Order (Self : View_Model; Into : in out Slot_Lists.List);
   --  The slots of the items, the earliest made first.

   function Made (Self : View_Model) return Natural;
   --  The slot of the item made last; 0 if none has been.

   procedure Add (Self : in out View_Model; Name : String; Kind : Items.Kinds; Slot : out Items.Slot)
     with Pre => Is_Entered (Self), Post => Is_Item (Self, Slot) and then Made (Self) = Slot;
   --  Make an item called Name, in the middle of what is shown (and a step down and right of the last made).

   function Source_Rank (Self : View_Model; Slot : Items.Slot) return Natural
     with Pre => Is_Item (Self, Slot);
   --  Of a source, which it is of the sources, by when they were made; 0 for a note.

   function Items_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever an item is made or taken away, or shown another way.

   function Raised (Self : View_Model) return Natural;
   --  The slot that was to be brought over the others last, by Show_Item.

   function Raised_Version (Self : View_Model) return Parts.Version_Number;

   --  Where it is looked at from

   function Camera (Self : View_Model) return Items.Models.Camera;

   function Shown_Camera (Self : in out View_Model) return access constant Items.Models.Camera;
   --  What the windows put themselves by: it changes as the camera does.

   procedure Set_Camera (Self : in out View_Model; To : Items.Models.Camera)
     with Pre => To.Zoom > 0.0;
   --  The person panned or zoomed the canvas.

   procedure Set_Viewport (Self : in out View_Model; Width, Height : Float)
     with Pre => Width >= 0.0 and then Height >= 0.0;
   --  How much of the canvas there is to see, in points.

   function Viewport_Width (Self : View_Model) return Float;

   function Viewport_Height (Self : View_Model) return Float;

   function Camera_Version (Self : View_Model) return Parts.Version_Number;

   function Middle (Self : View_Model; Across : Boolean) return Float;
   --  The middle of what is shown, in canvas units: across, or down.

   --  Where it is asked to go

   type Steer is record
      Zoom     : Float := 0.0;
      --  What to zoom to, if not 0.0.
      Centre_X : Float := 0.0;
      Centre_Y : Float := 0.0;
   end record;
   --  What the canvas is asked to do: zoom to Zoom if it is not 0.0, and then have its Centre in the middle.

   function Steering (Self : View_Model) return Steer;

   function Steering_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever the canvas is asked to go somewhere.

   procedure Centre_On (Self : in out View_Model; X, Y : Float);

   procedure Centre_On_Items (Self : in out View_Model);
   --  On the middle of those shown as windows, if there are any.

   procedure Restore_View (Self : in out View_Model; Found : out Boolean);
   --  As it was kept for the project, if it was.

   procedure Save_View (Self : in out View_Model);
   --  Keep it, if there is room to see it in.

   --  What is done to the items by hand

   procedure Move_Item (Self : in out View_Model; Slot : Items.Slot; Across, Down : Float)
     with Pre => Is_Item (Self, Slot);
   --  Its window was dragged by so many points of the screen.

   procedure Resize_Item (Self : in out View_Model; Slot : Items.Slot; Across, Down : Float; Still : Boolean)
     with Pre => Is_Item (Self, Slot);
   --  Its corner was dragged by so many points of the screen; Still, it is held.

   procedure Choose_Origin (Self : in out View_Model; Slot : Items.Slot; To : Items.Origins)
     with Pre => Is_Item (Self, Slot) and then Details_Is_Source (Self, Slot);
   --  The source is from a link, or from a file; and that is kept.

   function Details_Is_Source (Self : View_Model; Slot : Items.Slot) return Boolean;

   procedure Put_Tool_Away (Self : in out View_Model; Slot : Items.Slot)
     with Pre => Is_Item (Self, Slot);
   --  The pointer was pressed outside the window of the item, which had a tool in hand (a highlighter, an eraser): it
   --  has the pointer again.

   procedure Flush_All (Self : in out View_Model; Now : Pomarine.Events.Milliseconds; Force : Boolean)
     with Pre => Is_Entered (Self);
   --  Write what has changed of the items, as Items.Models.Flush does, the windows having said what they know
   --  (Items.Windows.Report).

   --  The links

   function Link_Count (Self : View_Model) return Natural;

   function Link_At (Self : View_Model; Number : Positive) return Items.Links.Link
     with Pre => Number <= Link_Count (Self);

   function Link_Number (Self : View_Model; Key : Items.Id) return Natural;
   --  Its place among them; 0 if there is none such.

   function Slot_Of (Self : View_Model; Key : Items.Id) return Natural;
   --  The slot of the item; 0 if there is none such.

   function Selected_Link (Self : View_Model) return Items.Id;
   --  The key of the one selected; 0 if none.

   procedure Select_Link (Self : in out View_Model; Number : Natural)
     with Pre => Number <= Link_Count (Self);
   --  The one in that place is selected; none, if 0.

   procedure Join
     (Self : in out View_Model; From, To : Items.Slot; From_Side, To_Side : Items.Links.Sides)
     with Pre => Is_Item (Self, From) and then Is_Item (Self, To);
   --  Draw a line from the side of one item to the side of the other, if they are not joined already.

   procedure Begin_Link (Self : in out View_Model; From : Items.Slot; Side : Items.Links.Sides)
     with Pre => Is_Item (Self, From);
   --  A line is dragged from a pin.

   procedure Begin_Moving_Link (Self : in out View_Model);
   --  The target end of the selected link is dragged, from the item it starts at.

   procedure End_Link (Self : in out View_Model; To : Natural; Side : Items.Links.Sides);
   --  What was dragged is let go on the pin at the Side of the window in the slot To (0 if none): a link is made, or
   --  the one selected is moved; and it is put away.

   function Link_From (Self : View_Model) return Natural;
   --  The slot of the item a line is being dragged from; 0 if none is.

   function Link_From_Side (Self : View_Model) return Items.Links.Sides;

   function Is_Moving_Link (Self : View_Model) return Boolean;
   --  Whether it is the selected link that is dragged.

   procedure Restyle
     (Self   : in out View_Model;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors);
   --  Draw the selected link so.

   procedure Reload_Links (Self : in out View_Model);
   --  The links were changed in the library (an item went with its links).

   function Links_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever the links are, or which is selected, or what is dragged.

   overriding function Version (Self : View_Model) return Parts.Version_Number;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Add_Note and Add_Source: the canvas is entered. Of an item (Index; 0 asks whether there is any): Open_Item, if it
   --  is not open; Minimize_Item, if it is; Close_Item, if it is not closed; Show_Item and Remove_Item, if it is there.
   --  Delete_Link: one is selected. Cancel_Link: a line is being dragged.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0);

private

   type Library_Access is access all Library'Class;
   type Surface_Access is access all Surface'Class;
   type Table_Access is access all Items.Models.Tables.Table;

   type View_Model is limited new Commands.Model with record
      Kept      : Library_Access;
      Room      : Surface_Access;
      Models    : Table_Access;
      Entered   : Boolean := False;
      Last_Made : Natural := 0;
      Looking   : aliased Items.Models.Camera;
      Looks     : Parts.Change_Counter;
      --  Of where it is looked at from.
      Width, Height : Float := 0.0;
      Asked     : Steer;
      Asks      : Parts.Change_Counter;
      Front     : Natural := 0;
      Fronts    : Parts.Change_Counter;
      Shown     : Parts.Change_Counter;
      --  Of the items made, taken away and shown another way.
      Link_Set  : Items.Links.Link_List;
      Chosen    : Items.Id := 0;
      From      : Natural := 0;
      From_Side : Items.Links.Sides := Items.Links.Top;
      Moving    : Boolean := False;
      Joined    : Parts.Change_Counter;
   end record;

end Canvas_VM;
