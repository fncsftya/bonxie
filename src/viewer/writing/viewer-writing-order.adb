with Viewer.Writing.Support;

package body Viewer.Writing.Order is

   package Windows renames Items.Windows;

   use type Items.Id;

   procedure Sync_Order (Item : in out Session) is
   begin
      Item.Reading.Write_Count := 0;
      for Row in 2 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Kind = Document_Leaf then
            Item.Reading.Write_Count := Item.Reading.Write_Count + 1;
            Item.Reading.Write_Order (Item.Reading.Write_Count)
               := Item.Docs.Tree (Row).Doc;
         end if;
      end loop;
   end Sync_Order;

   procedure Insert_Row
     (Item : in out Session; Index : Positive; Node : Tree_Entry) is
   begin
      for Row in reverse Index .. Item.Docs.Tree_Count loop
         Item.Docs.Tree (Row + 1) := Item.Docs.Tree (Row);
      end loop;
      Item.Docs.Tree (Index) := Node;
      Item.Docs.Tree_Count := Item.Docs.Tree_Count + 1;
   end Insert_Row;

   procedure Delete_Row (Item : in out Session; Index : Positive) is
   begin
      for Row in Index .. Item.Docs.Tree_Count - 1 loop
         Item.Docs.Tree (Row) := Item.Docs.Tree (Row + 1);
      end loop;
      Item.Docs.Tree_Count := Item.Docs.Tree_Count - 1;
   end Delete_Row;

   procedure Move_Block (Item : in out Session; From, Index : Positive) is
      Last   : constant Positive := Support.Block_End (Item, From);
      Length : constant Positive := Last - From + 1;
      Moved  : constant Tree_Entry_Array := Item.Docs.Tree;
      Place  : Positive := Index;
   begin
      if Index in From .. Last + 1 then
         return;
      end if;
      if Index > Last then
         Place := Index - Length;
      end if;
      for Each in reverse From .. Last loop
         Delete_Row (Item, From);
      end loop;
      for Each in 0 .. Length - 1 loop
         Insert_Row (Item, Place + Each, Moved (From + Each));
      end loop;
   end Move_Block;

   function Key_Of (Position : Natural) return Natural is
     (if Position = 0 then Natural'Last else Position);
   --  Never put comes after what was.

   procedure Arrange (Item : in out Session);
   --  Make the tree of the documents (as Write_Order and Doc_Dir have
   --  them, in the order kept) and the directories: each directory, and
   --  the documents in none, in the order kept, each directory's
   --  documents after it.

   procedure Arrange (Item : in out Session) is
      Total    : Natural := 1;
      Next_Doc : Positive := 1;
      Next_Dir : Positive := 1;
   begin
      Item.Docs.Tree (1) := (Kind => Overview_Node, others => 0);
      loop
         while Next_Doc <= Item.Reading.Write_Count
           and then Item.Docs.Doc_Dir (Item.Reading.Write_Order (Next_Doc))
              /= 0
         loop
            Next_Doc := Next_Doc + 1;
         end loop;
         exit when Next_Doc > Item.Reading.Write_Count
                   and then Next_Dir > Item.Docs.Dirs.Count;
         if Next_Dir <= Item.Docs.Dirs.Count
           and then
             (Next_Doc > Item.Reading.Write_Count
              or else Key_Of (Item.Docs.Dirs.Directories (Next_Dir).Position)
                      <= Key_Of
                           (Items.Directories.Position_Of
                              (Item.Nav.Store,
                               Windows.Details
                                 (Item.Windows
                                    (Item.Reading.Write_Order
                                       (Next_Doc))).Key)))
         then
            Total := Total + 1;
            Item.Docs.Tree (Total) :=
              (Kind => Directory_Node, Dir => Next_Dir, Doc => 0);
            for Rank in 1 .. Item.Reading.Write_Count loop
               if Item.Docs.Doc_Dir (Item.Reading.Write_Order (Rank))
                  = Next_Dir
               then
                  Total := Total + 1;
                  Item.Docs.Tree (Total) :=
                    (Kind => Document_Leaf, Dir => Next_Dir,
                     Doc  => Item.Reading.Write_Order (Rank));
               end if;
            end loop;
            Next_Dir := Next_Dir + 1;
         else
            Total := Total + 1;
            Item.Docs.Tree (Total) :=
              (Kind => Document_Leaf, Dir => 0,
               Doc  => Item.Reading.Write_Order (Next_Doc));
            Next_Doc := Next_Doc + 1;
         end if;
      end loop;
      Item.Docs.Tree_Count := Total;
      Sync_Order (Item);
   end Arrange;

   procedure Build_Order (Item : in out Session) is
      Ordered : Items.Id_List;
   begin
      Item.Reading.Write_Count := 0;
      Item.Reading.Source_Total := 0;
      Item.Docs.Shown_Dir := 0;
      Item.Docs.Doc_Dir := [others => 0];
      Items.Directories.Load_Directories
        (Item.Nav.Store, Item.Opened.Current, Item.Docs.Dirs);
      Items.Directories.Load_Order
        (Item.Nav.Store, Item.Opened.Current, Ordered);
      for Place in 1 .. Ordered.Count loop
         for Which in Items.Slot loop
            if Windows.Is_Assigned (Item.Windows (Which))
              and then Windows.Details (Item.Windows (Which)).Key
                       = Ordered.Keys (Place)
            then
               if Support.Is_Note (Item, Which) then
                  declare
                     Inside : constant Items.Id :=
                       Items.Directories.Directory_Of (Item.Nav.Store,
                                           Ordered.Keys (Place));
                  begin
                     for Dir in 1 .. Item.Docs.Dirs.Count loop
                        if Item.Docs.Dirs.Directories (Dir).Key = Inside then
                           Item.Docs.Doc_Dir (Which) := Dir;
                        end if;
                     end loop;
                  end;
                  Item.Reading.Write_Count := Item.Reading.Write_Count + 1;
                  Item.Reading.Write_Order (Item.Reading.Write_Count) := Which;
               else
                  Item.Reading.Source_Total := Item.Reading.Source_Total + 1;
                  Item.Reading.Source_Order (Item.Reading.Source_Total)
                     := Which;
               end if;
            end if;
         end loop;
      end loop;
      Arrange (Item);
   end Build_Order;

   procedure Keep_Directory (Item : in out Session; Which : Items.Slot) is
      Dir : constant Natural := Item.Docs.Doc_Dir (Which);
   begin
      Items.Directories.Set_Directory
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key,
         (if Dir = 0 then 0 else Item.Docs.Dirs.Directories (Dir).Key));
   end Keep_Directory;

   procedure Keep_Order (Item : in out Session) is
   begin
      --  A row's place is its number in the tree, directories and
      --  documents together.
      for Row in 2 .. Item.Docs.Tree_Count loop
         case Item.Docs.Tree (Row).Kind is
            when Directory_Node =>
               Items.Directories.Set_Directory_Position
                 (Item.Nav.Store,
                  Item.Docs.Dirs.Directories (Item.Docs.Tree (Row).Dir).Key,
                     Row);
            when Document_Leaf =>
               Items.Directories.Set_Position
                 (Item.Nav.Store,
                  Windows.Details
                    (Item.Windows (Item.Docs.Tree (Row).Doc)).Key,
                  Row);
            when Overview_Node =>
               null;
         end case;
      end loop;
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Keep_Order;

   function Last_Of (Item : Session; Dir : Natural) return Positive is
     (if Dir = 0 then Item.Docs.Tree_Count + 1
      else Support.Block_End (Item, Support.Dir_Row (Item, Dir)) + 1);

end Viewer.Writing.Order;
