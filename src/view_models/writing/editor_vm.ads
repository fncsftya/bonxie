with Pomarine.View_Models;
with Texts;
with Texts.Documents;

--  Dictation into a versioned document, independent of how it is edited or drawn.

package Editor_VM is
   package Docs renames Texts.Documents;

   type Editor is limited interface;
   function Focused (Self : Editor) return Boolean is abstract;
   function Caret (Self : Editor) return Texts.Position is abstract;
   function Mark (Self : Editor) return Texts.Position is abstract;
   procedure Select_Range (Self : in out Editor; From, To : Texts.Position) is abstract;
   procedure Insert (Self : in out Editor; Text : String) is abstract;
   --  Insert through the editor so its caret, styles and undo behavior follow a normal edit.
   procedure Set_Faint (Self : in out Editor; From, To : Texts.Position) is abstract;
   procedure Clear_Faint (Self : in out Editor) is abstract;
   --  Clear every view that could show this dictation, including a second editor of the same document.

   type View_Model is limited private;
   function Is_Initialized (Self : View_Model) return Boolean;
   function Version (Self : View_Model) return Pomarine.View_Models.Version_Number;
   --  Document edits and dictation bookkeeping. The view receives caret/faint operations through Editor.
   procedure Initialize (Self : in out View_Model; Document : not null access Docs.Document);
   --  The document must outlive Self. Start with no provisional speech.
   procedure Reset (Self : in out View_Model)
   with Post => not Has_Live (Self);
   --  Forget bookkeeping when the owning item is assigned or released, after its views have been detached.
   function Has_Live (Self : View_Model) return Boolean;
   procedure Take_Back_Live (Self : in out View_Model; View : in out Editor'Class)
   with Pre => Is_Initialized (Self), Post => not Has_Live (Self);
   --  Remove provisional text unless another edit changed it; then retain it as typed text.
   procedure Show_Live (Self : in out View_Model; View : in out Editor'Class; Said : String; Settled : Natural := 0)
   with Pre => Is_Initialized (Self);
   --  Replace the provisional text without recording undo. Settled is a byte offset; faint text starts at a
   --  UTF-8 character boundary. Wait for typing to stop before showing more, retaining any speech already edited.
   procedure Append_Said (Self : in out View_Model; View : in out Editor'Class; Said : String)
   with Pre => Is_Initialized (Self), Post => not Has_Live (Self);
   --  Final text is one undoable edit, at the caret without replacing the selection if focused or moved;
   --  otherwise in a new paragraph, filling an empty last paragraph. Retained speech is not duplicated.
private
   type Live_State is record
      Shown      : Boolean := False;
      Moved      : Boolean := False;
      Done, Upto : Natural := 0;
      Version    : Docs.Version := 0;
      Break      : Boolean := False;
      From, To   : Texts.Position;
      Seen       : Docs.Version := 0;
   end record;
   type View_Model is limited record
      Document : Docs.Document_Access;
      Live     : Live_State;
      Changes  : Pomarine.View_Models.Change_Counter;
   end record;
end Editor_VM;
