with Items.Models;
with Pomarine.View_Models;

--  Commands of an item's canvas window. Content and persistence stay in Items.Models; effects that
--  need the application (capture, dictation, file selection and outline menus) are injected.
package Item_Window_VM is

   package Parts renames Pomarine.View_Models;
   type Command is
     (Capture, Choose_Link, Choose_File, Previous_Page, Next_Page, Speak, Link_To_Outline,
      Use_Pointer, Use_Marker, Use_Eraser, Toggle_Zoom, Zoom_Preset,
      Begin_Title_Edit, Accept_Title, Minimize_Window, Restore_Window, Close_Window);
   package Commands is new Parts.Command_Models (Command);

   subtype Preset_Index is Positive range 1 .. 6;
   Preset_Zooms : constant array (Preset_Index) of Float := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

   type Effects is limited interface;
   procedure Requested (Self : in out Effects; What : Command; Index : Natural) is abstract;
   procedure Changed (Self : in out Effects) is abstract;

   type Model is limited new Commands.Model with private;
   procedure Initialize
     (Self : in out Model; Data : not null access Items.Models.Item; View : not null access Effects'Class);
   --  Data and View must outlive Self and its UI bindings.

   procedure Poll (Self : in out Model);
   --  Observe changes from outside the commands; unchanged state keeps its version.
   overriding function Version (Self : Model) return Parts.Version_Number;
   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0);

   function Zoom_Fraction (Self : Model) return Float;
   procedure Set_Zoom_Fraction (Self : in out Model; Value : Float)
     with Pre => Value in 0.0 .. 1.0;

   function Previous_Allowed (Self : Model) return Boolean is (Can_Execute (Self, Previous_Page));
   function Next_Allowed (Self : Model) return Boolean is (Can_Execute (Self, Next_Page));

   function Pointer_Selected (Self : Model) return Boolean;
   function Marker_Selected (Self : Model) return Boolean;
   function Eraser_Selected (Self : Model) return Boolean;

private

   type Item_Access is access all Items.Models.Item;
   type Effects_Access is access all Effects'Class;
   type Snapshot is record
      Assigned : Boolean := False;
      Key : Items.Id := 0;
      Kind : Items.Kinds := Items.Note;
      State : Items.States := Items.Closed;
      Origin : Items.Origins := Items.Unchosen;
      Page, Count : Natural := 0;
      Zoom : Float := 1.0;
      Tool : Items.Models.Tools := Items.Models.Pointer;
   end record;

   type Model is limited new Commands.Model with record
      Data : Item_Access;
      View : Effects_Access;
      Seen : Snapshot;
      Changes : Parts.Change_Counter;
   end record;

end Item_Window_VM;
