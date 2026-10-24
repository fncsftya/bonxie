with Long_Texts;

package body Grammar_VM_Fakes is

   use type Projects.Rules.Rule_Id;

   overriding procedure Load (Self : in out Kept; Owner : Projects.Id; Result : out Projects.Rules.Rule_List) is
   begin
      Self.Owner := Owner;
      Self.Reads := Self.Reads + 1;
      Result := Self.Table;
   end Load;

   overriding function Add
     (Self        : in out Kept;
      Owner       : Projects.Id;
      Action      : Projects.Rules.Actions;
      Kind        : Projects.Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Projects.Rules.Rule_Id
   is
      pragma Unreferenced (Owner);
   begin
      Self.Table.Append
        ((Key => Self.Next, Action => Action, Kind => Kind, Pattern => Long_Texts.To_Text (Pattern),
          Replacement => Long_Texts.To_Text (Replacement)));
      Self.Next := Self.Next + 1;
      Self.Writes := Self.Writes + 1;
      return Self.Next - 1;
   end Add;

   overriding procedure Remove (Self : in out Kept; Key : Projects.Rules.Rule_Id) is
   begin
      for Each in 1 .. Self.Table.Count loop
         if Self.Table (Each).Key = Key then
            Self.Table.Delete (Each);
            exit;
         end if;
      end loop;
      Self.Writes := Self.Writes + 1;
   end Remove;

end Grammar_VM_Fakes;
