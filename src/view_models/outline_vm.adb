package body Outline_VM is

   use type Sections.Section_Id;
   use type Projects.Id;

   function Count (Self : View_Model) return Natural is (Self.Order.Count);

   function Section_At (Self : View_Model; Row : Positive) return Sections.Section is (Self.Order (Row));

   function Title (Self : View_Model; Row : Positive) return String is
     (Sections.Title_Texts.To_String (Self.Order (Row).Title));

   function Notes (Self : View_Model; Row : Positive) return String is
     (Sections.Note_Texts.To_String (Self.Order (Row).Notes));

   function Stored_Notes (Self : in out View_Model; Row : Positive) return String is
     (Stored_Notes (Self.Kept.all, Self.Order (Row).Key));

   function Is_Open (Self : View_Model; Row : Positive) return Boolean is (Self.Order (Row).Open);

   function Is_Entered (Self : View_Model) return Boolean is (Self.Owner /= 0);

   function Project_Title (Self : View_Model) return String is (Projects.Titles.To_String (Self.Title));

   function Title_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Names));

   function Project_Description (Self : View_Model) return String is (Projects.Titles.To_String (Self.Words));

   function Trimmed (Text : String) return String is
      First : Positive := Text'First;
      Last  : Natural := Text'Last;
   begin
      while First <= Last and then Text (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Text (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Trimmed;

   function Documents_In (Self : View_Model; Row : Positive) return Natural is
      Total : Natural := 0;
   begin
      for Each in 1 .. Self.Links.Count loop
         if Self.Links (Each).Section = Self.Order (Row).Key then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Documents_In;

   function Index_Of_Key (Self : View_Model; Key : Sections.Section_Id) return Natural is
   begin
      for Place in 1 .. Self.Order.Count loop
         if Self.Order (Place).Key = Key then
            return Place;
         end if;
      end loop;
      return 0;
   end Index_Of_Key;

   function Section_Of_Item (Self : View_Model; Item : Long_Integer) return Natural is
   begin
      for Each in 1 .. Self.Links.Count loop
         if Self.Links (Each).Item = Item then
            declare
               Place : constant Natural := Index_Of_Key (Self, Self.Links (Each).Section);
            begin
               if Place /= 0 then
                  return Place;
               end if;
            end;
         end if;
      end loop;
      return 0;
   end Section_Of_Item;

   function Can_Move_Up (Self : View_Model; Row : Positive) return Boolean is
     (Row > 1 and then Row <= Self.Order.Count);

   function Can_Move_Down (Self : View_Model; Row : Positive) return Boolean is (Row < Self.Order.Count);

   overriding function Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Changes));

   --  Read the sections, and which are open: the ones with notes, and the ones that were.
   procedure Read (Self : in out View_Model) is
      Was : constant Sections.Section_List := Self.Order;
   begin
      Load (Self.Kept.all, Self.Owner, Self.Order, Self.Links);
      for Each in 1 .. Self.Order.Count loop
         declare
            Section : Sections.Section renames Self.Order (Each);
         begin
            Section.Open := Sections.Note_Texts.Length (Section.Notes) > 0;
            for Before in 1 .. Was.Count loop
               if Was (Before).Key = Section.Key then
                  Section.Open := Was (Before).Open or else Section.Open;
               end if;
            end loop;
         end;
      end loop;
   end Read;

   procedure Initialize (Self : in out View_Model; Kept : not null access Library'Class) is
   begin
      Self.Kept := Kept.all'Unrestricted_Access;
   end Initialize;

   procedure Reload_Project (Self : in out View_Model) is
      Found : Boolean;
   begin
      Project_Words (Self.Kept.all, Self.Owner, Found, Self.Title, Self.Words);
      Parts.Bump (Self.Changes);
      Parts.Bump (Self.Names);
   end Reload_Project;

   procedure Enter (Self : in out View_Model; Owner : Projects.Id) is
   begin
      Self.Owner := Owner;
      Reload_Project (Self);
      Self.Order.Count := 0;
      Read (Self);
   end Enter;

   procedure Leave (Self : in out View_Model) is
   begin
      Self.Owner := 0;
      Self.Order.Count := 0;
      Self.Links.Count := 0;
      Self.Title := Projects.Titles.Null_Text;
      Parts.Bump (Self.Changes);
      Parts.Bump (Self.Names);
   end Leave;

   procedure Reload (Self : in out View_Model) is
   begin
      Read (Self);
      Parts.Bump (Self.Changes);
   end Reload;

   procedure Set_Project_Title (Self : in out View_Model; Text : String; Kept : out Boolean) is
      Name : constant String := Trimmed (Text);
   begin
      Kept := Name /= "";
      if Kept then
         Rename_Project (Self.Kept.all, Self.Owner, Name);
         Self.Title := Projects.Titles.To_Text (Name);
         Parts.Bump (Self.Changes);
         Parts.Bump (Self.Names);
      end if;
   end Set_Project_Title;

   procedure Set_Project_Description (Self : in out View_Model; Stored : String) is
   begin
      Keep_Description (Self.Kept.all, Self.Owner, Stored);
      Self.Words := Projects.Titles.To_Text (Stored);
   end Set_Project_Description;

   procedure Set_Title (Self : in out View_Model; Row : Positive; Text : String) is
   begin
      declare
         Section : Sections.Section renames Self.Order (Row);
      begin
         Section.Title := Sections.Title_Texts.To_Text (Text);
      end;
      Rename (Self.Kept.all, Self.Order (Row).Key, Text);
      Parts.Bump (Self.Changes);
   end Set_Title;

   procedure Set_Notes (Self : in out View_Model; Row : Positive; Text, Stored : String) is
   begin
      declare
         Section : Sections.Section renames Self.Order (Row);
      begin
         Section.Notes := Sections.Note_Texts.To_Text (Text);
      end;
      Keep_Notes (Self.Kept.all, Self.Order (Row).Key, Stored);
      Parts.Bump (Self.Changes);
   end Set_Notes;

   procedure Set_Colour (Self : in out View_Model; Row : Positive; Colour : Sections.Colour_Value) is
   begin
      Set_Colour (Self.Kept.all, Self.Order (Row).Key, Colour);
      declare
         Section : Sections.Section renames Self.Order (Row);
      begin
         Section.Colour := Colour;
      end;
      Parts.Bump (Self.Changes);
   end Set_Colour;

   procedure Move (Self : in out View_Model; From, To : Positive) is
   begin
      if From = To then
         return;
      end if;
      declare
         Moved : constant Sections.Section := Self.Order (From);
      begin
         if From < To then
            for Each in From .. To - 1 loop
               Self.Order (Each) := Self.Order (Each + 1);
            end loop;
         else
            for Each in reverse To + 1 .. From loop
               Self.Order (Each) := Self.Order (Each - 1);
            end loop;
         end if;
         Self.Order (To) := Moved;
      end;
      declare
         Keys : constant Sections.Key_Array (1 .. Self.Order.Count) :=
           [for Each in 1 .. Self.Order.Count => Self.Order (Each).Key];
      begin
         Set_Order (Self.Kept.all, Self.Owner, Keys);
      end;
      Parts.Bump (Self.Changes);
   end Move;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
     (case What is
         when Add_Section =>
            Is_Entered (Self),
         when Move_Up =>
            (if Index = 0 then Self.Order.Count > 1 else Index in 2 .. Self.Order.Count),
         when Move_Down =>
            (if Index = 0 then Self.Order.Count > 1 else Index in 1 .. Self.Order.Count - 1),
         when Remove_Section | Toggle_Notes =>
            (if Index = 0 then Self.Order.Count > 0 else Index <= Self.Order.Count));

   procedure Observe (Self : in out View_Model; Reactions : access Effects'Class) is
   begin
      Self.Reactions := (if Reactions = null then null else Reactions.all'Unrestricted_Access);
   end Observe;

   procedure Run (Self : in out View_Model; What : Command; Index : Natural);

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
   begin
      if Self.Reactions /= null then
         Outline_Going (Self.Reactions.all, What, Index);
      end if;
      Run (Self, What, Index);
      if Self.Reactions /= null then
         Outline_Done (Self.Reactions.all, What, Index);
      end if;
   end Execute;

   procedure Run (Self : in out View_Model; What : Command; Index : Natural) is
   begin
      if What in Move_Up | Move_Down | Remove_Section | Toggle_Notes and then Index not in 1 .. Self.Order.Count then
         raise Constraint_Error with "no such section" & Index'Image;
      end if;
      case What is
         when Add_Section =>
            declare
               Key : constant Sections.Section_Id := Add (Self.Kept.all, Self.Owner, Untitled_Section);
               pragma Unreferenced (Key);
            begin
               Read (Self);
            end;
         when Move_Up =>
            Move (Self, Index, Index - 1);
         when Move_Down =>
            Move (Self, Index, Index + 1);
         when Remove_Section =>
            Delete (Self.Kept.all, Self.Order (Index).Key);
            Load_Links (Self.Kept.all, Self.Owner, Self.Links);
            Self.Order.Delete (Index);
         when Toggle_Notes =>
            declare
               Section : Sections.Section renames Self.Order (Index);
            begin
               Section.Open := not Section.Open;
            end;
      end case;
      Parts.Bump (Self.Changes);
   end Run;

end Outline_VM;
