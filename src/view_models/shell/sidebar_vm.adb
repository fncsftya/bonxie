package body Sidebar_VM is
   use type Nav_VM.Modes;

   procedure Initialize
     (Self : in out View_Model; Navigation : not null access Nav_VM.View_Model;
      Kept : access Store'Class := null) is
   begin
      Self.Navigation := Navigation.all'Unchecked_Access;
      Self.Kept := (if Kept = null then null else Kept.all'Unchecked_Access);
      declare
         Loaded : constant Open_Sections := (if Kept = null then [others => True] else Load (Kept.all));
      begin
         if Self.Opened /= Loaded then
            Self.Opened := Loaded;
            Parts.Bump (Self.Changes);
         end if;
      end;
   end Initialize;

   function Is_Open (Self : View_Model; Which : Section) return Boolean is (Self.Opened (Which));
   overriding function Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Changes));
   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
     (Self.Navigation /= null and then Index = 0
      and then Nav_VM.Takes_Gestures (Self.Navigation.all)
      and then Nav_VM.Mode (Self.Navigation.all) = Nav_VM.Write);

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      Which : constant Section :=
        (case What is when Toggle_Edit => Edit, when Toggle_Documents => Documents, when Toggle_Sources => Sources);
   begin
      pragma Assert (Can_Execute (Self, What, Index));
      Self.Opened (Which) := not Self.Opened (Which);
      Parts.Bump (Self.Changes);
      if Self.Kept /= null then
         begin
            Save (Self.Kept.all, Self.Opened);
         exception
            when others => null; --  Folding remains usable if preferences cannot be written.
         end;
      end if;
   end Execute;
end Sidebar_VM;
