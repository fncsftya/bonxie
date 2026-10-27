package body Writing_VM.Trees is
   use type Items.Id;

   function Version (Self : Tree_Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes));
   function Count (Self : Tree_Model) return Natural
   is (Self.Rows.Count);
   function Element (Self : Tree_Model; Row : Positive) return Tree_Entry
   is (Self.Rows (Row));

   function Page_Count (Self : Tree_Model) return Natural
   is (Self.Pages.Count);
   function Page_At (Self : Tree_Model; Rank : Positive) return Items.Slot
   is (Self.Pages (Rank));

   function Rank_Of (Self : Tree_Model; Doc : Items.Slot) return Natural is
   begin
      for Rank in 1 .. Page_Count (Self) loop
         if Self.Pages (Rank) = Doc then
            return Rank;
         end if;
      end loop;
      return 0;
   end Rank_Of;

   procedure Index_Pages (Self : in out Tree_Model) is
   begin
      Self.Pages.Clear;
      for Dir of Self.Membership loop
         Dir := 0;
      end loop;
      for Node of Self.Rows loop
         if Node.Kind = Document_Leaf then
            Self.Pages.Append (Node.Doc);
            if Node.Doc > Self.Membership.Count then
               Self.Membership.Resize (Node.Doc, 0);
            end if;
            Self.Membership (Node.Doc) := Node.Dir;
         end if;
      end loop;
   end Index_Pages;

   procedure Reset (Self : in out Tree_Model) is
   begin
      if Count (Self) /= 0 then
         Self.Rows.Clear;
         Self.Pages.Clear;
         Self.Membership.Clear;
         Parts.Bump (Self.Changes);
      end if;
   end Reset;

   procedure Insert (Self : in out Tree_Model; Index : Positive; Node : Tree_Entry) is
   begin
      Self.Rows.Append (Node);
      for Row in reverse Index .. Count (Self) - 1 loop
         Self.Rows (Row + 1) := Self.Rows (Row);
      end loop;
      Self.Rows (Index) := Node;
      Index_Pages (Self);
      Parts.Bump (Self.Changes);
   end Insert;

   procedure Delete (Self : in out Tree_Model; Index : Positive) is
   begin
      Self.Rows.Delete (Index);
      Index_Pages (Self);
      Parts.Bump (Self.Changes);
   end Delete;

   procedure Arrange (Self : in out Tree_Model; Dirs : Directories; Docs : Documents) is
      Fresh : Tree_Entry_Array;
      function Placed (Position : Natural) return Natural
      is (if Position = 0 then Natural'Last else Position);
      procedure Children (Parent : Natural; Level : Natural) is
         Next_Doc, Next_Dir : Positive := 1;
      begin
         pragma Assert (Level <= Dirs.Count);
         loop
            while Next_Doc <= Docs.Count and then Docs (Next_Doc).Dir /= Parent loop
               Next_Doc := Next_Doc + 1;
            end loop;
            while Next_Dir <= Dirs.Count and then Parent_Of (Dirs, Next_Dir) /= Parent loop
               Next_Dir := Next_Dir + 1;
            end loop;
            exit when Next_Doc > Docs.Count and then Next_Dir > Dirs.Count;
            if Next_Dir <= Dirs.Count
              and then (Next_Doc > Docs.Count
                        or else Placed (Dirs (Next_Dir).Position) <= Placed (Docs (Next_Doc).Position))
            then
               Fresh.Append ((Kind => Directory_Node, Dir => Next_Dir, Doc => 0));
               Children (Next_Dir, Level + 1);
               Next_Dir := Next_Dir + 1;
            else
               Fresh.Append ((Kind => Document_Leaf, Dir => Parent, Doc => Docs (Next_Doc).Slot));
               Next_Doc := Next_Doc + 1;
            end if;
         end loop;
      end Children;
   begin
      Fresh.Append ((Kind => Overview_Node, others => 0));
      Children (0, 0);
      pragma Assert (Fresh.Count = 1 + Dirs.Count + Docs.Count);
      if Fresh.Count = Count (Self) then
         declare
            Same : Boolean := True;
         begin
            for Row in 1 .. Fresh.Count loop
               Same := Same and then Fresh (Row) = Self.Rows (Row);
            end loop;
            if Same then
               return;
            end if;
         end;
      end if;
      Self.Rows := Fresh;
      Index_Pages (Self);
      Parts.Bump (Self.Changes);
   end Arrange;

   function Leaf_Row (Self : Tree_Model; Doc : Items.Slot) return Natural is
   begin
      for Row in 1 .. Count (Self) loop
         if Self.Rows (Row).Kind = Document_Leaf and then Self.Rows (Row).Doc = Doc then
            return Row;
         end if;
      end loop;
      return 0;
   end Leaf_Row;

   function Directory_Of (Self : Tree_Model; Doc : Items.Slot) return Natural
   is (if Doc > Self.Membership.Count then 0 else Self.Membership (Doc));

   function Dir_Row (Self : Tree_Model; Dir : Positive) return Natural is
   begin
      for Row in 1 .. Count (Self) loop
         if Self.Rows (Row).Kind = Directory_Node and then Self.Rows (Row).Dir = Dir then
            return Row;
         end if;
      end loop;
      return 0;
   end Dir_Row;

   function Block_End (Self : Tree_Model; Dirs : Directories; Row : Positive) return Positive is
      Last : Positive := Row;
   begin
      if Self.Rows (Row).Kind = Directory_Node then
         while Last < Count (Self)
           and then Self.Rows (Last + 1).Kind /= Overview_Node
           and then Within (Dirs, Self.Rows (Last + 1).Dir, Self.Rows (Row).Dir)
         loop
            Last := Last + 1;
         end loop;
      end if;
      return Last;
   end Block_End;

   function Last_Of (Self : Tree_Model; Dirs : Directories; Dir : Natural) return Positive
   is (if Dir = 0 then Count (Self) + 1 else Block_End (Self, Dirs, Dir_Row (Self, Dir)) + 1);

   function Can_Execute (Self : Tree_Model; Dirs : Directories; Row, Index, Dir : Natural) return Boolean is
   begin
      if Row not in 2 .. Count (Self) or else Index not in 2 .. Count (Self) + 1 or else Dir > Dirs.Count then
         return False;
      end if;
      if Dir /= 0 and then Dir_Row (Self, Dir) = 0 then
         return False;
      end if;
      if Index /= Last_Of (Self, Dirs, Dir) then
         if Index > Count (Self) then
            return False;
         end if;
         declare
            Next_Node : constant Tree_Entry := Self.Rows (Index);
            Parent    : constant Natural :=
              (if Next_Node.Kind = Directory_Node then Parent_Of (Dirs, Next_Node.Dir) else Next_Node.Dir);
         begin
            if Parent /= Dir then
               return False;
            end if;
         end;
      end if;
      if Self.Rows (Row).Kind = Directory_Node then
         return
           Dirs (Self.Rows (Row).Dir).Section = 0
           and then not Within (Dirs, Dir, Self.Rows (Row).Dir)
           and then Index not in Row + 1 .. Block_End (Self, Dirs, Row);
      end if;
      return Self.Rows (Row).Kind = Document_Leaf;
   end Can_Execute;

   procedure Keep (Self : Tree_Model; Dirs : Directories; Store : in out Library'Class) is
   begin
      for Row in 2 .. Count (Self) loop
         declare
            Node : constant Tree_Entry := Self.Rows (Row);
         begin
            if Node.Kind = Directory_Node then
               Keep_Position (Store, Dirs (Node.Dir).Key, Row, Directory => True);
            else
               pragma Assert (Node.Kind = Document_Leaf);
               Keep_Position (Store, Key_Of (Store, Node.Doc), Row, Directory => False);
            end if;
         end;
      end loop;
      Touch (Store);
   end Keep;

   procedure Relocate
     (Self       : in out Tree_Model;
      Dirs       : in out Directories;
      Store      : in out Library'Class;
      Row, Index : Positive;
      Dir        : Natural)
   is
      Last       : constant Positive := Block_End (Self, Dirs, Row);
      Length     : constant Positive := Last - Row + 1;
      Node       : constant Tree_Entry := Self.Rows (Row);
      Parent_Key : constant Items.Id := (if Dir = 0 then 0 else Dirs (Dir).Key);
      Place      : Positive := Index;
      Moved      : Tree_Entry_Array;
      Reorder    : constant Boolean := Index not in Row .. Last + 1;
      Changed    : constant Boolean :=
        Reorder or else (if Node.Kind = Document_Leaf then Node.Dir /= Dir else Dirs (Node.Dir).Parent /= Parent_Key);
   begin
      if not Changed then
         return;
      end if;
      if Node.Kind = Document_Leaf then
         Self.Rows (Row).Dir := Dir;
         Keep_Membership (Store, Key_Of (Store, Node.Doc), Parent_Key);
      end if;
      if Reorder then
         for Each in Row .. Last loop
            Moved.Append (Self.Rows (Each));
         end loop;
         if Index > Last then
            Place := Index - Length;
         end if;
         for Each in Row .. Last loop
            Self.Rows.Delete (Row);
         end loop;
         for Each in reverse 1 .. Length loop
            Self.Rows.Append (Moved (Each));
            for At_Row in reverse Place .. Count (Self) - 1 loop
               Self.Rows (At_Row + 1) := Self.Rows (At_Row);
            end loop;
            Self.Rows (Place) := Moved (Each);
         end loop;
      end if;
      if Node.Kind = Directory_Node then
         Dirs (Node.Dir).Parent := Parent_Key;
         Keep_Parent (Store, Dirs (Node.Dir).Key, Parent_Key);
      end if;
      Index_Pages (Self);
      Parts.Bump (Self.Changes);
      Keep (Self, Dirs, Store);
   end Relocate;
end Writing_VM.Trees;
