package body Nav_VM.Stored is

   Untitled : constant String := "Untitled project";

   procedure Open (Self : in out Projects_Kept; Store : not null access Projects.Store) is
   begin
      Self.Store := Store.all'Unrestricted_Access;
   end Open;

   overriding
   function Create (Self : in out Projects_Kept) return Projects.Id
   is (Projects.Create (Self.Store.all, Untitled));

   overriding
   function Tab (Self : Projects_Kept; Key : Projects.Id) return Natural
   is (Projects.Tab (Self.Store.all, Key));

   overriding
   procedure Set_Tab (Self : in out Projects_Kept; Key : Projects.Id; To : Natural) is
   begin
      Projects.Set_Tab (Self.Store.all, Key, To);
   end Set_Tab;

end Nav_VM.Stored;
