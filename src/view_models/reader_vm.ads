with Items.Models;
with Pomarine.View_Models;

--  Reader controls operate on an injected reading engine. Geometry, page widgets, and the pin/visit
--  effects belong to the view; command rules and selected-tool bindings are tested without them.
package Reader_VM is
   package Parts renames Pomarine.View_Models;
   type Command is (Use_Pointer, Use_Marker, Use_Eraser, Toggle_Pin, Visit, Close_Reader);
   package Commands is new Parts.Command_Models (Command);

   type Engine is limited interface;
   function Is_Open (Self : Engine) return Boolean is abstract;
   function Tool (Self : Engine) return Items.Models.Tools is abstract;
   procedure Select_Tool (Self : in out Engine; To : Items.Models.Tools) is abstract;
   function Zoom (Self : Engine) return Float is abstract;
   procedure Set_Zoom (Self : in out Engine; Value : Float) is abstract;
   procedure Requested (Self : in out Engine; What : Command) is abstract;

   type Model is limited new Commands.Model with private;
   procedure Initialize (Self : in out Model; Reading : not null access Engine'Class);
   --  Reading must outlive the model and its bindings.
   procedure Poll (Self : in out Model);
   overriding function Version (Self : Model) return Parts.Version_Number;
   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0);
   function Zoom_Fraction (Self : Model) return Float;
   procedure Set_Zoom_Fraction (Self : in out Model; Value : Float)
     with Pre => Value in 0.0 .. 1.0;
   function Pointer_Selected (Self : Model) return Boolean;
   function Marker_Selected (Self : Model) return Boolean;
   function Eraser_Selected (Self : Model) return Boolean;
private
   type Engine_Access is access all Engine'Class;
   type Model is limited new Commands.Model with record
      Reading : Engine_Access;
      Seen_Zoom : Float := 1.0;
      Seen_Open : Boolean := False;
      Seen_Tool : Items.Models.Tools := Items.Models.Pointer;
      Changes : Parts.Change_Counter;
   end record;
end Reader_VM;
