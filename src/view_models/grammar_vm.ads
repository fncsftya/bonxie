with Harper;
with Pomarine.View_Models;
with Projects.Rules;

--  The view-model of a project's grammar rules: the rules it has (to ignore a text, or always correct it to
--  another) and the form that makes a correction, with when it can be made. It names no widget, so the
--  tests run it without a window. An injected engine supplies current diagnostic facts and applies card actions.
package Grammar_VM is

   package Parts renames Pomarine.View_Models;

   package Rules renames Projects.Rules;

   use type Projects.Id;

   Longest_Correction : constant := Harper.Max_Replacement;
   --  Bytes of a correction that can be a rule: what a suggestion can be.

   type Command is (Accept_Entry, Cancel_Entry, Toggle_Cards, Expand_Card, Apply_Fix, Edit_Rule, Ignore_Text);
   subtype Card_Command is Command range Toggle_Cards .. Ignore_Text;

   type Card_State is record
      Writing, Showing, Current, Editable, Has_Text : Boolean := False;
      Suggestions : Natural := 0;
   end record;
   --  Facts about the live diagnostic, queried at execution time so stale checks cannot edit replacement text.
   --  Expand_Card indexes a viewport card; Apply_Fix indexes a suggestion of the expanded diagnostic.
   --  The other commands take index zero.

   type Card_Engine is limited interface;
   function Inspect (Self : Card_Engine; What : Card_Command; Index : Natural) return Card_State is abstract;
   procedure Perform (Self : in out Card_Engine; What : Card_Command; Index : Natural) is abstract;

   package Commands is new Parts.Command_Models (Command);

   --  The rules kept.

   type Library is limited interface;

   procedure Load (Self : in out Library; Owner : Projects.Id; Result : out Rules.Rule_List) is abstract;

   function Add
     (Self        : in out Library;
      Owner       : Projects.Id;
      Action      : Rules.Actions;
      Kind        : Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Rules.Rule_Id is abstract;

   procedure Remove (Self : in out Library; Key : Rules.Rule_Id) is abstract;

   type Effects is limited interface;

   procedure Entry_Ended (Self : in out Effects; Accepted : Boolean) is abstract;
   --  The entry command has completed; the view can restore focus and recheck after a saved rule.

   type View_Model is limited new Commands.Model with private;

   procedure Attach_Cards (Self : in out View_Model; Engine : not null access Card_Engine'Class);
   --  Engine must outlive the model and its bindings.

   procedure Observe (Self : in out View_Model; Reactions : access Effects'Class);
   --  Reactions must outlive Self, or be removed with Observe (Self, null).

   procedure Initialize (Self : in out View_Model; Kept : not null access Library'Class);
   --  Kept must be there as long as the view-model is. No project's rules are in it.

   procedure Open (Self : in out View_Model; Owner : Projects.Id)
     with Post => Owner_Of (Self) = Owner;
   --  The rules of the project, unless they are those it has (and the entry is put away if they are not).

   procedure Forget (Self : in out View_Model)
     with Post => Owner_Of (Self) = 0;
   --  Let go of them, so that Open reads them again.

   function Owner_Of (Self : View_Model) return Projects.Id;

   function Current (Self : aliased View_Model) return access constant Rules.Rule_List;
   --  The rules, for checks to be read against.

   function Count (Self : View_Model) return Natural;

   function Rules_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever the rules are: a view checks again.

   procedure Ignore (Self : in out View_Model; Kind : Rules.Kind_Code; Pattern : String)
     with Pre => Owner_Of (Self) /= 0 and then Pattern'Length > 0;
   --  Never flag this text, of this kind.

   procedure Remove_Correction (Self : in out View_Model; Pattern : String; Removed : out Boolean)
     with Pre => Owner_Of (Self) /= 0;
   --  Take away the rule that always corrects the text. Removed is False if there is none.

   function Corrects (Self : View_Model; Pattern : String) return Boolean;
   --  Whether there is a rule that always corrects the text.

   --  The entry

   procedure Begin_Entry (Self : in out View_Model; Pattern : String; Kind : Rules.Kind_Code; Starting : String)
     with Pre  => Owner_Of (Self) /= 0 and then Pattern'Length > 0,
          Post => Is_Entering (Self) and then Correction (Self) = Starting;
   --  Begin a rule that always corrects the text of Pattern, of a diagnostic of this kind, to what is typed,
   --  which is Starting to begin with.

   function Is_Entering (Self : View_Model) return Boolean;

   function Entry_Text (Self : View_Model) return String;
   --  The text the rule is for.

   function Prompt (Self : View_Model) return String;
   --  'Always correct "text" to:'.

   function Correction (Self : View_Model) return String;

   procedure Set_Correction (Self : in out View_Model; Text : String)
     with Post => Correction (Self) = Text;
   --  What has been typed.

   overriding function Version (Self : View_Model) return Parts.Version_Number;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Card commands require the writing view and a current diagnostic; applying also requires an editable
   --  document and a valid suggestion. Rule actions require nonempty diagnostic text and an open project.
   --  Cancel_Entry: it is being made. Accept_Entry: and the correction is not the text itself, which
   --  would change nothing, and is not longer than a rule's can be.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => (if What in Accept_Entry | Cancel_Entry then not Is_Entering (Self));
   --  Accept_Entry makes the rule, and puts the entry away; Cancel_Entry puts it away.
   --  Card commands apply the action through the injected engine and leave entry lifecycle to that action.

private

   type Library_Access is access all Library'Class;
   type Effects_Access is access all Effects'Class;
   type Card_Engine_Access is access all Card_Engine'Class;

   type View_Model is limited new Commands.Model with record
      Kept     : Library_Access;
      Reactions : Effects_Access;
      Engine : Card_Engine_Access;
      Owner    : Projects.Id := 0;
      Known    : aliased Rules.Rule_List;
      Entering : Boolean := False;
      Text     : Projects.Titles.Text;
      Kind     : Rules.Kind_Code := 0;
      Typed    : Parts.Text_Property;
      Changes  : Parts.Change_Counter;
      Lists    : Parts.Change_Counter;
   end record;

end Grammar_VM;
