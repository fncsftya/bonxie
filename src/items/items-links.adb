with Ada_Sqlite3;
with Items.Database; use Items.Database;

package body Items.Links is

   use type Ada_Sqlite3.Result_Code;

   function Side_Of (Code : Integer) return Sides is
     (if Code in 0 .. Sides'Pos (Sides'Last)
      then Sides'Val (Code) else Top);

   function Stroke_Of (Code : Integer) return Strokes is
     (if Code in 0 .. Strokes'Pos (Strokes'Last)
      then Strokes'Val (Code) else Solid);

   function Ending_Of (Code : Integer) return Endings is
     (if Code in 0 .. Endings'Pos (Endings'Last)
      then Endings'Val (Code) else Plain);

   function Color_Of (Code : Integer) return Link_Colors is
     (if Code in Link_Colors then Code else 1);

   function Is_Linked
     (Store : Projects.Store; A, B : Id) return Boolean
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
   end Is_Linked;

   procedure Add_Link
     (Store : in out Projects.Store; Made : Link; Added : out Boolean) is
   begin
      Added := not Is_Linked (Store, Made.From, Made.To);
      if Added then
         declare
            Insert : Ada_Sqlite3.Statement :=
              Ada_Sqlite3.Prepare
                (DB (Store).all,
                 "INSERT INTO item_links "
                 & "(from_id, to_id, from_side, to_side, "
                 & "stroke, ending, color) "
                 & "VALUES (:from, :to, :from_side, :to_side, "
                 & ":stroke, :ending, :color)");
         begin
            Ada_Sqlite3.Bind_Int64 (Insert, ":from", Long_Integer (Made.From));
            Ada_Sqlite3.Bind_Int64 (Insert, ":to", Long_Integer (Made.To));
            Ada_Sqlite3.Bind_Int
              (Insert, ":from_side", Sides'Pos (Made.From_Side));
            Ada_Sqlite3.Bind_Int
              (Insert, ":to_side", Sides'Pos (Made.To_Side));
            Ada_Sqlite3.Bind_Int
              (Insert, ":stroke", Strokes'Pos (Made.Stroke));
            Ada_Sqlite3.Bind_Int
              (Insert, ":ending", Endings'Pos (Made.Ending));
            Ada_Sqlite3.Bind_Int (Insert, ":color", Made.Color);
            Ada_Sqlite3.Step (Insert);
         end;
      end if;
   end Add_Link;

   procedure Delete_Link (Store : in out Projects.Store; Key : Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM item_links WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete_Link;

   procedure Set_Link_Style
     (Store  : in out Projects.Store;
      Key    : Id;
      Stroke : Strokes;
      Ending : Endings;
      Color  : Link_Colors)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE item_links SET stroke = :stroke, ending = :ending, "
           & "color = :color WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":stroke", Strokes'Pos (Stroke));
      Ada_Sqlite3.Bind_Int (Update, ":ending", Endings'Pos (Ending));
      Ada_Sqlite3.Bind_Int (Update, ":color", Color);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Link_Style;

   procedure Move_Link
     (Store : in out Projects.Store;
      Key   : Id;
      To    : Id;
      Side  : Sides;
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
         Ada_Sqlite3.Bind_Int (Update, ":side", Sides'Pos (Side));
         Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
         Ada_Sqlite3.Step (Update);
      end if;
   end Move_Link;

   procedure Load_Links
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Link_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT l.from_id, l.to_id, l.from_side, l.to_side, "
           & "l.id, l.stroke, l.ending, l.color "
           & "FROM item_links l JOIN items i ON i.id = l.from_id "
           & "WHERE i.project_id = :project ORDER BY l.id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Max_Links);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Count := Result.Count + 1;
         Result.Links (Result.Count) :=
           (From      => Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            To        => Id (Ada_Sqlite3.Column_Int64 (Query, 1)),
            From_Side => Side_Of (Ada_Sqlite3.Column_Int (Query, 2)),
            To_Side   => Side_Of (Ada_Sqlite3.Column_Int (Query, 3)),
            Key       => Id (Ada_Sqlite3.Column_Int64 (Query, 4)),
            Stroke    => Stroke_Of (Ada_Sqlite3.Column_Int (Query, 5)),
            Ending    => Ending_Of (Ada_Sqlite3.Column_Int (Query, 6)),
            Color     => Color_Of (Ada_Sqlite3.Column_Int (Query, 7)));
      end loop;
   end Load_Links;

end Items.Links;
