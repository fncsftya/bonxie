with Ada.Finalization;
with Ada.Strings.Bounded;

--  UTF-8 spelling and grammar checking. Each Checker owns one Ada task, made by its first Submit.
--  Submit and Poll only copy bounded data; every call into Rust is made
--  by that task, including dictionary initialization and cleanup.

package Harper is

   Max_Text        : constant := 65_536;
   Max_Lints       : constant := 128;
   Max_Suggestions : constant := 4;
   Max_Message     : constant := 512;
   Max_Replacement : constant := 256;

   type Dialect is (American, Canadian, Australian, British, Indian);
   type Text_Format is (Plain_Text, Markdown);
   type Request_Id is mod 2**64;
   type Check_Status is (Success, Invalid_UTF8, Invalid_Argument, Internal_Error);

   type Lint_Kind is
     (Agreement,
      Boundary_Error,
      Capitalization,
      Eggcorn,
      Enhancement,
      Formatting,
      Grammar,
      Malapropism,
      Miscellaneous,
      Nonstandard,
      Punctuation,
      Readability,
      Redundancy,
      Regionalism,
      Repetition,
      Spelling,
      Style,
      Typo,
      Usage,
      Word_Choice,
      Word_Order);

   subtype Byte_Offset is Natural range 0 .. Max_Text;
   type Span is record
      First : Byte_Offset := 0;
      Last  : Byte_Offset := 0;
   end record
   with Dynamic_Predicate => Span.First <= Span.Last;
   --  Zero based UTF-8 byte offsets [First, Last) into the original text.
   --  First = Last denotes an insertion. These are not Ada String indices.

   package Messages is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Message);
   package Replacements is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Replacement);

   type Suggestion is record
      Location : Span;
      Text     : Replacements.Bounded_String;
   end record;
   --  Replace Location with Text; empty Text removes Location. InsertAfter
   --  is normalized to an empty span at the end of Harper's lint span.

   type Suggestion_Array is array (Positive range 1 .. Max_Suggestions) of Suggestion;
   type Diagnostic is record
      Location              : Span;
      Kind                  : Lint_Kind := Miscellaneous;
      Priority              : Natural range 0 .. 255 := 0;
      Message               : Messages.Bounded_String;
      Message_Truncated     : Boolean := False;
      Suggestion_Count      : Natural range 0 .. Max_Suggestions := 0;
      Suggestions_Truncated : Boolean := False;
      Suggestions           : Suggestion_Array;
      Custom                : Boolean := False;
   end record;
   --  Lower priority numbers are more important. Messages contain Harper's
   --  Markdown. Oversized replacements are omitted rather than shortened.
   --  Custom is never set by Harper: the application sets it on a diagnostic
   --  that one of its own rules made or changed.

   type Diagnostic_Array is array (Positive range 1 .. Max_Lints) of Diagnostic;
   type Check_Result is record
      Revision  : Request_Id := 0;
      Status    : Check_Status := Success;
      Count     : Natural range 0 .. Max_Lints := 0;
      Truncated : Boolean := False;
      Lints     : Diagnostic_Array;
   end record;

   Max_Word     : constant := 64;
   Max_Synonyms : constant := 32;

   package Word_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Word);
   type Word_Array is array (Positive range 1 .. Max_Synonyms) of Word_Strings.Bounded_String;
   type Synonym_List is record
      Status    : Check_Status := Success;
      Count     : Natural range 0 .. Max_Synonyms := 0;
      Truncated : Boolean := False;
      Words     : Word_Array;
   end record;
   --  The first Count of Words, the most used first.

   function Synonyms (Word : String) return Synonym_List
   with Pre => Word'Length in 1 .. Max_Word;
   --  Other words of the thesaurus's for Word, in the capitals of Word (Hello gives Greeting, HELLO
   --  GREETING); for a phrase (words and single spaces), phrases and words, from the phrase itself or, if
   --  the thesaurus has not it, from what is left of it without the words in front that only strengthen
   --  (very easy gives what easy does). None, with Success, if it has not the word. The Rust is called in a
   --  task of its own, made by the first call (which waits for the thesaurus to be read) and ended with the
   --  program, so call it from one task at a time.

   type Checker is limited private;

   procedure Submit
     (Item     : in out Checker;
      Text     : String;
      Revision : Request_Id;
      Accepted : out Boolean;
      Language : Dialect := British;
      Format   : Text_Format := Plain_Text)
   with Pre => Text'Length <= Max_Text;
   --  Nonblocking conditional rendezvous. Accepted means Text was copied.
   --  Otherwise retry later: the task may be starting, checking, or holding
   --  an uncollected result. There is one request at a time per Checker.
   --  Revision is echoed so callers can discard results for stale text.

   procedure Poll (Item : in out Checker; Value : out Check_Result; Ready : out Boolean);
   --  Nonblocking: Value is meaningful only when Ready. A collected result
   --  frees the Checker for another request. No callbacks run on the task.
   --  At scope exit, a running check finishes and the task terminates even
   --  if its result has not been collected.

private

   task type Worker with Storage_Size => 16 * 1024 * 1024 is
      entry Begin_Check (Text : String; Revision : Request_Id; Language : Dialect; Format : Text_Format);
      entry Take_Result (Value : out Check_Result);
   end Worker;
   type Worker_Ref is access Worker;

   task type Lookup with Storage_Size => 16 * 1024 * 1024 is
      entry Find (Word : String; Value : out Synonym_List);
   end Lookup;

   type Checker is limited new Ada.Finalization.Limited_Controlled with record
      Engine : Worker_Ref;
      --  Null until the first Submit: a Checker that is never used has no task.
   end record;

   overriding
   procedure Finalize (Item : in out Checker);
   --  A check that is running finishes, and the task goes (it is not waited for).

end Harper;
