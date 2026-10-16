with Projects.Sections;

--  What is asked of a language model to make the sections of a project's
--  outline, and how what it replies is read: it is told to reply with
--  nothing but a JSON object (see Schema), and the reply is parsed here, as
--  it is not a model's way to be exact; a reply that does not parse is the
--  caller's to ask for again.
package Outline_Generation is

   Max_Tries : constant := 3;
   --  How many times the model is asked before the work is given up.

   Tokens : constant := 8192;
   --  The most a model may make, thoughts and reply: the model is to think
   --  first, and a reply of Max_Sections titles is a few thousand bytes.

   System_Prompt : constant String;
   --  What the model is told it is for, with Schema in it.

   Schema : constant String;
   --  The JSON Schema of the reply: an object with a list of sections, each
   --  with a title, in the order they are to be read in.

   function Prompt
     (Title, Description : String;
      Existing           : Projects.Sections.Section_List) return String
     with Post => Prompt'Result'Length > 0;
   --  What starts the work: the project's title and description, and the
   --  sections it has already, which the outline is to keep.

   procedure Parse
     (Reply  : String;
      Result : out Projects.Sections.Section_List;
      Valid  : out Boolean)
     with Post => (if Valid then Result.Count > 0 else Result.Count = 0);
   --  The sections the model replied with, as the reply's JSON gives them:
   --  titles trimmed, cut to Max_Title and, beyond Max_Sections, left out;
   --  those that are blank or a title already given are left out too, and
   --  the keys are 0. Valid is False, and Result empty, if there is no
   --  JSON object in Reply that fits Schema, or no title in it. The reply
   --  may have words about the object, or fences round it: they are
   --  passed over.

private

   LF : constant Character := Character'Val (10);

   Schema : constant String :=
     "{" & LF
     & "  ""type"": ""object""," & LF
     & "  ""properties"": {" & LF
     & "    ""sections"": {" & LF
     & "      ""type"": ""array""," & LF
     & "      ""minItems"": 1," & LF
     & "      ""maxItems"": 64," & LF
     & "      ""items"": {" & LF
     & "        ""type"": ""object""," & LF
     & "        ""properties"": {" & LF
     & "          ""title"": { ""type"": ""string"", ""minLength"": 1, ""maxLength"": 128 }" & LF
     & "        }," & LF
     & "        ""required"": [""title""]," & LF
     & "        ""additionalProperties"": false" & LF
     & "      }" & LF
     & "    }" & LF
     & "  }," & LF
     & "  ""required"": [""sections""]," & LF
     & "  ""additionalProperties"": false" & LF
     & "}";

   System_Prompt : constant String :=
     "You are an editor who plans writing projects. You are given the title and description of a "
     & "project, and the sections its outline has so far, if any. Plan the full outline: the "
     & "sections the finished piece is to be divided into, in the order they are to be read in, "
     & "from the first to the last." & LF & LF
     & "Guidelines:" & LF
     & "- Give each section a short title of a few words, as a heading, without a number, a "
     & "colon or a trailing full stop." & LF
     & "- Cover the whole of what the description sets out, with a sensible beginning and end, "
     & "and no overlap between sections." & LF
     & "- Keep every existing section, with its title as it is written, and put it where it "
     & "belongs in the order; add the sections that are missing around them." & LF
     & "- Give as many sections as the project needs, usually between 5 and 15, and never more "
     & "than 64." & LF
     & "- Write in the language of the title and description." & LF & LF
     & "Think the outline through first. Then reply with a single JSON object that conforms to "
     & "this JSON Schema, and with nothing else: no words before or after it, and no Markdown "
     & "code fences." & LF & LF
     & Schema & LF & LF
     & "For example:" & LF
     & "{""sections"": [{""title"": ""Introduction""}, {""title"": ""Background""}, "
     & "{""title"": ""Conclusion""}]}";

end Outline_Generation;
