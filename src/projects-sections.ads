with Ada.Strings.Bounded;

--  The sections of a project's outline: their titles, in the order they
--  are to be read in, each kept in a table of its own.
package Projects.Sections is

   Max_Sections   : constant := 64;
   Max_Title : constant := 128;
   --  Bytes, of what is read back: longer is cut.

   package Title_Texts is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max_Title);

   type Section_Id is new Long_Integer;

   type Section is record
      Key   : Section_Id := 0;
      Title : Title_Texts.Bounded_String := Title_Texts.Null_Bounded_String;
   end record;

   type Section_Array is array (Positive range <>) of Section;
   type Key_Array is array (Positive range <>) of Section_Id;

   type Section_List is record
      Count : Natural range 0 .. Max_Sections := 0;
      Items : Section_Array (1 .. Max_Sections);
   end record;
   --  Items (1 .. Count) are in order.

   procedure Load
     (Item    : Store;
      Owner : Id;
      Result  : out Section_List)
     with Pre => Is_Open (Item);
   --  The project's sections, in order; at most Max_Sections.

   function Add
     (Item    : in out Store;
      Owner : Id;
      Title   : String) return Section_Id
     with Pre => Is_Open (Item);
   --  Put a section after the rest.

   procedure Rename
     (Item : in out Store; Key : Section_Id; Title : String)
     with Pre => Is_Open (Item);

   procedure Set_Order
     (Item    : in out Store;
      Owner : Id;
      Order   : Key_Array)
     with Pre => Is_Open (Item);
   --  Put the sections with these keys in this order, first to last. All
   --  or none are moved.

   procedure Delete (Item : in out Store; Key : Section_Id)
     with Pre => Is_Open (Item);

end Projects.Sections;
