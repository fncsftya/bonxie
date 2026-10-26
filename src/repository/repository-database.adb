package body Repository.Database is

   use type Ada_Sqlite3.Result_Code;

   function Has_Column
     (Store : Projects.Store; Table, Name : String) return Boolean
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM pragma_table_info('" & Table & "') "
           & "WHERE name = '" & Name & "'");
   begin
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) > 0;
   end Has_Column;

   procedure Add_Column
     (Store : Projects.Store; Table, Name, Definition : String) is
   begin
      if not Has_Column (Store, Table, Name) then
         Ada_Sqlite3.Execute
           (DB (Store).all,
            "ALTER TABLE " & Table & " ADD COLUMN " & Name & " "
            & Definition);
      end if;
   end Add_Column;

   procedure Set_Int
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : Integer)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE " & Table & " SET " & Column & " = :value WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":value", Value);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Key);
      Ada_Sqlite3.Step (Update);
   end Set_Int;

   procedure Set_Int64
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : Long_Integer)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE " & Table & " SET " & Column & " = :value WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":value", Value);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Key);
      Ada_Sqlite3.Step (Update);
   end Set_Int64;

   procedure Set_Double
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : Float)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE " & Table & " SET " & Column & " = :value WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Double (Update, ":value", Value);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Key);
      Ada_Sqlite3.Step (Update);
   end Set_Double;

   procedure Set_Text
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE " & Table & " SET " & Column & " = :value WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":value", Value);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Key);
      Ada_Sqlite3.Step (Update);
   end Set_Text;

   procedure Delete_Where (Store : Projects.Store; Table, Column : String; Key : Long_Integer) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM " & Table & " WHERE " & Column & " = :key");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":key", Key);
      Ada_Sqlite3.Step (Remove);
   end Delete_Where;

end Repository.Database;
