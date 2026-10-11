with Ada.Finalization;
with System;

package CoreText.Strings is

   type Text is limited private;
   --  Some text held as a CoreFoundation string, so that lines of it can
   --  be cut out by UTF-16 range without scanning the UTF-8 from its
   --  start. Make one for a paragraph, and keep it while the paragraph's
   --  text is unchanged.

   procedure Set (Item : in out Text; Value : String)
     with Post => Is_Set (Item) and then Length (Item) = UTF16_Length (Value);
   --  Replace Item's text with the UTF-8 Value.

   procedure Clear (Item : in out Text)
     with Post => not Is_Set (Item);

   function Is_Set (Item : Text) return Boolean;

   function Length (Item : Text) return Natural;
   --  In UTF-16 units; 0 if not set.

   procedure Cluster
     (Item : Text; Unit : Natural; First, Stop : out Natural)
     with Pre  => Is_Set (Item) and then Unit < Length (Item),
          Post => First <= Unit and then Unit < Stop
                  and then Stop <= Length (Item);
   --  The UTF-16 range [First, Stop) of the character Unit is part of,
   --  as a reader sees one: a letter and its accents, an emoji and its
   --  modifiers, a surrogate pair. Move and delete by these.

   --  Words, as CoreFoundation finds them in the text's language: not
   --  the spaces and punctuation between them.

   function Previous_Word_Start (Item : Text; Unit : Natural) return Natural
     with Pre  => Is_Set (Item) and then Unit <= Length (Item),
          Post => Previous_Word_Start'Result <= Unit
                  and then (Unit = 0
                            or else Previous_Word_Start'Result < Unit);
   --  Where the last word that starts before Unit starts; 0 if none does.

   function Next_Word_Stop (Item : Text; Unit : Natural) return Natural
     with Pre  => Is_Set (Item) and then Unit <= Length (Item),
          Post => Next_Word_Stop'Result >= Unit
                  and then Next_Word_Stop'Result <= Length (Item)
                  and then (Unit = Length (Item)
                            or else Next_Word_Stop'Result > Unit);
   --  Where the first word that ends after Unit ends; the end of the text
   --  if none does.

   procedure Word_At
     (Item : Text; Unit : Natural; First, Stop : out Natural)
     with Pre  => Is_Set (Item) and then Unit <= Length (Item),
          Post => First <= Unit and then Unit <= Stop
                  and then Stop <= Length (Item);
   --  The UTF-16 range [First, Stop) of the word Unit is in, or that ends
   --  at Unit; First = Stop = Unit if there is none.

   function Handle (Item : Text) return System.Address
     with Pre => Is_Set (Item);
   --  The CFStringRef, for CoreText's own packages.

private

   type Text is new Ada.Finalization.Limited_Controlled with record
      Ref   : System.Address := System.Null_Address;
      Units : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Text);

end CoreText.Strings;
