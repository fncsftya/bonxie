with View.Outlines;
with View.Writing.Order;
with View.Writing.Support;
with View.Writing.Tree;

package body View.Writing.Moves is

   procedure Relocate
     (Item : in out Session; Row, Index, Dir : Natural);
   --  Put the row, a document or a directory, before the Indexth row, and
   --  a document in the directory, or an ordinary folder in a section
   --  (none, if 0), and keep that.

   procedure Relocate
     (Item : in out Session; Row, Index, Dir : Natural) is
   begin
      Order.Relocate (Item, Row, Index, Dir);
      Outlines.Reload (Item);
      Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
      Item.Section_Menu.Seen := Item.Section_Menu.Changes;
      Tree.Refresh (Item);
   end Relocate;

   procedure Move_Page (Item : in out Session; From, To : Positive) is
      Beside : constant Items.Slot := Trees.Page_At (Item.Docs.Ordering, To);
   begin
      if From /= To then
         Relocate
           (Item, Support.Leaf_Row (Item, Trees.Page_At (Item.Docs.Ordering, From)),
            Support.Leaf_Row (Item, Beside) + (if From < To then 1 else 0),
            Trees.Directory_Of (Item.Docs.Ordering, Beside));
      end if;
   end Move_Page;

   procedure Move_Page_To_Directory
     (Item : in out Session; Rank : Positive; Directory : Natural) is
   begin
      Relocate
        (Item, Support.Leaf_Row (Item, Trees.Page_At (Item.Docs.Ordering, Rank)),
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
                        (if Trees.Element (Item.Docs.Ordering, Target.Row).Kind = Directory_Node
                         then Trees.Element (Item.Docs.Ordering, Target.Row).Dir else 0)),
               (if Trees.Element (Item.Docs.Ordering, Target.Row).Kind = Directory_Node
                then Trees.Element (Item.Docs.Ordering, Target.Row).Dir else 0));
         when Between =>
            Relocate (Item, Row, Target.Index, Target.Dir);
      end case;
   end Drop_Row;

end View.Writing.Moves;
