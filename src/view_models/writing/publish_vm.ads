with Long_Texts;
with Pomarine.Events;
with Nav_VM;
with Pomarine.View_Models;

--  Publishing choices and format-menu rules; document layout and platform effects belong to the view.
--  A format is one of a fixed few. Those that are text (Markdown, plain text, HTML) have a source to show beside the
--  page and to copy; the others are files (an e-book, a word processor's, a PDF) that are only exported.

package Publish_VM is
   package Parts renames Pomarine.View_Models;
   type Command is
     (Toggle_Section_Headings, Toggle_Document_Headings, Toggle_Format, Choose_Format, Close_Format, Export, Copy);
   package Commands is new Parts.Command_Models (Command);

   type Formats is (Markdown, Plain_Text, HTML, EPUB, ODT, DOCX, PDF);
   --  In the order of the format menu, whose row is the format's place.

   function Label (Which : Formats) return String;
   --  What the menu and the file dialog call it.

   function Extension (Which : Formats) return String
   with Post => Extension'Result'Length > 0;
   --  The ending of its files, lower case, without the dot.

   function Has_Source (Which : Formats) return Boolean
   is (Which in Markdown | Plain_Text | HTML);
   --  Whether it is text, to show as it will be written and to copy.

   type Export_States is (Waiting, Cancelled, Chosen);
   type Effects is limited interface;
   function Export_Available (Self : Effects) return Boolean is abstract;
   function Copy_Available (Self : Effects) return Boolean is abstract;
   function Render (Self : Effects; Which : Formats) return String is abstract;
   --  The document as a file of that format: text for Markdown, plain text and HTML, bytes for the others.
   function Clock (Self : Effects) return Pomarine.Events.Milliseconds is abstract;
   procedure Ask_Export (Self : in out Effects; Which : Formats) is abstract
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
   function Has_Format (Self : View_Model) return Boolean;
   --  Whether one has been chosen.
   function Format (Self : View_Model) return Formats
   with Pre => Has_Format (Self);
   function Source_Shown (Self : View_Model) return Boolean;
   --  Whether the format chosen is text, whose source is shown beside the page.
   function Format_Open (Self : View_Model) return Boolean;
   function Export_Pending (Self : View_Model) return Boolean;
   function Copy_Caption (Self : View_Model) return String;
   function Copy_Remaining (Self : View_Model) return Integer;
   --  Milliseconds until copy confirmation expires; -1 if it is not showing.
   procedure Poll (Self : in out View_Model);
   --  Complete a pending export from its captured text, and expire copy confirmation.
   function File_Name (Path : String; Which : Formats) return String
   with Pre => Path'Length > 0;
   --  Keep an explicit extension, otherwise append the format's; dots in directories do not count.
   function Content_Version (Self : View_Model) return Parts.Version_Number;
   overriding
   function Version (Self : View_Model) return Parts.Version_Number;
   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Choices require Publish with no modal layer. Choose_Format takes the row of the open menu, a format's place
   --  from 1; other commands take Index 0. Close_Format also works when leaving Publish.
   --  Export and Copy require a format and their platform capability, and Copy that it be text. Export requires a
   --  store and no pending export.
   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
   with
     Post =>
       (case What is
          when Toggle_Section_Headings  => Section_Headings (Self) /= Section_Headings (Self)'Old,
          when Toggle_Document_Headings => Document_Headings (Self) /= Document_Headings (Self)'Old,
          when Toggle_Format            => Format_Open (Self) /= Format_Open (Self)'Old,
          when Choose_Format            =>
            Has_Format (Self) and then Format (Self) = Formats'Val (Index - 1) and then not Format_Open (Self),
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
      Which, Saving                       : Formats := Markdown;
      --  Saving is the format being exported, which the menu may change while the dialog is open.
      Content, Menu, Status               : Parts.Change_Counter;
   end record;
end Publish_VM;
