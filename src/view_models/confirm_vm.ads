with Ada.Strings.Unbounded;
with Pomarine.View_Models;

--  The view-model of the dialog that asks before something is deleted: what it
--  is about (a project, a folder, a document, a source, the speech model's
--  files), what it says, and the answer. It names no widget, so the tests run it
--  without a window.
--
--  The dialog only asks. The view does what the answer says (it knows how to
--  delete a project, a folder or the model), from Answer.
package Confirm_VM is

   package Parts renames Pomarine.View_Models;

   type Subjects is (Nothing, Project, Folder, Document, Source, Model);
   --  What is to be deleted. Nothing: the dialog is not up.

   subtype Nodes is Subjects range Folder .. Source;
   --  What of the writing view's tree.

   type Command is (Confirm, Cancel);

   package Commands is new Parts.Command_Models (Command);

   type View_Model is limited new Commands.Model with private;

   --  Asking: whatever was asked before is forgotten.

   procedure Ask_Project (Self : in out View_Model; Row : Positive; Name : String)
     with Post => Subject (Self) = Project;
   --  About the project listed in the row.

   procedure Ask_Node (Self : in out View_Model; Kind : Nodes; Dir, Doc : Natural; Name : String)
     with Post => Subject (Self) = Kind;
   --  About a folder (Dir is which), or a document or source (Doc is its window, Dir the folder it
   --  is in, 0 if none).

   procedure Ask_Model (Self : in out View_Model; Size : String)
     with Post => Subject (Self) = Model;
   --  About the speech model's files, which are Size.

   function Subject (Self : View_Model) return Subjects;

   function Is_Asking (Self : View_Model) return Boolean;
   --  Whether the dialog is up, about anything.

   function Is_About_Node (Self : View_Model) return Boolean;
   --  Whether it is about a folder, a document or a source.

   --  What it says

   function Title (Self : View_Model) return String;
   --  "Delete project", "Delete folder", ...: of a project when nothing is asked.

   function Message (Self : View_Model) return String;
   --  'Delete “Name”?', in curved quotes.

   function Note (Self : View_Model) return String;
   --  "This cannot be undone.", or what else of the subject is worth saying.

   function Offers_Documents (Self : View_Model) return Boolean;
   --  Whether it asks, of a folder, to delete its documents too.

   function Delete_Documents (Self : View_Model) return Boolean;

   procedure Set_Delete_Documents (Self : in out View_Model; To : Boolean);

   overriding function Version (Self : View_Model) return Parts.Version_Number;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Both, while it is up.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => not Is_Asking (Self);
   --  Confirm: the dialog goes and its answer is kept. Cancel: it goes, and nothing is.

   --  The answer to the last Confirm

   type Answer is record
      Subject          : Subjects := Nothing;
      --  What was confirmed; Nothing if the dialog was cancelled.
      Row              : Natural := 0;
      --  Of a project.
      Dir, Doc         : Natural := 0;
      --  Of a node.
      Delete_Documents : Boolean := False;
   end record;

   function Last_Answer (Self : View_Model) return Answer;

private

   type View_Model is limited new Commands.Model with record
      Asked    : Answer;
      --  What the dialog is about; its Subject is Nothing when it is not up.
      Name     : Ada.Strings.Unbounded.Unbounded_String;
      Size     : Ada.Strings.Unbounded.Unbounded_String;
      Given    : Answer;
      Changes  : Parts.Change_Counter;
   end record;

end Confirm_VM;
