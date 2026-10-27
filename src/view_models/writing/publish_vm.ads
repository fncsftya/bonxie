with Long_Texts;
with Pomarine.Events;
with Nav_VM;
with Pomarine.View_Models;

--  Publishing choices and format-menu rules; document layout and platform effects belong to the view.

package Publish_VM is
   package Parts renames Pomarine.View_Models;
   type Command is
     (Toggle_Section_Headings, Toggle_Document_Headings, Toggle_Format, Choose_Markdown, Close_Format, Export, Copy);
   package Commands is new Parts.Command_Models (Command);
   type Export_States is (Waiting, Cancelled, Chosen);
   type Effects is limited interface;
   function Export_Available (Self : Effects) return Boolean is abstract;
   function Copy_Available (Self : Effects) return Boolean is abstract;
   function Markdown_Text (Self : Effects) return String is abstract;
   function Clock (Self : Effects) return Pomarine.Events.Milliseconds is abstract;
   procedure Ask_Export (Self : in out Effects) is abstract
   with Pre'Class => Export_Available (Self);
   procedure Export_Result (Self : in out Effects; State : out Export_States; Path : out Long_Texts.Text) is abstract;
   --  Consume a completed dialog result once; Waiting keeps it open.
   procedure Copy_Text (Self : in out Effects; Words : String; Succeeded : out Boolean) is abstract
   with Pre'Class => Copy_Available (Self);
   --  Succeeded means that the clipboard now contains Words.

   type Store is limited interface;
   procedure Save (Self : in out Store; Path, Words : String) is abstract
   with Pre'Class => Path'Length > 0;

   type View_Model is limited new Commands.Model with private;
   procedure Initialize
     (Self       : in out View_Model;
      Navigation : not null access Nav_VM.View_Model;
      Platform   : access Effects'Class := null;
      Files      : access Store'Class := null);
   --  Dependencies must outlive Self. Choices remain across project and view changes.
   function Section_Headings (Self : View_Model) return Boolean;
   function Document_Headings (Self : View_Model) return Boolean;
   function Markdown (Self : View_Model) return Boolean;
   function Format_Open (Self : View_Model) return Boolean;
   function Export_Pending (Self : View_Model) return Boolean;
   function Copy_Caption (Self : View_Model) return String;
   function Copy_Remaining (Self : View_Model) return Integer;
   --  Milliseconds until copy confirmation expires; -1 if it is not showing.
   procedure Poll (Self : in out View_Model);
   --  Complete a pending export from its captured text, and expire copy confirmation.
   function File_Name (Path : String) return String
   with Pre => Path'Length > 0;
   --  Keep an explicit extension, otherwise append .md; dots in directories do not count.
   function Content_Version (Self : View_Model) return Parts.Version_Number;
   overriding
   function Version (Self : View_Model) return Parts.Version_Number;
   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Choices require Publish with no modal layer. Choose_Markdown takes row 1 of the open menu;
   --  other commands take Index 0. Close_Format also works when leaving Publish.
   --  Export and Copy require Markdown and their platform capability. Export requires a store and no pending export.
   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
   with
     Post =>
       (case What is
          when Toggle_Section_Headings  => Section_Headings (Self) /= Section_Headings (Self)'Old,
          when Toggle_Document_Headings => Document_Headings (Self) /= Document_Headings (Self)'Old,
          when Toggle_Format            => Format_Open (Self) /= Format_Open (Self)'Old,
          when Choose_Markdown          => Markdown (Self) and then not Format_Open (Self),
          when Close_Format             => not Format_Open (Self),
          when Export                   => Export_Pending (Self),
          when Copy                     => True);
private
   type Nav_Access is access all Nav_VM.View_Model;
   type Effects_Access is access all Effects'Class;
   type Store_Access is access all Store'Class;
   type View_Model is limited new Commands.Model with record
      Navigation                          : Nav_Access;
      Platform                            : Effects_Access;
      Files                               : Store_Access;
      Pending, Copied                     : Boolean := False;
      Snapshot                            : Long_Texts.Text;
      Copied_Until                        : Pomarine.Events.Milliseconds := 0;
      Sections, Documents, Chosen, Opened : Boolean := False;
      Content, Menu, Status               : Parts.Change_Counter;
   end record;
end Publish_VM;
