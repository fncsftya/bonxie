with Writing_Sources_VM;
with Items.Models;
with Items.Directories;
with View.Build;
with View.Writing.Support;

package body View.Writing.Order is
   package Windows renames Items.Windows;
   package Models renames Items.Models;
   use type Items.Id;

   --  This adapter is used synchronously; the model never retains the session or its widgets.
   type Library is limited new Trees.Library with record
      Owner : Session_Access;
   end record;
   overriding function Key_Of (Self : Library; Doc : Items.Slot) return Items.Id;
   overriding procedure Keep_Position
     (Self : in out Library; Key : Items.Id; Position : Positive; Directory : Boolean);
   overriding procedure Keep_Membership (Self : in out Library; Key, Directory : Items.Id);
   overriding procedure Keep_Parent (Self : in out Library; Key, Parent : Items.Id);
   overriding procedure Touch (Self : in out Library);

   overriding function Key_Of (Self : Library; Doc : Items.Slot) return Items.Id is
     (Models.Details (Self.Owner.Models (Doc)).Key);
   overriding procedure Keep_Position
     (Self : in out Library; Key : Items.Id; Position : Positive; Directory : Boolean) is
   begin
      if Directory then
         Items.Directories.Set_Directory_Position (Self.Owner.Nav.Store, Key, Position);
      else
         Items.Directories.Set_Position (Self.Owner.Nav.Store, Key, Position);
      end if;
   end Keep_Position;
   overriding procedure Keep_Membership (Self : in out Library; Key, Directory : Items.Id) is
   begin
      Items.Directories.Set_Directory (Self.Owner.Nav.Store, Key, Directory);
   end Keep_Membership;
   overriding procedure Keep_Parent (Self : in out Library; Key, Parent : Items.Id) is
   begin
      Items.Directories.Set_Parent (Self.Owner.Nav.Store, Key, Parent);
   end Keep_Parent;
   overriding procedure Touch (Self : in out Library) is
   begin
      Projects.Touch (Self.Owner.Nav.Store, Open_Key (Self.Owner.all));
   end Touch;

   procedure Insert_Row (Item : in out Session; Index : Positive; Node : Tree_Entry) is
   begin
      Trees.Insert (Item.Docs.Ordering, Index, Node);
   end Insert_Row;

   procedure Delete_Row (Item : in out Session; Index : Positive) is
   begin
      Trees.Delete (Item.Docs.Ordering, Index);
   end Delete_Row;

   procedure Build_Order (Item : in out Session) is
      Ordered : Items.Id_List;
      Docs : Trees.Documents;
   begin
      Writing_Sources_VM.Reset (Item.Reading.Sources);
      Items.Directories.Load_Directories
        (Item.Nav.Store, Open_Key (Item), Item.Docs.Dirs);
      Build.Reserve_Rows (Item);
      Items.Directories.Load_Order
        (Item.Nav.Store, Open_Key (Item), Ordered);
      for Place in 1 .. Ordered.Count loop
         for Which in 1 .. Item.Windows.Count loop
            if Windows.Is_Assigned (Item.Windows (Which))
              and then Models.Details (Item.Models (Which)).Key
                       = Ordered (Place)
            then
               if Support.Is_Note (Item, Which) then
                  declare
                     Directory : Natural := 0;
                     Inside : constant Items.Id :=
                       Items.Directories.Directory_Of (Item.Nav.Store,
                                           Ordered (Place));
                  begin
                     for Dir in 1 .. Item.Docs.Dirs.Count loop
                        if Item.Docs.Dirs (Dir).Key = Inside then
                           Directory := Dir;
                        end if;
                     end loop;
                     Docs.Append
                       ((Slot => Which, Dir => Directory,
                         Position => Items.Directories.Position_Of (Item.Nav.Store, Ordered (Place))));
                  end;
               else
                  Writing_Sources_VM.Add (Item.Reading.Sources, Which);
               end if;
            end if;
         end loop;
      end loop;
      Trees.Arrange (Item.Docs.Ordering, Item.Docs.Dirs, Docs);
   end Build_Order;

   procedure Keep_Directory (Item : in out Session; Which : Items.Slot) is
      Dir : constant Natural := Trees.Directory_Of (Item.Docs.Ordering, Which);
      Store : Library := (Owner => Item'Unrestricted_Access);
   begin
      Keep_Membership (Store, Key_Of (Store, Which), (if Dir = 0 then 0 else Item.Docs.Dirs (Dir).Key));
   end Keep_Directory;

   procedure Keep_Order (Item : in out Session) is
      Store : Library := (Owner => Item'Unrestricted_Access);
   begin
      Trees.Keep (Item.Docs.Ordering, Item.Docs.Dirs, Store);
   end Keep_Order;

   procedure Relocate (Item : in out Session; Row, Index : Positive; Dir : Natural) is
      Store : Library := (Owner => Item'Unrestricted_Access);
   begin
      Trees.Relocate (Item.Docs.Ordering, Item.Docs.Dirs, Store, Row, Index, Dir);
   end Relocate;

   function Last_Of (Item : Session; Dir : Natural) return Positive is
     (Trees.Last_Of (Item.Docs.Ordering, Item.Docs.Dirs, Dir));
end View.Writing.Order;
