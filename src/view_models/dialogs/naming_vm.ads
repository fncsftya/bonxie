with Growing;
with Items;

--  What of the writing view is being renamed: a folder, a document or a source of the sidebar, by the field over
--  its row, and the titles of pages that are being edited in place. Which row is which, and where the field goes,
--  is the view's. It names no widget, so the tests run it without a window.
--
--  A folder and a document are renamed in the same field, and one at a time; a source in a field of its own.

package Naming_VM is

   type Model is limited private;

   function Directory (Self : Model) return Natural;
   --  The folder being renamed, as the view numbers its folders, 0 if none.

   function Document (Self : Model) return Natural;
   --  The slot of the document being renamed in the sidebar, 0 if none.

   function Source (Self : Model) return Natural;
   --  The slot of the source being renamed, 0 if none.

   function Is_Renaming_Name (Self : Model) return Boolean
   is (Directory (Self) /= 0 or else Document (Self) /= 0);
   --  The field of a folder's or a document's name is in use.

   procedure Begin_Directory (Self : in out Model; Which : Positive)
   with Post => Directory (Self) = Which;

   procedure Begin_Document (Self : in out Model; Which : Items.Slot)
   with Post => Document (Self) = Which;

   procedure Begin_Source (Self : in out Model; Which : Items.Slot)
   with Post => Source (Self) = Which;

   procedure End_Directory (Self : in out Model)
   with Post => Directory (Self) = 0;

   procedure End_Document (Self : in out Model)
   with Post => Document (Self) = 0;

   procedure End_Source (Self : in out Model)
   with Post => Source (Self) = 0;

   function Is_Titling (Self : Model; Rank : Positive) return Boolean;
   --  The title of the page of this rank is being edited in place.

   procedure Begin_Title (Self : in out Model; Rank : Positive)
   with Post => Is_Titling (Self, Rank);

   procedure End_Title (Self : in out Model; Rank : Positive)
   with Post => not Is_Titling (Self, Rank);

   procedure Reset (Self : in out Model)
   with Post => Directory (Self) = 0 and then Document (Self) = 0 and then Source (Self) = 0;
   --  Nothing is being renamed, of the sidebar: the project is left, or another is opened. Titles being edited
   --  are the pages' own and are ended with End_Title.

private

   package Flags is new Growing (Boolean);

   type Model is limited record
      Folder : Natural := 0;
      Doc    : Natural := 0;
      Origin : Natural := 0;
      Titles : Flags.List;
   end record;

end Naming_VM;
