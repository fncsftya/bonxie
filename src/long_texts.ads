with Ada.Strings.Unbounded;

--  Text a person types or chooses (a title, a note, a path), kept whole: it
--  has no length it is cut at.
package Long_Texts is

   subtype Text is Ada.Strings.Unbounded.Unbounded_String;

   Null_Text : Text renames Ada.Strings.Unbounded.Null_Unbounded_String;

   function To_Text (Source : String) return Text renames Ada.Strings.Unbounded.To_Unbounded_String;

   function To_String (Source : Text) return String renames Ada.Strings.Unbounded.To_String;

   function Length (Source : Text) return Natural renames Ada.Strings.Unbounded.Length;

   function "=" (Left, Right : Text) return Boolean renames Ada.Strings.Unbounded."=";

end Long_Texts;
