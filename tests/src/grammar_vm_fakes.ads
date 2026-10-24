with Grammar_VM;
with Projects;
with Projects.Rules;

--  The grammar rules as a test of the view-model has them: kept in memory, with a count of what was written.
package Grammar_VM_Fakes is

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
