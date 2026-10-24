with Harper;
with Projects.Rules;

--  A project's own rules for its spelling and grammar checks, applied to what Harper found.
--  A text is matched exactly, with its case, and a correction only where it is a whole word.
package Grammar_Rules is

   function Kind_Code (Kind : Harper.Lint_Kind) return Projects.Rules.Kind_Code is
     (Harper.Lint_Kind'Pos (Kind));

   function Flagged (Text : String; Item : Harper.Diagnostic) return String
     with Pre => Text'First = 1,
          Post => Flagged'Result'Length <= Text'Length;
   --  The text the diagnostic marks; empty for an insertion or a span outside Text.

   procedure Apply
     (Rules  : Projects.Rules.Rule_List;
      Text   : String;
      Result : in out Harper.Check_Result)
     with Pre => Text'First = 1 and then Text'Length <= Harper.Max_Text,
          Post => Result.Count <= Harper.Max_Lints;
   --  Text is what was checked. Drop each diagnostic a rule ignores. Offer each correction first at
   --  every diagnostic on its text, and make a diagnostic of its own, marked Custom, wherever Harper
   --  found nothing there. The diagnostics stay in the order of their places.

end Grammar_Rules;
