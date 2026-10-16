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

   Palette_Size : constant := 12;
   --  How many colours there are to tell sections apart by.

   subtype Colour_Index is Natural range 0 .. Palette_Size - 1;

   type Section is record
      Key   : Section_Id := 0;
      Title : Title_Texts.Bounded_String := Title_Texts.Null_Bounded_String;
      Colour : Colour_Index := 0;
      --  Given when the section is made: the one of the project's that is
      --  used least, so that no two are alike until there are more than
      --  Palette_Size, and kept, whatever the order and the others.
   end record;

   type Section_Array is array (Positive range <>) of Section;
   type Key_Array is array (Positive range <>) of Section_Id;

   type Section_List is record
      Count : Natural range 0 .. Max_Sections := 0;
      Items : Section_Array (1 .. Max_Sections);
   end record;
   --  Items (1 .. Count) are in order.

   Max_Links : constant := 16;
   --  The most items a project has (see Items.Capacity), each in at most
   --  one section.

   type Membership is record
      Item    : Long_Integer := 0;
      --  The key of an item: a note on the canvas, a document of the
      --  writing view.
      Section : Section_Id := 0;
   end record;
   --  An item is of a section, which is to be read for. A section has any
   --  number of items.

   type Link_Array is array (Positive range <>) of Membership;

   type Link_List is record
      Count : Natural range 0 .. Max_Links := 0;
      Items : Link_Array (1 .. Max_Links);
   end record;
   --  Items (1 .. Count): the items of the project that are of a section.

   procedure Load_Links
     (Item   : Store;
      Owner  : Id;
      Result : out Link_List)
     with Pre => Is_Open (Item);

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

   procedure Link
     (Item : in out Store; Key : Section_Id; Linked : Long_Integer)
     with Pre => Is_Open (Item) and then Linked /= 0;
   --  Make the item (by its key) one of the section's; it is not of the
   --  one it was.

   procedure Unlink (Item : in out Store; Linked : Long_Integer)
     with Pre => Is_Open (Item);
   --  The item is of no section.

   procedure Delete (Item : in out Store; Key : Section_Id)
     with Pre => Is_Open (Item);

end Projects.Sections;
