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

end Repository.Database;
