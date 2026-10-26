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

   overriding function Inspect
     (Self : Engine; What : Grammar_VM.Card_Command; Index : Natural) return Grammar_VM.Card_State
   is
      pragma Unreferenced (What, Index);
   begin
      return Self.State;
   end Inspect;

   overriding procedure Perform (Self : in out Engine; What : Grammar_VM.Card_Command; Index : Natural) is
   begin
      Self.Calls := Self.Calls + 1;
      Self.Last := What;
      Self.Index := Index;
   end Perform;

   overriding procedure Entry_Ended (Self : in out Reactions; Accepted : Boolean) is
   begin
      if Accepted then
         Self.Accepted := Self.Accepted + 1;
      else
         Self.Cancelled := Self.Cancelled + 1;
      end if;
      Self.Closed := not Grammar_VM.Is_Entering (Self.Model.all);
      Self.Rules := Grammar_VM.Count (Self.Model.all);
   end Entry_Ended;

end Grammar_VM_Fakes;
