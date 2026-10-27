with Growing;
with Long_Texts;

--  The rules a project keeps for its spelling and grammar checks, each in a
--  row of a table of its own: a flagged text to leave alone, or to correct
--  to the text the writer chose.

package Projects.Rules is

   type Rule_Id is new Long_Integer;

   type Actions is (Ignore, Correct);
   --  Ignore drops a diagnostic of a kind (Kind) on exactly Pattern.
   --  Correct offers Replacement for exactly Pattern, as a diagnostic of its own.

   subtype Kind_Code is Natural range 0 .. 20;
   --  A position of Harper.Lint_Kind, so that a rule outlives a change of the enumeration's names.

   type Rule is record
      Key         : Rule_Id := 0;
      Action      : Actions := Ignore;
      Kind        : Kind_Code := 0;
      Pattern     : Long_Texts.Text := Long_Texts.Null_Text;
      Replacement : Long_Texts.Text := Long_Texts.Null_Text;
   end record;

   package Rule_Lists is new Growing (Rule);
   subtype Rule_List is Rule_Lists.List;
   --  The earliest made first.

   procedure Load (Item : Store; Owner : Id; Result : out Rule_List)
   with Pre => Is_Open (Item);

   function Add
     (Item : in out Store; Owner : Id; Action : Actions; Kind : Kind_Code; Pattern : String; Replacement : String := "")
      return Rule_Id
   with Pre => Is_Open (Item) and then Pattern'Length > 0 and then (Action = Correct or else Replacement'Length = 0);
   --  A rule for a pattern and an action that the project has already is changed rather than repeated.

   procedure Remove (Item : in out Store; Key : Rule_Id)
   with Pre => Is_Open (Item);

end Projects.Rules;
