with Slot_Tables;
with Nav_VM;
with Canvas_VM;
with Growing;
with Projects;
with Items.Models.Tables;
with Pomarine.View_Models;

--  The rows and actions of the item list. The surface applies an action to the canvas, including window teardown.

package Item_List_VM is
   package Parts renames Pomarine.View_Models;
   type Command is (Reveal, Toggle_Shown, Remove);
   package Commands is new Parts.Command_Models (Command);

   type Surface is limited interface;
   procedure Apply (Self : in out Surface; What : Canvas_VM.Command; Slot : Items.Slot) is abstract;

   type View_Model is limited new Commands.Model with private;
   procedure Initialize
     (Self       : in out View_Model;
      Canvas     : not null access Canvas_VM.View_Model;
      Models     : not null access Items.Models.Tables.Table;
      View       : not null access Surface'Class;
      Navigation : access Nav_VM.View_Model := null);
   --  The dependencies must outlive Self. With Navigation, commands require the item-list layer;
   --  revealing an item closes it before applying the surface action.

   procedure Refresh (Self : in out View_Model);
   --  Read the current order and row contents. An unchanged list keeps its version.
   function Count (Self : View_Model) return Natural;
   function Slot_Of (Self : View_Model; Row : Positive) return Items.Slot
   with Pre => Row <= Count (Self);
   function Row_Id (Self : View_Model; Row : Positive) return Positive
   with Pre => Row <= Count (Self);
   --  Stable while this item remains; a replacement in its slot receives another identity.
   function Title (Self : View_Model; Row : Positive) return String
   with Pre => Row <= Count (Self);
   function Is_Closed (Self : View_Model; Row : Positive) return Boolean
   with Pre => Row <= Count (Self);
   overriding
   function Version (Self : View_Model) return Parts.Version_Number;
   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Index is a row; 0 asks whether any row can act. Stale rows cannot act after their item is removed or replaced.
   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0);

private
   type Nav_Access is access all Nav_VM.View_Model;
   type Canvas_Access is access all Canvas_VM.View_Model;
   type Models_Access is access all Items.Models.Tables.Table;
   type Surface_Access is access all Surface'Class;
   type Row_Info is record
      Slot     : Items.Slot;
      Identity : Positive;
      Key      : Items.Id;
      Title    : Projects.Titles.Text;
      Closed   : Boolean;
   end record;
   package Rows is new Growing (Row_Info);
   type Slot_Identity is record
      Key      : Items.Id := 0;
      Identity : Natural := 0;
   end record;
   package Identities is new Slot_Tables (Slot_Identity);
   type View_Model is limited new Commands.Model with record
      Navigation    : Nav_Access;
      Identity_Of   : Identities.Table;
      Last_Identity : Natural := 0;
      Canvas        : Canvas_Access;
      Models        : Models_Access;
      View          : Surface_Access;
      Listed        : Rows.List;
      Changes       : Parts.Change_Counter;
   end record;
end Item_List_VM;
