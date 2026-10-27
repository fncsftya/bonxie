with Growing;

--  Document order and subtree commands, independent of row widgets and drag geometry.

package Writing_VM.Trees is
   type Tree_Kinds is (Overview_Node, Directory_Node, Document_Leaf);

   type Tree_Entry is record
      Kind : Tree_Kinds := Overview_Node;
      Dir  : Natural := 0;
      --  Of a directory, which it is (of Dirs); of a document, the
      --  directory it is in, 0 if none.
      Doc  : Natural := 0;
      --  Of a document, its window.
   end record;
   --  What a row of the tree is of.

   package Tree_Entry_Lists is new Growing (Tree_Entry);
   subtype Tree_Entry_Array is Tree_Entry_Lists.List;

   type Library is limited interface;
   function Key_Of (Self : Library; Doc : Items.Slot) return Items.Id is abstract;
   procedure Keep_Position (Self : in out Library; Key : Items.Id; Position : Positive; Directory : Boolean)
   is abstract;
   procedure Keep_Membership (Self : in out Library; Key, Directory : Items.Id) is abstract;
   procedure Keep_Parent (Self : in out Library; Key, Parent : Items.Id) is abstract;
   procedure Touch (Self : in out Library) is abstract;

   type Document is record
      Slot          : Items.Slot := 1;
      Dir, Position : Natural := 0;
   end record;
   package Document_Lists is new Growing (Document);
   subtype Documents is Document_Lists.List;

   type Tree_Model is limited private;
   function Version (Self : Tree_Model) return Parts.Version_Number;
   function Count (Self : Tree_Model) return Natural;
   function Element (Self : Tree_Model; Row : Positive) return Tree_Entry
   with Pre => Row <= Count (Self);
   function Page_Count (Self : Tree_Model) return Natural;
   function Page_At (Self : Tree_Model; Rank : Positive) return Items.Slot
   with Pre => Rank <= Page_Count (Self);
   function Rank_Of (Self : Tree_Model; Doc : Items.Slot) return Natural;
   procedure Reset (Self : in out Tree_Model)
   with Post => Count (Self) = 0;
   procedure Arrange (Self : in out Tree_Model; Dirs : Directories; Docs : Documents);
   --  Docs and Dirs are in persisted order. Zero positions follow placed entries; directory ties win.
   procedure Insert (Self : in out Tree_Model; Index : Positive; Node : Tree_Entry)
   with Pre => Index in 2 .. Count (Self) + 1, Post => Count (Self) = Count (Self)'Old + 1;
   procedure Delete (Self : in out Tree_Model; Index : Positive)
   with Pre => Index in 2 .. Count (Self), Post => Count (Self) = Count (Self)'Old - 1;
   function Leaf_Row (Self : Tree_Model; Doc : Items.Slot) return Natural;
   function Directory_Of (Self : Tree_Model; Doc : Items.Slot) return Natural;
   function Dir_Row (Self : Tree_Model; Dir : Positive) return Natural;
   function Block_End (Self : Tree_Model; Dirs : Directories; Row : Positive) return Positive
   with Pre => Row <= Count (Self);
   function Last_Of (Self : Tree_Model; Dirs : Directories; Dir : Natural) return Positive
   with Pre => Dir <= Dirs.Count and then (Dir = 0 or else Dir_Row (Self, Dir) /= 0);
   function Can_Execute (Self : Tree_Model; Dirs : Directories; Row, Index, Dir : Natural) return Boolean;
   procedure Relocate
     (Self       : in out Tree_Model;
      Dirs       : in out Directories;
      Store      : in out Library'Class;
      Row, Index : Positive;
      Dir        : Natural)
   with Pre => Can_Execute (Self, Dirs, Row, Index, Dir);
   procedure Keep (Self : Tree_Model; Dirs : Directories; Store : in out Library'Class);
private
   package Page_Lists is new Growing (Items.Slot);
   package Membership_Lists is new Growing (Natural);
   type Tree_Model is limited record
      Rows       : Tree_Entry_Array;
      Pages      : Page_Lists.List;
      Membership : Membership_Lists.List;
      Changes    : Parts.Change_Counter;
   end record;
end Writing_VM.Trees;
