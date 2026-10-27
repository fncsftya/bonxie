with Nav_VM;
with Pomarine.View_Models;

--  The writing sidebar's folding choices, independent of layout and gestures.
package Sidebar_VM is
   package Parts renames Pomarine.View_Models;
   type Section is (Edit, Documents, Sources);
   type Open_Sections is array (Section) of Boolean;
   type Command is (Toggle_Edit, Toggle_Documents, Toggle_Sources);
   package Commands is new Parts.Command_Models (Command);

   type Store is limited interface;
   function Load (Self : Store) return Open_Sections is abstract;
   procedure Save (Self : in out Store; Value : Open_Sections) is abstract;

   type View_Model is limited new Commands.Model with private;
   procedure Initialize
     (Self : in out View_Model; Navigation : not null access Nav_VM.View_Model;
      Kept : access Store'Class := null);
   --  Dependencies outlive Self. Without a store all sections start open; failures keep the live choice.
   function Is_Open (Self : View_Model; Which : Section) return Boolean;
   overriding function Version (Self : View_Model) return Parts.Version_Number;
   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Commands require Write, a project with no modal layer, and Index 0.
   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => (case What is
       when Toggle_Edit => Is_Open (Self, Edit) /= Is_Open (Self, Edit)'Old,
       when Toggle_Documents => Is_Open (Self, Documents) /= Is_Open (Self, Documents)'Old,
       when Toggle_Sources => Is_Open (Self, Sources) /= Is_Open (Self, Sources)'Old);
private
   type Nav_Access is access all Nav_VM.View_Model;
   type Store_Access is access all Store'Class;
   type View_Model is limited new Commands.Model with record
      Navigation : Nav_Access;
      Kept : Store_Access;
      Opened : Open_Sections := [others => True];
      Changes : Parts.Change_Counter;
   end record;
end Sidebar_VM;
