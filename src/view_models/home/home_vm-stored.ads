--  The projects of the database, for the home screen's view-model.

package Home_VM.Stored is

   type Projects_Kept is limited new Library with private;

   procedure Open (Self : in out Projects_Kept; Store : not null access Projects.Store);
   --  The projects in Store, which must be there as long as this is.

   overriding
   procedure Recent (Self : in out Projects_Kept; Into : out Projects.Recent_List);

   overriding
   procedure Count_Items (Self : in out Projects_Kept; Key : Projects.Id; Documents, Sources : out Natural);

   overriding
   procedure Rename (Self : in out Projects_Kept; Key : Projects.Id; Words : String);

   overriding
   procedure Delete (Self : in out Projects_Kept; Key : Projects.Id);

private

   type Store_Access is access all Projects.Store;

   type Projects_Kept is limited new Library with record
      Store : Store_Access;
   end record;

end Home_VM.Stored;
