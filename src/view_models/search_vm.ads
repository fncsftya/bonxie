with Items;
with Pomarine.View_Models;

--  Search lifecycle and commands. The finder owns matching, navigation and transient engine decorations.
package Search_VM is
   package Parts renames Pomarine.View_Models;
   type Scopes is (Canvas_Item, Writing);
   type Context is record
      Scope : Scopes := Canvas_Item;
      Target : Items.Slot := 1;
      Key : Items.Id := 0;
   end record;
   type Result is record
      Current, Total : Natural := 0;
      Busy : Boolean := False;
   end record
     with Dynamic_Predicate => Result.Current <= Result.Total;

   type Finder is limited interface;
   function Valid (Self : Finder; Where : Context) return Boolean is abstract;
   procedure Refresh (Self : in out Finder; Where : Context; Term : String; Found : out Result) is abstract
     with Pre'Class => Valid (Self, Where);
   procedure Advance (Self : in out Finder; Where : Context; Backwards : Boolean) is abstract
     with Pre'Class => Valid (Self, Where);
   procedure Clear (Self : in out Finder; Where : Context) is abstract;
   --  Clear must tolerate an item that has disappeared; it must not clear a replacement with another key.

   type Command is (Close, Previous, Next);
   package Commands is new Parts.Command_Models (Command);
   type View_Model is limited new Commands.Model with private;
   procedure Initialize (Self : in out View_Model; Engine : not null access Finder'Class);
   --  Engine must outlive Self.
   procedure Open (Self : in out View_Model; Where : Context)
     with Post => Location (Self) = Where;
   --  Replace the previous search, retaining the term. An invalid context stays closed.
   procedure Set_Term (Self : in out View_Model; Text : String)
     with Post => Term (Self) = Text;
   function Term (Self : View_Model) return String;
   function Is_Showing (Self : View_Model) return Boolean;
   function Location (Self : View_Model) return Context;
   function Found (Self : View_Model) return Result;
   function Summary (Self : View_Model) return String;
   procedure Poll (Self : in out View_Model);
   --  Refresh the engines and result, or close if the context is no longer valid.
   overriding function Version (Self : View_Model) return Parts.Version_Number;
   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => (if What = Close then not Is_Showing (Self) and then Found (Self) = Result'(others => <>));
private
   type Finder_Access is access all Finder'Class;
   type View_Model is limited new Commands.Model with record
      Engine : Finder_Access;
      Showing : Boolean := False;
      Where : Context;
      Matches : Result;
      Typed : Parts.Text_Property;
      Changes : Parts.Change_Counter;
   end record;
end Search_VM;
