with Ada_Sqlite3;
with Repository.Database; use Repository.Database;

package body Repository.Link is

   use type Ada_Sqlite3.Result_Code;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS item_links ("
     & "id INTEGER PRIMARY KEY, "
     & "from_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "to_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "from_side INTEGER NOT NULL, to_side INTEGER NOT NULL, "
     & "stroke INTEGER NOT NULL DEFAULT 0, "
     & "ending INTEGER NOT NULL DEFAULT 0, "
     & "color INTEGER NOT NULL DEFAULT 1, "
     & "CHECK (from_id <> to_id))";

   function Side_Of (Code : Integer) return Items.Links.Sides is
     (if Code in 0 .. Items.Links.Sides'Pos (Items.Links.Sides'Last)
      then Items.Links.Sides'Val (Code) else Items.Links.Top);

   function Stroke_Of (Code : Integer) return Items.Links.Strokes is
     (if Code in 0 .. Items.Links.Strokes'Pos (Items.Links.Strokes'Last)
      then Items.Links.Strokes'Val (Code) else Items.Links.Solid);

   function Ending_Of (Code : Integer) return Items.Links.Endings is
     (if Code in 0 .. Items.Links.Endings'Pos (Items.Links.Endings'Last)
      then Items.Links.Endings'Val (Code) else Items.Links.Plain);

   function Color_Of (Code : Integer) return Items.Links.Link_Colors is
     (if Code in Items.Links.Link_Colors then Code else 1);

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Add_Column (Store, "item_links", "stroke", "INTEGER NOT NULL DEFAULT 0");
      Add_Column (Store, "item_links", "ending", "INTEGER NOT NULL DEFAULT 0");
      Add_Column (Store, "item_links", "color", "INTEGER NOT NULL DEFAULT 1");
   end Prepare;

   function Exists
     (Store : Projects.Store; A, B : Items.Id) return Boolean
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM item_links "
           & "WHERE (from_id = :a AND to_id = :b) "
           & "OR (from_id = :b AND to_id = :a)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":a", Long_Integer (A));
      Ada_Sqlite3.Bind_Int64 (Query, ":b", Long_Integer (B));
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) > 0;
   end Exists;

   procedure Insert (Store : in out Projects.Store; Made : Items.Links.Link) is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_links "
           & "(from_id, to_id, from_side, to_side, stroke, ending, color) "
           & "VALUES (:from, :to, :from_side, :to_side, "
           & ":stroke, :ending, :color)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":from", Long_Integer (Made.From));
      Ada_Sqlite3.Bind_Int64 (Query, ":to", Long_Integer (Made.To));
      Ada_Sqlite3.Bind_Int (Query, ":from_side", Items.Links.Sides'Pos (Made.From_Side));
      Ada_Sqlite3.Bind_Int (Query, ":to_side", Items.Links.Sides'Pos (Made.To_Side));
      Ada_Sqlite3.Bind_Int (Query, ":stroke", Items.Links.Strokes'Pos (Made.Stroke));
      Ada_Sqlite3.Bind_Int (Query, ":ending", Items.Links.Endings'Pos (Made.Ending));
      Ada_Sqlite3.Bind_Int (Query, ":color", Made.Color);
      Ada_Sqlite3.Step (Query);
   end Insert;

   procedure Delete (Store : in out Projects.Store; Key : Items.Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM item_links WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete;

   procedure Set_Style
     (Store  : in out Projects.Store;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE item_links SET stroke = :stroke, ending = :ending, "
           & "color = :color WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":stroke", Items.Links.Strokes'Pos (Stroke));
      Ada_Sqlite3.Bind_Int (Update, ":ending", Items.Links.Endings'Pos (Ending));
      Ada_Sqlite3.Bind_Int (Update, ":color", Color);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Style;

   procedure Move
     (Store : in out Projects.Store;
      Key   : Items.Id;
      To    : Items.Id;
      Side  : Items.Links.Sides;
      Moved : out Boolean)
   is
      Joined : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM item_links a, item_links b "
           & "WHERE a.id = :id AND b.id <> a.id AND "
           & "((b.from_id = a.from_id AND b.to_id = :to) "
           & "OR (b.to_id = a.from_id AND b.from_id = :to))");
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE item_links SET to_id = :to, to_side = :side "
           & "WHERE id = :id AND from_id <> :to");
   begin
      Ada_Sqlite3.Bind_Int64 (Joined, ":id", Long_Integer (Key));
      Ada_Sqlite3.Bind_Int64 (Joined, ":to", Long_Integer (To));
      Moved := Ada_Sqlite3.Step (Joined) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Joined, 0) = 0;
      if Moved then
         Ada_Sqlite3.Bind_Int64 (Update, ":to", Long_Integer (To));
         Ada_Sqlite3.Bind_Int (Update, ":side", Items.Links.Sides'Pos (Side));
         Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
         Ada_Sqlite3.Step (Update);
      end if;
   end Move;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Links.Link_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT l.from_id, l.to_id, l.from_side, l.to_side, "
           & "l.id, l.stroke, l.ending, l.color "
           & "FROM item_links l JOIN items i ON i.id = l.from_id "
           & "WHERE i.project_id = :project ORDER BY l.id");
   begin
      Result.Clear;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Append
           ((From      => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            To        => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 1)),
            From_Side => Side_Of (Ada_Sqlite3.Column_Int (Query, 2)),
            To_Side   => Side_Of (Ada_Sqlite3.Column_Int (Query, 3)),
            Key       => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 4)),
            Stroke    => Stroke_Of (Ada_Sqlite3.Column_Int (Query, 5)),
            Ending    => Ending_Of (Ada_Sqlite3.Column_Int (Query, 6)),
            Color     => Color_Of (Ada_Sqlite3.Column_Int (Query, 7))));
      end loop;
   end Load;

end Repository.Link;
