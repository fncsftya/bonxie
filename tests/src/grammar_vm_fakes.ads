with Grammar_VM;
with Projects;
with Projects.Rules;

--  The grammar rules as a test of the view-model has them: kept in memory, with a count of what was written.
package Grammar_VM_Fakes is

   type Engine is limited new Grammar_VM.Card_Engine with record
      State : Grammar_VM.Card_State;
      Calls : Natural := 0;
      Last : Grammar_VM.Card_Command := Grammar_VM.Toggle_Cards;
      Index : Natural := 0;
   end record;

   overriding function Inspect
     (Self : Engine; What : Grammar_VM.Card_Command; Index : Natural) return Grammar_VM.Card_State;
   overriding procedure Perform (Self : in out Engine; What : Grammar_VM.Card_Command; Index : Natural);

   type Reactions (Model : not null access Grammar_VM.View_Model) is
     limited new Grammar_VM.Effects with record
      Accepted, Cancelled : Natural := 0;
      Closed : Boolean := False;
      Rules : Natural := 0;
   end record;

   overriding procedure Entry_Ended (Self : in out Reactions; Accepted : Boolean);

   type Kept is limited new Grammar_VM.Library with record
      Table   : aliased Projects.Rules.Rule_List;
      Owner   : Projects.Id := 0;
      --  Whose rules were last read.
      Next    : Projects.Rules.Rule_Id := 1;
      Reads   : Natural := 0;
      Writes  : Natural := 0;
   end record;

   overriding procedure Load (Self : in out Kept; Owner : Projects.Id; Result : out Projects.Rules.Rule_List);

   overriding function Add
     (Self        : in out Kept;
      Owner       : Projects.Id;
      Action      : Projects.Rules.Actions;
      Kind        : Projects.Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Projects.Rules.Rule_Id;

   overriding procedure Remove (Self : in out Kept; Key : Projects.Rules.Rule_Id);

end Grammar_VM_Fakes;
