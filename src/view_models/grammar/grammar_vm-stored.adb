package body Grammar_VM.Stored is

   procedure Open (Self : in out Rules_Kept; Store : not null access Projects.Store) is
   begin
      Self.Store := Store.all'Unrestricted_Access;
   end Open;

   overriding procedure Load (Self : in out Rules_Kept; Owner : Projects.Id; Result : out Rules.Rule_List) is
   begin
      Rules.Load (Self.Store.all, Owner, Result);
   end Load;

   overriding function Add
     (Self        : in out Rules_Kept;
      Owner       : Projects.Id;
      Action      : Rules.Actions;
      Kind        : Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Rules.Rule_Id is
     (Rules.Add (Self.Store.all, Owner, Action, Kind, Pattern, Replacement));

   overriding procedure Remove (Self : in out Rules_Kept; Key : Rules.Rule_Id) is
   begin
      Rules.Remove (Self.Store.all, Key);
   end Remove;

end Grammar_VM.Stored;
