with Projects.Rules;

--  The table of the rules of the projects' spelling and grammar checks, one row to a rule.
package Repository.Rule is

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none.

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Projects.Rules.Rule_List)
     with Pre => Projects.Is_Open (Store);

   function Insert
     (Store       : in out Projects.Store;
      Project     : Projects.Id;
      Action      : Projects.Rules.Actions;
      Kind        : Projects.Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Projects.Rules.Rule_Id
     with Pre => Projects.Is_Open (Store);
   --  Replaces the rule of the same action, pattern and (to ignore) kind.

   procedure Delete (Store : in out Projects.Store; Key : Projects.Rules.Rule_Id)
     with Pre => Projects.Is_Open (Store);

end Repository.Rule;
