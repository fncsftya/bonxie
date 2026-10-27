package body Menu_VM is
   procedure Initialize (Self : in out Model; Target : not null access Router'Class) is
   begin
      Self.Target := Target.all'Unrestricted_Access;
   end Initialize;
   overriding
   function Version (Self : Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes));
   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (Index > 0 and then Self.Target /= null and then Allowed (Self.Target.all, What, Index));
   overriding
   procedure Execute (Self : in out Model; What : Command; Index : Natural := 0) is
   begin
      Choose (Self.Target.all, What, Index);
      Parts.Bump (Self.Changes);
   end Execute;
end Menu_VM;
