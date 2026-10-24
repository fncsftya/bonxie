package body Home_VM_Fakes is

   use type Projects.Id;

   procedure Add (Self : in out Few; Title : String; Documents : Natural := 0; Sources : Natural := 0) is
   begin
      Self.Last := Self.Last + 1;
      Self.Table (Self.Last) :=
        (Key => Self.Next, Length => Title'Length, Documents => Documents, Sources => Sources, others => <>);
      Self.Table (Self.Last).Title (1 .. Title'Length) := Title;
      Self.Next := Self.Next + Projects.Id'(1);
   end Add;

   function Titles (Self : Few) return String is
      Said : String (1 .. 600);
      Used : Natural := 0;
   begin
      for Each in reverse 1 .. Self.Last loop
         if Used > 0 then
            Said (Used + 1) := ',';
            Used := Used + 1;
         end if;
         Said (Used + 1 .. Used + Self.Table (Each).Length) :=
           Self.Table (Each).Title (1 .. Self.Table (Each).Length);
         Used := Used + Self.Table (Each).Length;
      end loop;
      return Said (1 .. Used);
   end Titles;

   function Looked (Self : Few) return Natural is (Self.Listed);

   overriding procedure Recent (Self : in out Few; Into : out Projects.Recent_List) is
   begin
      Self.Listed := Self.Listed + 1;
      Into := (others => <>);
      for Each in reverse 1 .. Self.Last loop
         exit when Into.Count = Projects.Recent_Count;
         Into.Count := Into.Count + 1;
         Into.Items (Into.Count).Key := Self.Table (Each).Key;
         Into.Items (Into.Count).Title :=
           Projects.Titles.To_Text (Self.Table (Each).Title (1 .. Self.Table (Each).Length));
      end loop;
   end Recent;

   overriding procedure Count_Items (Self : in out Few; Key : Projects.Id; Documents, Sources : out Natural) is
   begin
      Documents := 0;
      Sources := 0;
      for Each in 1 .. Self.Last loop
         if Self.Table (Each).Key = Key then
            Documents := Self.Table (Each).Documents;
            Sources := Self.Table (Each).Sources;
         end if;
      end loop;
   end Count_Items;

   overriding procedure Delete (Self : in out Few; Key : Projects.Id) is
   begin
      for Each in 1 .. Self.Last loop
         if Self.Table (Each).Key = Key then
            Self.Table (Each .. Self.Last - 1) := Self.Table (Each + 1 .. Self.Last);
            Self.Last := Self.Last - 1;
            return;
         end if;
      end loop;
   end Delete;

   overriding procedure Rename (Self : in out Few; Key : Projects.Id; Title : String) is
   begin
      for Each in 1 .. Self.Last loop
         if Self.Table (Each).Key = Key then
            declare
               Renamed : Known := Self.Table (Each);
            begin
               Renamed.Length := Title'Length;
               Renamed.Title := [others => ' '];
               Renamed.Title (1 .. Title'Length) := Title;
               Delete (Self, Key);
               Self.Last := Self.Last + 1;
               Self.Table (Self.Last) := Renamed;
            end;
            return;
         end if;
      end loop;
   end Rename;

end Home_VM_Fakes;
