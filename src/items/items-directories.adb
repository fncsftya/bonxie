with Repository.Directory;
with Repository.Item;

package body Items.Directories is

   procedure Load_Order
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Id_List) is
   begin
      Repository.Item.Load_Order (Store, Project, Result);
   end Load_Order;

   function Create_Directory
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Id is
     (Repository.Directory.Insert (Store, Project, Title));

   procedure Load_Directories
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Directory_List) is
   begin
      Repository.Directory.Load (Store, Project, Result);
   end Load_Directories;

   function Position_Of (Store : Projects.Store; Key : Id) return Natural is
     (Repository.Item.Position_Of (Store, Key));

   procedure Set_Position
     (Store : in out Projects.Store; Key : Id; Position : Positive) is
   begin
      Repository.Item.Set_Position (Store, Key, Position);
   end Set_Position;

   procedure Set_Directory_Position
     (Store : in out Projects.Store; Key : Id; Position : Positive) is
   begin
      Repository.Directory.Set_Position (Store, Key, Position);
   end Set_Directory_Position;

   function Directory_Count
     (Store : Projects.Store; Project : Projects.Id) return Natural is
     (Repository.Directory.Count (Store, Project));

   procedure Rename_Directory
     (Store : in out Projects.Store; Key : Id; Title : String) is
   begin
      Repository.Directory.Rename (Store, Key, Title);
   end Rename_Directory;

   procedure Set_Parent
     (Store : in out Projects.Store; Key, Parent : Id) is
   begin
      Repository.Directory.Set_Parent (Store, Key, Parent);
   end Set_Parent;

   procedure Delete_Directory (Store : in out Projects.Store; Key : Id) is
   begin
      Repository.Item.Free_Directory (Store, Key);
      Repository.Directory.Delete (Store, Key);
   end Delete_Directory;

   function Directory_Of (Store : Projects.Store; Key : Id) return Id is
     (Repository.Item.Directory_Of (Store, Key));

   procedure Set_Directory
     (Store : in out Projects.Store; Key : Id; Into : Id) is
   begin
      Repository.Item.Set_Directory (Store, Key, Into);
   end Set_Directory;

end Items.Directories;
