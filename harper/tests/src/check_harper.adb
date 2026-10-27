with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;
with Harper;

procedure Check_Harper is
   use Harper;
   use type Ada.Real_Time.Time;

   Worker : Checker;
   Other  : Checker;
   Value  : Check_Result;
   Ready  : Boolean;

   procedure Start
     (Item     : in out Checker;
      Text     : String;
      Revision : Request_Id := 1;
      Language : Dialect := British;
      Format   : Text_Format := Plain_Text)
   is
      Accepted : Boolean;
      Deadline : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (60);
   begin
      loop
         Submit (Item, Text, Revision, Accepted, Language, Format);
         exit when Accepted;
         pragma Assert (Ada.Real_Time.Clock < Deadline, "submission timed out");
         delay 0.001;
      end loop;
   end Start;

   procedure Await (Item : in out Checker; Result : out Check_Result) is
      Ready    : Boolean;
      Deadline : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (60);
   begin
      loop
         Poll (Item, Result, Ready);
         exit when Ready;
         pragma Assert (Ada.Real_Time.Clock < Deadline, "check timed out");
         delay 0.001;
      end loop;
      pragma Assert (Result.Status = Success);
   end Await;

   function Has_Kind (Result : Check_Result; Kind : Lint_Kind) return Boolean
   is (for some Index in 1 .. Result.Count => Result.Lints (Index).Kind = Kind);

begin
   declare
      procedure Check_ABI
      with Import, Convention => C, External_Name => "check_harper_abi";
      task ABI_Check;
      task body ABI_Check is
      begin
         Check_ABI;
      end ABI_Check;
   begin
      null;
   end;

   Poll (Worker, Value, Ready);
   pragma Assert (not Ready);

   --  Empty input, arbitrary String lower bounds, task reuse, and revision echo.
   Start (Worker, "", 42);
   Await (Worker, Value);
   pragma Assert (Value.Revision = 42 and then Value.Count = 0);
   declare
      Text : constant String (10 .. 34) := "This is the the sentence.";
   begin
      Start (Worker, Text, 43);
   end;
   declare
      Accepted : Boolean;
   begin
      Submit (Worker, "Must not replace the pending request.", 44, Accepted);
      pragma Assert (not Accepted);
   end;
   Await (Worker, Value);
   pragma Assert (Value.Revision = 43 and then Has_Kind (Value, Repetition));

   --  UTF-8 byte spans must account for a four-byte character before the error.
   declare
      Text  : constant String := Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("🙂 This is a speling mistake.");
      First : constant Natural := Ada.Strings.Fixed.Index (Text, "speling") - 1;
      Found : Boolean := False;
   begin
      Start (Worker, Text);
      Start (Other, "This is an test.");
      Await (Worker, Value);
      for Index in 1 .. Value.Count loop
         declare
            Lint : Diagnostic renames Value.Lints (Index);
         begin
            pragma Assert (Lint.Location.Last <= Text'Length);
            if Lint.Kind = Spelling and then Lint.Location = (First, First + 7) then
               Found := True;
               pragma Assert (Lint.Suggestion_Count > 0);
               pragma Assert (Messages.Length (Lint.Message) > 0);
               pragma
                 Assert
                   (for some Each in 1 .. Lint.Suggestion_Count =>
                      Replacements.To_String (Lint.Suggestions (Each).Text) = "spelling");
            end if;
         end;
      end loop;
      pragma Assert (Found, "missing spelling diagnostic at UTF-8 byte offset");
      Await (Other, Value);
      pragma Assert (Value.Count > 0, "missing grammar diagnostic");
   end;

   Start (Worker, "```" & ASCII.LF & "speling" & ASCII.LF & "```", Format => Markdown);
   Await (Worker, Value);
   pragma Assert (not Has_Kind (Value, Spelling), "Markdown code was checked");

   Start (Worker, "The colour is blue.", Language => British);
   Await (Worker, Value);
   pragma Assert (not Has_Kind (Value, Spelling));
   Start (Worker, "The colour is blue.", Language => American);
   Await (Worker, Value);
   pragma Assert (Has_Kind (Value, Spelling));

   Start (Worker, [1 => Character'Val (255)]);
   loop
      Poll (Worker, Value, Ready);
      exit when Ready;
      delay 0.001;
   end loop;
   pragma Assert (Value.Status = Invalid_UTF8 and then Value.Count = 0);

   --  Capacity is reported explicitly, and a subsequent request still works.
   declare
      Text : String (1 .. 8 * (Max_Lints + 1));
   begin
      for Index in 0 .. Max_Lints loop
         Text (Index * 8 + 1 .. Index * 8 + 8) := "speling ";
      end loop;
      Start (Worker, Text);
      Await (Worker, Value);
      pragma Assert (Value.Truncated and then Value.Count = Max_Lints);
   end;
   Start (Worker, [1 .. Max_Text => ' ']);
   Await (Worker, Value);
   pragma Assert (not Has_Kind (Value, Spelling));
   pragma Assert (for all Index in 1 .. Value.Count => Value.Lints (Index).Location.Last <= Max_Text);

   --  A task with an uncollected result must not prevent scope exit.
   declare
      Temporary : Checker;
   begin
      Start (Temporary, "This is a speling mistake.");
   end;
   Ada.Text_IO.Put_Line ("Harper task and ABI checks passed.");
end Check_Harper;
