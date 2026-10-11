--  Tests of documents (Texts.Documents) and their layouts
--  (Typeset.Layouts) without drawing: text, ids, kinds, the history, the
--  log of changes, and lines kept right through edits. See Goldens.
package Document_Tests is

   procedure Loading;
   procedure Splicing;
   procedure Ids;
   procedure Kinds;
   procedure Steps;
   procedure Joining_Edits;
   procedure Units;
   procedure Against_A_String;
   procedure Mapping;
   procedure Lines_After_Edits;

end Document_Tests;
