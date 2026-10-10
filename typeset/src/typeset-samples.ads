--  Text to try things on.
package Typeset.Samples is

   function Document
     (Paragraphs : Positive; Seed : Natural := 1) return String;
   --  A document of that many paragraphs, a line each, of varied length:
   --  mostly of a few sentences, some of one word and some of a few
   --  thousand. Made from pseudo-random words, with some in other scripts
   --  and an emoji now and then, so that fonts have to be substituted.
   --  The same Seed gives the same document.

end Typeset.Samples;
