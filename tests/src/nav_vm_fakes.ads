with Nav_VM;
with Projects;

--  The projects as a test of where-the-person-is has them: made as asked, with the view each was left at.
package Nav_VM_Fakes is

   type Nat_Array is array (1 .. 20) of Natural;

   type Few is limited new Nav_VM.Library with record
      Made : Natural := 0;
      --  How many were made.
      Left : Natural := 0;
      --  How many times a view was kept.
      Tabs : Nat_Array := [others => 0];
   end record;

   overriding function Create (Self : in out Few) return Projects.Id;

   overriding function Tab (Self : Few; Key : Projects.Id) return Natural;

   overriding procedure Set_Tab (Self : in out Few; Key : Projects.Id; To : Natural);

end Nav_VM_Fakes;
