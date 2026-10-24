package body Grammar_VM is

   use type Rules.Actions;
   use type Parts.Version_Number;

   function Owner_Of (Self : View_Model) return Projects.Id is (Self.Owner);

   function Current (Self : aliased View_Model) return access constant Rules.Rule_List is (Self.Known'Access);

   function Count (Self : View_Model) return Natural is (Self.Known.Count);

   function Rules_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Lists));

   function Is_Entering (Self : View_Model) return Boolean is (Self.Entering);

   function Entry_Text (Self : View_Model) return String is (Projects.Titles.To_String (Self.Text));

   function Prompt (Self : View_Model) return String is ("Always correct """ & Entry_Text (Self) & """ to:");

   function Correction (Self : View_Model) return String is (Parts.Get (Self.Typed));

   procedure Set_Correction (Self : in out View_Model; Text : String) is
   begin
      Parts.Set (Self.Typed, Text);
   end Set_Correction;

   overriding function Version (Self : View_Model) return Parts.Version_Number is
     (Parts.Value (Self.Changes) + Parts.Value (Self.Lists) + Parts.Version (Self.Typed));

   procedure Initialize (Self : in out View_Model; Kept : not null access Library'Class) is
   begin
      Self.Kept := Kept.all'Unrestricted_Access;
   end Initialize;

   procedure Read (Self : in out View_Model) is
   begin
      Load (Self.Kept.all, Self.Owner, Self.Known);
      Parts.Bump (Self.Lists);
   end Read;

   procedure Open (Self : in out View_Model; Owner : Projects.Id) is
   begin
      if Self.Owner /= Owner then
         Self.Entering := False;
         Self.Owner := Owner;
         Read (Self);
         Parts.Bump (Self.Changes);
      end if;
   end Open;

   procedure Forget (Self : in out View_Model) is
   begin
      Self.Owner := 0;
      Self.Entering := False;
      Parts.Bump (Self.Changes);
   end Forget;

   procedure Ignore (Self : in out View_Model; Kind : Rules.Kind_Code; Pattern : String) is
      Key : constant Rules.Rule_Id := Add (Self.Kept.all, Self.Owner, Rules.Ignore, Kind, Pattern, "");
      pragma Unreferenced (Key);
   begin
      Read (Self);
   end Ignore;

   function Corrects (Self : View_Model; Pattern : String) return Boolean is
   begin
      for Each of Self.Known loop
         if Each.Action = Rules.Correct and then Projects.Titles.To_String (Each.Pattern) = Pattern then
            return True;
         end if;
      end loop;
      return False;
   end Corrects;

   procedure Remove_Correction (Self : in out View_Model; Pattern : String; Removed : out Boolean) is
   begin
      Removed := False;
      for Each of Self.Known loop
         if Each.Action = Rules.Correct and then Projects.Titles.To_String (Each.Pattern) = Pattern then
            Remove (Self.Kept.all, Each.Key);
            Removed := True;
            exit;
         end if;
      end loop;
      if Removed then
         Read (Self);
      end if;
   end Remove_Correction;

   procedure Begin_Entry (Self : in out View_Model; Pattern : String; Kind : Rules.Kind_Code; Starting : String) is
   begin
      Self.Text := Projects.Titles.To_Text (Pattern);
      Self.Kind := Kind;
      Self.Entering := True;
      Parts.Set (Self.Typed, Starting);
      Parts.Bump (Self.Changes);
   end Begin_Entry;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      pragma Unreferenced (Index);
   begin
      return
        (case What is
            when Cancel_Entry => Self.Entering,
            when Accept_Entry =>
               Self.Entering and then Correction (Self) /= Entry_Text (Self)
               and then Correction (Self)'Length <= Longest_Correction);
   end Can_Execute;

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      if What = Accept_Entry then
         declare
            Key : constant Rules.Rule_Id :=
              Add (Self.Kept.all, Self.Owner, Rules.Correct, Self.Kind, Entry_Text (Self), Correction (Self));
            pragma Unreferenced (Key);
         begin
            Read (Self);
         end;
      end if;
      Self.Entering := False;
      Parts.Bump (Self.Changes);
   end Execute;

end Grammar_VM;
