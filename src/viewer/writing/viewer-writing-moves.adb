with Viewer.Outlines;
with Items.Directories;
with Viewer.Writing.Order;
with Viewer.Writing.Support;
with Viewer.Writing.Tree;

package body Viewer.Writing.Moves is

   procedure Relocate
     (Item : in out Session; Row, Index, Dir : Natural);
   --  Put the row, a document or a directory, before the Indexth row, and
   --  a document in the directory, or an ordinary folder in a section
   --  (none, if 0), and keep that.

   procedure Relocate
     (Item : in out Session; Row, Index, Dir : Natural) is
      Folder : constant Natural :=
        (if Item.Docs.Tree (Row).Kind = Directory_Node then Item.Docs.Tree (Row).Dir else 0);
   begin
      if Item.Docs.Tree (Row).Kind = Document_Leaf then
         Item.Docs.Doc_Dir (Item.Docs.Tree (Row).Doc) := Dir;
         Item.Docs.Tree (Row).Dir := Dir;
         Order.Keep_Directory (Item, Item.Docs.Tree (Row).Doc);
      end if;
      Order.Move_Block (Item, Row, Index);
      if Folder /= 0 then
         pragma Assert (not Support.Is_Section (Item, Folder));
         pragma Assert (not Support.Within (Item, Dir, Folder));
         Item.Docs.Dirs (Folder).Parent := (if Dir = 0 then 0 else Item.Docs.Dirs (Dir).Key);
         Items.Directories.Set_Parent
           (Item.Nav.Store, Item.Docs.Dirs (Folder).Key, Item.Docs.Dirs (Folder).Parent);
      end if;
      Outlines.Reload (Item);
      Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
      Item.Section_Menu.Seen := Item.Section_Menu.Changes;
      Order.Sync_Order (Item);
      Order.Keep_Order (Item);
      Tree.Refresh (Item);
   end Relocate;

   procedure Move_Page (Item : in out Session; From, To : Positive) is
      Beside : constant Items.Slot := Item.Reading.Write_Order (To);
   begin
      if From /= To then
         Relocate
           (Item, Support.Leaf_Row (Item, Item.Reading.Write_Order (From)),
            Support.Leaf_Row (Item, Beside) + (if From < To then 1 else 0),
            Item.Docs.Doc_Dir (Beside));
      end if;
   end Move_Page;

   procedure Move_Page_To_Directory
     (Item : in out Session; Rank : Positive; Directory : Natural) is
   begin
      Relocate
        (Item, Support.Leaf_Row (Item, Item.Reading.Write_Order (Rank)),
         Order.Last_Of (Item, Directory), Directory);
   end Move_Page_To_Directory;

   procedure Drop_Row
     (Item : in out Session; Row : Positive; Target : Drop_Target) is
   begin
      case Target.Kind is
         when No_Drop =>
            null;
         when Into_Node =>
            Relocate
              (Item, Row,
               Order.Last_Of (Item,
                        (if Item.Docs.Tree (Target.Row).Kind = Directory_Node
                         then Item.Docs.Tree (Target.Row).Dir else 0)),
               (if Item.Docs.Tree (Target.Row).Kind = Directory_Node
                then Item.Docs.Tree (Target.Row).Dir else 0));
         when Between =>
            Relocate (Item, Row, Target.Index, Target.Dir);
      end case;
   end Drop_Row;

end Viewer.Writing.Moves;
