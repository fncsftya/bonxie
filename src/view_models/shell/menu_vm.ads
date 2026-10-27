with Pomarine.View_Models;

--  Discrete choices from the current menu snapshot. The view supplies the current row availability
--  and translates the choice into its existing application operation; no widget state is retained here.

package Menu_VM is
   package Parts renames Pomarine.View_Models;
   type Command is (Source_Menu, Context_Menu, Section_Menu, Grammar_Menu);
   package Commands is new Parts.Command_Models (Command);
   type Router is limited interface;
   function Allowed (Self : Router; What : Command; Row : Natural) return Boolean is abstract;
   procedure Choose (Self : in out Router; What : Command; Row : Positive) is abstract;
   type Model is limited new Commands.Model with private;
   procedure Initialize (Self : in out Model; Target : not null access Router'Class);
   --  Target must outlive the model and its bindings.
   overriding
   function Version (Self : Model) return Parts.Version_Number;
   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding
   procedure Execute (Self : in out Model; What : Command; Index : Natural := 0);
private
   type Router_Ref is access all Router'Class;
   type Model is limited new Commands.Model with record
      Target  : Router_Ref;
      Changes : Parts.Change_Counter;
   end record;
end Menu_VM;
