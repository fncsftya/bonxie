with Growing;
with Long_Texts;

--  The sections of a project's outline: their titles, in the order they
--  are to be read in, each kept in a table of its own.
package Projects.Sections is

   package Title_Texts renames Long_Texts;
   package Note_Texts renames Long_Texts;

   type Section_Id is new Long_Integer;

   Palette_Size : constant := 12;
   --  How many colours there are to tell sections apart by.

   subtype Colour_Index is Natural range 0 .. Palette_Size - 1;

   subtype Colour_Value is Natural range 0 .. Palette_Size + 16#FFFFFF#;
   --  Old palette indices remain theme aware; values from Palette_Size onward
   --  store a person's exact RGB colour, packed as Palette_Size + RRGGBB.

   type Section is record
      Key   : Section_Id := 0;
      Title : Title_Texts.Text := Title_Texts.Null_Text;
      Notes : Note_Texts.Text := Note_Texts.Null_Text;
      --  What is to be said in the section, as the writer typed it.
      Open  : Boolean := False;
      --  Whether the notes are shown: not kept, as only the view's.
      Colour : Colour_Value := 0;
      --  Initially the least-used palette colour; afterward the exact colour
      --  the writer chose. Kept independently of the order and other sections.
   end record;

   type Key_Array is array (Positive range <>) of Section_Id;

   package Section_Lists is new Growing (Section);
   subtype Section_List is Section_Lists.List;
   --  In order.

   type Membership is record
      Item    : Long_Integer := 0;
      --  The key of an item: a note on the canvas, a document of the
      --  writing view.
      Section : Section_Id := 0;
   end record;
   --  An item is of a section, which is to be read for. A section has any
   --  number of items.

   package Link_Lists is new Growing (Membership);
   subtype Link_List is Link_Lists.List;
   --  The items of the project that are of a section.

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
   --  The project's sections, in order.

   function Add
     (Item    : in out Store;
      Owner : Id;
      Title   : String) return Section_Id
     with Pre => Is_Open (Item);
   --  Put a section after the rest.

   procedure Set_Colour (Item : in out Store; Key : Section_Id; Colour : Colour_Value)
     with Pre => Is_Open (Item) and then Key /= 0;

   procedure Rename
     (Item : in out Store; Key : Section_Id; Title : String)
     with Pre => Is_Open (Item);

   function Stored_Notes (Item : Store; Key : Section_Id) return String
     with Pre => Is_Open (Item);
   procedure Set_Stored_Notes (Item : in out Store; Key : Section_Id; Notes : String)
     with Pre => Is_Open (Item);

   procedure Set_Notes
     (Item : in out Store; Key : Section_Id; Notes : String)
     with Pre => Is_Open (Item);
   --  Keep the section's notes.

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
