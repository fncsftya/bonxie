package body Nav_VM_Fakes is

   overriding
   function Create (Self : in out Few) return Projects.Id is
   begin
      Self.Made := Self.Made + 1;
      return Projects.Id (Self.Made);
   end Create;

   overriding
   function Tab (Self : Few; Key : Projects.Id) return Natural
   is (Self.Tabs (Positive (Key)));

   overriding
   procedure Set_Tab (Self : in out Few; Key : Projects.Id; To : Natural) is
   begin
      Self.Tabs (Positive (Key)) := To;
      Self.Left := Self.Left + 1;
   end Set_Tab;

end Nav_VM_Fakes;
