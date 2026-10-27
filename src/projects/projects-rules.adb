with Repository.Rule;

package body Projects.Rules is

   procedure Load (Item : Store; Owner : Id; Result : out Rule_List) is
   begin
      Repository.Rule.Load (Item, Owner, Result);
   end Load;

   function Add
     (Item : in out Store; Owner : Id; Action : Actions; Kind : Kind_Code; Pattern : String; Replacement : String := "")
      return Rule_Id
   is (Repository.Rule.Insert (Item, Owner, Action, Kind, Pattern, Replacement));

   procedure Remove (Item : in out Store; Key : Rule_Id) is
   begin
      Repository.Rule.Delete (Item, Key);
   end Remove;

end Projects.Rules;
