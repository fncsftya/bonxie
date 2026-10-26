with Ada_Sqlite3;
with Long_Texts;
with Repository.Database; use Repository.Database;

package body Repository.Rule is

   use type Ada_Sqlite3.Result_Code;
   use type Projects.Rules.Actions;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS grammar_rules ("
     & "id INTEGER PRIMARY KEY, "
     & "project_id INTEGER NOT NULL "
     & "REFERENCES projects (id) ON DELETE CASCADE, "
     & "action INTEGER NOT NULL, "
     & "kind INTEGER NOT NULL, "
     & "pattern TEXT NOT NULL, "
     & "replacement TEXT NOT NULL)";

   Index : constant String :=
     "CREATE INDEX IF NOT EXISTS grammar_rules_project ON grammar_rules (project_id, id)";

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Ada_Sqlite3.Execute (DB (Store).all, Index);
   end Prepare;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Projects.Rules.Rule_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT id, action, kind, pattern, replacement FROM grammar_rules "
           & "WHERE project_id = :project ORDER BY id");
   begin
      Result.Clear;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         declare
            Action : constant Integer := Ada_Sqlite3.Column_Int (Query, 1);
            Kind   : constant Integer := Ada_Sqlite3.Column_Int (Query, 2);
         begin
            --  A row this version cannot read is left alone, not guessed at.
            if Action in 0 .. Projects.Rules.Actions'Pos (Projects.Rules.Actions'Last)
              and then Kind in Projects.Rules.Kind_Code
            then
               Result.Append
                 ((Key         => Projects.Rules.Rule_Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
                   Action      => Projects.Rules.Actions'Val (Action),
                   Kind        => Kind,
                   Pattern     => Long_Texts.To_Text (Ada_Sqlite3.Column_Text (Query, 3)),
                   Replacement => Long_Texts.To_Text (Ada_Sqlite3.Column_Text (Query, 4))));
            end if;
         end;
      end loop;
   end Load;

   function Insert
     (Store       : in out Projects.Store;
      Project     : Projects.Id;
      Action      : Projects.Rules.Actions;
      Kind        : Projects.Rules.Kind_Code;
      Pattern     : String;
      Replacement : String) return Projects.Rules.Rule_Id
   is
      --  A correction is for a text of any kind, so its kind is not part of what makes it the same rule.
      Same_Kind : constant Projects.Rules.Kind_Code := (if Action = Projects.Rules.Correct then 0 else Kind);
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "DELETE FROM grammar_rules WHERE project_id = :project AND action = :action "
           & "AND kind = :kind AND pattern = :pattern");
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO grammar_rules (project_id, action, kind, pattern, replacement) "
           & "VALUES (:project, :action, :kind, :pattern, :replacement)");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Remove, ":action", Projects.Rules.Actions'Pos (Action));
      Ada_Sqlite3.Bind_Int (Remove, ":kind", Same_Kind);
      Ada_Sqlite3.Bind_Text (Remove, ":pattern", Pattern);
      Ada_Sqlite3.Step (Remove);
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":action", Projects.Rules.Actions'Pos (Action));
      Ada_Sqlite3.Bind_Int (Query, ":kind", Same_Kind);
      Ada_Sqlite3.Bind_Text (Query, ":pattern", Pattern);
      Ada_Sqlite3.Bind_Text (Query, ":replacement", Replacement);
      Ada_Sqlite3.Step (Query);
      return Projects.Rules.Rule_Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Insert;

   procedure Delete (Store : in out Projects.Store; Key : Projects.Rules.Rule_Id) is
   begin
      Delete_Where (Store, "grammar_rules", "id", Long_Integer (Key));
   end Delete;

end Repository.Rule;
