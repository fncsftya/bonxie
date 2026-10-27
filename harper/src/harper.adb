with Ada.Unchecked_Deallocation;
with Interfaces.C;
with System;

package body Harper is

   package C renames Interfaces.C;
   use type C.unsigned;
   use type C.size_t;

   type C_Edit is record
      First              : C.unsigned;
      Last               : C.unsigned;
      Replacement_Length : C.unsigned;
      Replacement        : C.char_array (0 .. Max_Replacement - 1);
   end record
   with Convention => C;
   type C_Edits is array (1 .. Max_Suggestions) of C_Edit with Convention => C;

   type C_Lint is record
      First                 : C.unsigned;
      Last                  : C.unsigned;
      Kind                  : C.unsigned;
      Priority              : C.unsigned;
      Message_Length        : C.unsigned;
      Message_Truncated     : C.unsigned;
      Message               : C.char_array (0 .. Max_Message - 1);
      Suggestion_Count      : C.unsigned;
      Suggestions_Truncated : C.unsigned;
      Suggestions           : C_Edits;
   end record
   with Convention => C;
   type C_Lints is array (1 .. Max_Lints) of C_Lint with Convention => C;

   type C_Result is record
      Count     : C.unsigned;
      Truncated : C.unsigned;
      Lints     : C_Lints;
   end record
   with Convention => C;

   function Check
     (Text : System.Address; Length : C.unsigned; Language : C.unsigned; Format : C.unsigned; Value : System.Address)
      return C.unsigned
   with Import, Convention => C, External_Name => "bonxie_harper_check";

   function Words (Text : C.char_array; Length : C.unsigned) return String
   with Pre => Length <= C.unsigned (Text'Length);

   function Words (Text : C.char_array; Length : C.unsigned) return String is
   begin
      if Length = 0 then
         return "";
      end if;
      return C.To_Ada (Text (0 .. C.size_t (Length) - 1), Trim_Nul => False);
   end Words;

   procedure Perform (Text : String; Language : Dialect; Format : Text_Format; Value : in out Check_Result) is
      Raw    : aliased C_Result;
      Status : C.unsigned;
   begin
      pragma Assert (C.unsigned'Size = 32);
      pragma Assert (C_Edit'Size = (12 + Max_Replacement) * 8);
      pragma Assert (C_Lint'Size = (32 + Max_Message + Max_Suggestions * (12 + Max_Replacement)) * 8);
      pragma Assert (C_Result'Size = 64 + Max_Lints * C_Lint'Size);
      Status :=
        Check
          (Text'Address,
           C.unsigned (Text'Length),
           C.unsigned (Dialect'Pos (Language)),
           C.unsigned (Text_Format'Pos (Format)),
           Raw'Address);
      if Status > C.unsigned (Check_Status'Pos (Check_Status'Last)) then
         Value.Status := Internal_Error;
         return;
      end if;
      Value.Status := Check_Status'Val (Status);
      if Value.Status /= Success then
         return;
      end if;
      pragma Assert (Raw.Count <= Max_Lints);
      Value.Count := Natural (Raw.Count);
      Value.Truncated := Raw.Truncated /= 0;
      for Index in 1 .. Value.Count loop
         declare
            Source : C_Lint renames Raw.Lints (Index);
            Target : Diagnostic renames Value.Lints (Index);
         begin
            pragma Assert (Source.First <= Source.Last and then Source.Last <= C.unsigned (Text'Length));
            Target.Location := (Natural (Source.First), Natural (Source.Last));
            Target.Kind := Lint_Kind'Val (Source.Kind);
            Target.Priority := Natural (Source.Priority);
            Target.Message := Messages.To_Bounded_String (Words (Source.Message, Source.Message_Length));
            Target.Message_Truncated := Source.Message_Truncated /= 0;
            Target.Suggestion_Count := Natural (Source.Suggestion_Count);
            Target.Suggestions_Truncated := Source.Suggestions_Truncated /= 0;
            for Each in 1 .. Target.Suggestion_Count loop
               declare
                  Edit : C_Edit renames Source.Suggestions (Each);
               begin
                  pragma Assert (Edit.First <= Edit.Last and then Edit.Last <= C.unsigned (Text'Length));
                  Target.Suggestions (Each) :=
                    (Location => (Natural (Edit.First), Natural (Edit.Last)),
                     Text     => Replacements.To_Bounded_String (Words (Edit.Replacement, Edit.Replacement_Length)));
               end;
            end loop;
         end;
      end loop;
   end Perform;

   task body Worker is
      Text_Buffer       : String (1 .. Max_Text);
      Length            : Natural range 0 .. Max_Text;
      Selected_Language : Dialect;
      Selected_Format   : Text_Format;
      Result            : Check_Result;
   begin
      loop
         select
            accept Begin_Check (Text : String; Revision : Request_Id; Language : Dialect; Format : Text_Format) do
               Length := Text'Length;
               Text_Buffer (1 .. Length) := Text;
               Selected_Language := Language;
               Selected_Format := Format;
               Result := (Revision => Revision, others => <>);
            end Begin_Check;
         or
            terminate;
         end select;

         begin
            Perform (Text_Buffer (1 .. Length), Selected_Language, Selected_Format, Result);
         exception
            when others =>
               Result := (Revision => Result.Revision, Status => Internal_Error, others => <>);
         end;

         select
            accept Take_Result (Value : out Check_Result) do
               Value := Result;
            end Take_Result;
         or
            terminate;
         end select;
      end loop;
   end Worker;

   procedure Submit
     (Item     : in out Checker;
      Text     : String;
      Revision : Request_Id;
      Accepted : out Boolean;
      Language : Dialect := British;
      Format   : Text_Format := Plain_Text) is
   begin
      if Item.Engine = null then
         --  A task that is only now made is not yet at its accept: it is given a moment.
         Item.Engine := new Worker;
         select
            Item.Engine.Begin_Check (Text, Revision, Language, Format);
            Accepted := True;
         or
            delay 0.1;
            Accepted := False;
         end select;
      else
         select
            Item.Engine.Begin_Check (Text, Revision, Language, Format);
            Accepted := True;
         else
            Accepted := False;
         end select;
      end if;
   end Submit;

   procedure Poll (Item : in out Checker; Value : out Check_Result; Ready : out Boolean) is
   begin
      if Item.Engine = null then
         Value := (others => <>);
         Ready := False;
         return;
      end if;
      select
         Item.Engine.Take_Result (Value);
         Ready := True;
      else
         Value := (others => <>);
         Ready := False;
      end select;
   end Poll;

   overriding
   procedure Finalize (Item : in out Checker) is
      procedure Free is new Ada.Unchecked_Deallocation (Worker, Worker_Ref);
   begin
      if Item.Engine /= null then
         abort Item.Engine.all;
         Free (Item.Engine);
      end if;
   end Finalize;

end Harper;
