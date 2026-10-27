with Items.Models.Tables;
with Nav_VM;
with Naming_VM;
with Writing_VM.Trees;

--  Page commands use the current tree: pooled page widgets retain ranks, not document identities.

package Writing_VM.Actions is
   type Command is
     (Open_Sources,
      Toggle_Dictation,
      Use_Tool,
      Follow_Link,
      Ask_Link,
      Begin_Page_Title,
      End_Page_Title,
      Select_Row,
      Rename_Row,
      End_Name_Edit,
      End_Source_Name_Edit,
      Open_Section_Menu);
   package Commands is new Parts.Command_Models (Command);
   type Effects is limited interface;
   procedure Open_Sources (Self : in out Effects; Rank : Positive) is abstract;
   procedure Toggle_Dictation (Self : in out Effects; Slot : Items.Slot) is abstract;
   procedure Use_Tool (Self : in out Effects; Rank : Positive; Tool : Positive) is abstract;
   procedure Follow_Link (Self : in out Effects; Rank : Positive) is abstract;
   procedure Ask_Link (Self : in out Effects; Rank : Positive) is abstract;
   procedure Begin_Page_Title (Self : in out Effects; Rank : Positive) is abstract;
   procedure End_Page_Title (Self : in out Effects; Rank : Positive) is abstract;
   procedure Open_Section_Menu (Self : in out Effects; Rank : Positive) is abstract;
   procedure Select_Row (Self : in out Effects; Row : Positive) is abstract;
   procedure Rename_Row (Self : in out Effects; Row : Positive) is abstract;
   procedure End_Name_Edit (Self : in out Effects) is abstract;
   procedure End_Source_Name_Edit (Self : in out Effects) is abstract;

   Tools_Per_Page : constant := 8;
   --  The tools a page's text may have (Editors.Tool_Capacity; the view checks the two agree).
   function Tool_Index (Rank : Positive; Tool : Positive) return Positive
   is (Rank * Tools_Per_Page + Tool)
   with Pre => Tool <= Tools_Per_Page;
   --  The Index of Use_Tool: the page, which of its tools (as Contexts.Tool_Index). The others take the rank.

   type Page_Model is limited new Commands.Model with private;
   procedure Initialize
     (Self       : in out Page_Model;
      Navigation : not null access Nav_VM.View_Model;
      Tree       : not null access Trees.Tree_Model;
      Models     : not null access Items.Models.Tables.Table;
      Names      : not null access Naming_VM.Model;
      Surface    : not null access Effects'Class);
   --  Dependencies outlive Self.
   overriding
   function Version (Self : Page_Model) return Parts.Version_Number;
   overriding
   function Can_Execute (Self : Page_Model; What : Command; Index : Natural := 0) return Boolean;
   --  A page's commands: a live document rank, in Write with no modal layer; Transcription cannot be
   --  interrupted; Begin_Page_Title: its title is not being edited; End_Page_Title: it is, whatever the screen (the
   --  person may leave the field as a dialog opens). Select_Row and Rename_Row: a row of the tree. End_Name_Edit
   --  and End_Source_Name_Edit (Index 0): in Write with no modal layer, and a name is being edited.
   overriding
   procedure Execute (Self : in out Page_Model; What : Command; Index : Natural := 0);
private
   type Nav_Access is access all Nav_VM.View_Model;
   type Tree_Access is access all Trees.Tree_Model;
   type Names_Access is access all Naming_VM.Model;
   type Models_Access is access all Items.Models.Tables.Table;
   type Effects_Access is access all Effects'Class;
   type Page_Model is limited new Commands.Model with record
      Navigation : Nav_Access;
      Tree       : Tree_Access;
      Names      : Names_Access;
      Models     : Models_Access;
      Surface    : Effects_Access;
   end record;
end Writing_VM.Actions;
