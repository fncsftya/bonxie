with Items.Directories;
with Pomarine.View_Models;

--  Writing navigation uses persisted keys; directory indices belong to the current loaded tree.

package Writing_VM is
   package Parts renames Pomarine.View_Models;
   subtype Directories is Items.Directories.Directory_List;
   type View_Model is limited private;
   --  Version tracks the selected key; Shown resolves its current row on each query.
   function Version (Self : View_Model) return Parts.Version_Number;
   function Shown (Self : View_Model; Dirs : Directories) return Natural;
   function Can_Execute (Dirs : Directories; Directory : Natural) return Boolean
   is (Directory <= Dirs.Count);
   procedure Show (Self : in out View_Model; Dirs : Directories; Directory : Natural)
   with Pre => Can_Execute (Dirs, Directory), Post => Shown (Self, Dirs) = Directory;
   procedure Reconcile (Self : in out View_Model; Dirs : Directories);
   --  Retain selection across reordering; a deleted directory returns to Overview.
   procedure Reset (Self : in out View_Model);
   function Parent_Of (Dirs : Directories; Dir : Natural) return Natural
   with Pre => Dir <= Dirs.Count;
   function Depth (Dirs : Directories; Dir : Natural) return Natural
   with Pre => Dir <= Dirs.Count;
   function Section_Directory (Dirs : Directories; Dir : Natural) return Natural
   with Pre => Dir <= Dirs.Count;
   function Within (Dirs : Directories; Dir, Ancestor : Natural) return Boolean
   with Pre => Dir <= Dirs.Count and then Ancestor <= Dirs.Count;
   function In_View (Self : View_Model; Dirs : Directories; Directory : Natural) return Boolean
   with Pre => Directory <= Dirs.Count;
private
   type View_Model is limited record
      Selected : Items.Id := 0;
      Changes  : Parts.Change_Counter;
   end record;
end Writing_VM;
