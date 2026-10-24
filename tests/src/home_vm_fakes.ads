with Home_VM;
with Projects;

--  The projects as a test of the home screen's view-model has them: a few, kept in
--  a table, the latest first as the database lists them, and renamed ones latest of all.
package Home_VM_Fakes is

   type Few is limited new Home_VM.Library with private;

   procedure Add (Self : in out Few; Title : String; Documents : Natural := 0; Sources : Natural := 0);
   --  A project, the latest so far.

   function Titles (Self : Few) return String;
   --  The titles, latest first, apart by a comma.

   function Looked (Self : Few) return Natural;
   --  How often the projects were listed.

   overriding procedure Recent (Self : in out Few; Into : out Projects.Recent_List);

   overriding procedure Count_Items
     (Self : in out Few; Key : Projects.Id; Documents, Sources : out Natural);

   overriding procedure Rename (Self : in out Few; Key : Projects.Id; Title : String);

   overriding procedure Delete (Self : in out Few; Key : Projects.Id);

private

   type Known is record
      Key       : Projects.Id := 0;
      Title     : String (1 .. 40) := [others => ' '];
      Length    : Natural := 0;
      Documents : Natural := 0;
      Sources   : Natural := 0;
   end record;

   type Known_Array is array (1 .. 12) of Known;

   type Few is limited new Home_VM.Library with record
      Table    : Known_Array;
      Last     : Natural := 0;
      --  The latest is the last.
      Next     : Projects.Id := 1;
      Listed   : Natural := 0;
   end record;

end Home_VM_Fakes;
