private package View.Grammar is
   function Inspect
     (Item : Session; What : Grammar_VM.Card_Command; Index : Natural) return Grammar_VM.Card_State;
   procedure Perform (Item : in out Session; What : Grammar_VM.Card_Command; Index : Natural);

   procedure Choose_Inline (Item : in out Session; Row : Positive);

   Idle_Delay : constant := 500;
   procedure Build (Item : in out Session);
   procedure Close (Item : in out Session);
   procedure Before_Event (Item : in out Session; Event : Pomarine.Events.Event);
   procedure Released (Item : in out Session; Event : Pomarine.Events.Event);
   procedure Update_Cursor (Item : in out Session);
   procedure Close_Inline (Item : in out Session);
   procedure Entry_Ended (Item : in out Session; Accepted : Boolean);
   procedure Close_Entry (Item : in out Session);
   --  Put away the field that a rule's correction is typed in.
   procedure Update (Item : in out Session; Now : Pomarine.Events.Milliseconds);
   function Until_Update (Item : Session; Now : Pomarine.Events.Milliseconds) return Integer;
   procedure Reset (Item : in out Session);
   procedure Recheck (Item : in out Session);
   --  Check every document again, as after a change of the project's rules; the cards stay open.

   --  For tests: the cards' and the menu's commands, on the shown diagnostic that marks Text.

   function Marking (Item : Session; Marked : String) return Natural;
   --  How many shown diagnostics mark exactly Marked.

   function Made_By_Rule (Item : Session; Marked : String) return Natural;
   --  How many of those a rule of the project made.

   function First_Suggestion (Item : Session; Marked : String) return String;
   --  The first fix offered at the first of them; empty if none.

   function Rule_Count (Item : Session) return Natural;
   --  How many rules the open project has.

   procedure Show (Item : in out Session);
   --  Open the list of cards, as its button does.

   function First_Card_Made_By_Rule (Item : Session) return Boolean;
   --  Whether the first card of the list is of a diagnostic a rule made.

   procedure Expand (Item : in out Session; Marked : String);
   --  Open the first card of a diagnostic marking Marked.

   procedure Begin_Rule (Item : in out Session; Marked : String);
   --  Press the button that makes a rule of it, and stop at the field.

   procedure Ignore (Item : in out Session; Marked : String);
   procedure Correct (Item : in out Session; Marked, To : String);
   procedure Remove_Rule (Item : in out Session; Marked : String);

end View.Grammar;
