--  The grammar rules as the database keeps them.

package Grammar_VM.Stored is

   type Rules_Kept is limited new Library with private;

   procedure Open (Self : in out Rules_Kept; Store : not null access Projects.Store);
   --  The rules in Store, which must be there as long as this is.

   overriding
   procedure Load (Self : in out Rules_Kept; Owner : Projects.Id; Result : out Rules.Rule_List);

   overriding
   function Add
     (Self        : in out Rules_Kept;
      Owner       : Projects.Id;
      Action      : Rules.Actions;
      Kind        : Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Rules.Rule_Id;

   overriding
   procedure Remove (Self : in out Rules_Kept; Key : Rules.Rule_Id);

private

   type Store_Access is access all Projects.Store;

   type Rules_Kept is limited new Library with record
      Store : Store_Access;
   end record;

end Grammar_VM.Stored;
