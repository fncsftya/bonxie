package body Browser_VM is

   package VM renames Pomarine.View_Models;
   package Strings renames Ada.Strings.Unbounded;

   overriding
   function Parts_Version (Self : Model) return VM.Version_Number
   is (VM.Version (Self.Draft));

   procedure Initialize (Self : in out Model; Shown : not null access Page'Class) is
   begin
      Self.Shown := Shown.all'Unrestricted_Access;
   end Initialize;

   function Address_Draft (Self : Model) return String
   is (VM.Get (Self.Draft));

   procedure Set_Address_Draft (Self : in out Model; Text : String) is
   begin
      VM.Set (Self.Draft, Text);
   end Set_Address_Draft;

   function Has_Started (Self : Model) return Boolean
   is (Self.Started);

   function Address_Of (Text : String) return String is
      function Begins (Prefix : String) return Boolean
      is (Text'Length >= Prefix'Length and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);
   begin
      return (if Begins ("http://") or else Begins ("https://") then Text else "https://" & Text);
   end Address_Of;

   procedure Refresh (Self : in out Model) is
   begin
      if Self.Shown = null or else not Self.Started or else not Self.Shown.Is_Ready then
         return;
      end if;
      declare
         Where : constant String := Self.Shown.Address;
      begin
         if Where /= "" and then Where /= Strings.To_String (Self.Where) then
            Self.Where := Strings.To_Unbounded_String (Where);
            Set_Address_Draft (Self, Where);
         end if;
      end;
   end Refresh;

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (Index = 0
       and then Self.Shown /= null
       and then Self.Shown.Is_Ready
       and then (case What is
                   when Go     => Address_Draft (Self)'Length > 0,
                   when Reload => Self.Started));

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Go     =>
            Self.Started := True;
            Self.Shown.Load (Address_Of (Address_Draft (Self)));

         when Reload =>
            Self.Shown.Reload;
      end case;
   end Perform;

end Browser_VM;
