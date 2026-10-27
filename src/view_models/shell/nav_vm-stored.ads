--  The projects of the database, for the view-model of where the person is.

package Nav_VM.Stored is

   type Projects_Kept is limited new Library with private;

   procedure Open (Self : in out Projects_Kept; Store : not null access Projects.Store);
   --  The projects in Store, which must be there as long as this is.

   overriding
   function Create (Self : in out Projects_Kept) return Projects.Id;

   overriding
   function Tab (Self : Projects_Kept; Key : Projects.Id) return Natural;

   overriding
   procedure Set_Tab (Self : in out Projects_Kept; Key : Projects.Id; To : Natural);

private

   type Store_Access is access all Projects.Store;

   type Projects_Kept is limited new Library with record
      Store : Store_Access;
   end record;

end Nav_VM.Stored;
