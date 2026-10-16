with Repository.Section;

package body Projects.Sections is

   procedure Load
     (Item    : Store;
      Owner : Id;
      Result  : out Section_List) is
   begin
      Repository.Section.Load (Item, Owner, Result);
   end Load;

   function Add
     (Item    : in out Store;
      Owner : Id;
      Title   : String) return Section_Id is
     (Repository.Section.Insert (Item, Owner, Title));

   procedure Rename
     (Item : in out Store; Key : Section_Id; Title : String) is
   begin
      Repository.Section.Rename (Item, Key, Title);
   end Rename;

   procedure Set_Notes
     (Item : in out Store; Key : Section_Id; Notes : String) is
   begin
      Repository.Section.Set_Notes (Item, Key, Notes);
   end Set_Notes;

   procedure Set_Order
     (Item    : in out Store;
      Owner : Id;
      Order   : Key_Array) is
   begin
      Repository.Section.Set_Order (Item, Owner, Order);
   end Set_Order;

   procedure Link
     (Item : in out Store; Key : Section_Id; Linked : Long_Integer) is
   begin
      Repository.Section.Link (Item, Key, Linked);
   end Link;

   procedure Unlink (Item : in out Store; Linked : Long_Integer) is
   begin
      Repository.Section.Unlink (Item, Linked);
   end Unlink;

   procedure Load_Links
     (Item   : Store;
      Owner  : Id;
      Result : out Link_List) is
   begin
      Repository.Section.Load_Links (Item, Owner, Result);
   end Load_Links;

   procedure Delete (Item : in out Store; Key : Section_Id) is
   begin
      Repository.Section.Delete (Item, Key);
   end Delete;

end Projects.Sections;
