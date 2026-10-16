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

   procedure Set_Order
     (Item    : in out Store;
      Owner : Id;
      Order   : Key_Array) is
   begin
      Repository.Section.Set_Order (Item, Owner, Order);
   end Set_Order;

   procedure Delete (Item : in out Store; Key : Section_Id) is
   begin
      Repository.Section.Delete (Item, Key);
   end Delete;

end Projects.Sections;
