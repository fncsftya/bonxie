with Growing;
with Items.Models.Tables;
with Nav_VM;
with Pomarine.View_Models;

--  Source order is independent of pooled sidebar rows. Retain keys to reject reused item slots.

package Writing_Sources_VM is
   package Parts renames Pomarine.View_Models;
   type Command is (Toggle_Source);
   package Commands is new Parts.Command_Models (Command);
   type Effects is limited interface;
   procedure Toggle_Source (Self : in out Effects; Slot : Items.Slot) is abstract;
   type View_Model is limited new Commands.Model with private;
   procedure Initialize
     (Self       : in out View_Model;
      Navigation : not null access Nav_VM.View_Model;
      Models     : not null access Items.Models.Tables.Table;
      Surface    : not null access Effects'Class);
   function Count (Self : View_Model) return Natural;
   function Slot_At (Self : View_Model; Row : Positive) return Items.Slot
   with Pre => Row <= Count (Self);
   function Row_Of (Self : View_Model; Slot : Items.Slot) return Natural;
   function Can_Add (Self : View_Model; Slot : Items.Slot) return Boolean;
   procedure Add (Self : in out View_Model; Slot : Items.Slot)
   with Pre => Can_Add (Self, Slot), Post => Count (Self) = Count (Self)'Old + 1;
   procedure Remove (Self : in out View_Model; Slot : Items.Slot)
   with Post => Row_Of (Self, Slot) = 0;
   procedure Reset (Self : in out View_Model)
   with Post => Count (Self) = 0;
   procedure Offer_Links (Self : View_Model; Offer : not null access procedure (Title, Address : String));
   --  Offer each source of the rows that is a web page, in row order, with its title and address: the
   --  addresses a page's text may link to.
   overriding
   function Version (Self : View_Model) return Parts.Version_Number;
   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0);
private
   type Entry_Info is record
      Slot : Items.Slot;
      Key  : Items.Id;
   end record;
   package Entries is new Growing (Entry_Info);
   type Nav_Access is access all Nav_VM.View_Model;
   type Models_Access is access all Items.Models.Tables.Table;
   type Effects_Access is access all Effects'Class;
   type View_Model is limited new Commands.Model with record
      Navigation : Nav_Access;
      Models     : Models_Access;
      Surface    : Effects_Access;
      Rows       : Entries.List;
      Changes    : Parts.Change_Counter;
   end record;
end Writing_Sources_VM;
