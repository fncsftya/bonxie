--  Reading what a language model replied with: it is told to answer with a
--  JSON object and nothing else, and may add words about it, or put it in
--  Markdown fences.
package Model_Replies is

   procedure Find_Object (Reply : String; First, Last : out Natural)
     with Post => (First = 0) = (Last = 0)
                  and then (if Last /= 0 then First in Reply'Range and then Last in First .. Reply'Last
                                              and then Reply (First) = '{' and then Reply (Last) = '}');
   --  Where the first JSON object in Reply is: from its opening brace to its
   --  closing one, the quotes in it respected. Both 0 if there is none, or it
   --  is not closed.

   procedure Find_Object (Reply : String; From : Positive; First, Last : out Natural)
     with Pre  => From >= Reply'First,
          Post => (First = 0) = (Last = 0)
                  and then (if Last /= 0 then First in From .. Last and then Last <= Reply'Last
                                              and then Reply (First) = '{' and then Reply (Last) = '}');
   --  As above, the first from From on: to go on to the next object when one
   --  could not be used (a model that thinks aloud may have braces in what it
   --  says before its reply).

   function Cut (Text : String; Limit : Natural) return String
     with Post => Cut'Result'Length <= Limit and then Cut'Result'Length <= Text'Length;
   --  Text, or its first Limit bytes, less any part of a UTF-8 character that
   --  would be left at the end.

   function Tidy (Text : String; Limit : Natural) return String
     with Post => Tidy'Result'Length <= Limit;
   --  Text with each run of spaces and control characters (line breaks, tabs)
   --  made a space, none at the ends, and cut to Limit bytes as Cut does.

end Model_Replies;
