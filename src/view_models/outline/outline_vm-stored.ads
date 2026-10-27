--  The outline's sections as the database keeps them.

package Outline_VM.Stored is

   type Sections_Kept is limited new Library with private;

   procedure Open (Self : in out Sections_Kept; Store : not null access Projects.Store);
   --  The sections in Store, which must be there as long as this is.

   overriding
   procedure Project_Words
     (Self              : in out Sections_Kept;
      Owner             : Projects.Id;
      Found             : out Boolean;
      Name, Description : out Projects.Titles.Text);

   overriding
   procedure Rename_Project (Self : in out Sections_Kept; Owner : Projects.Id; Name : String);

   overriding
   procedure Keep_Description (Self : in out Sections_Kept; Owner : Projects.Id; Marked : String);

   overriding
   procedure Load
     (Self  : in out Sections_Kept;
      Owner : Projects.Id;
      Order : out Sections.Section_List;
      Links : out Sections.Link_List);

   overriding
   procedure Load_Links (Self : in out Sections_Kept; Owner : Projects.Id; Links : out Sections.Link_List);

   overriding
   function Add (Self : in out Sections_Kept; Owner : Projects.Id; Name : String) return Sections.Section_Id;

   overriding
   procedure Rename (Self : in out Sections_Kept; Key : Sections.Section_Id; Name : String);

   overriding
   procedure Delete (Self : in out Sections_Kept; Key : Sections.Section_Id);

   overriding
   procedure Set_Order (Self : in out Sections_Kept; Owner : Projects.Id; Order : Sections.Key_Array);

   overriding
   function Stored_Notes (Self : in out Sections_Kept; Key : Sections.Section_Id) return String;

   overriding
   procedure Keep_Notes (Self : in out Sections_Kept; Key : Sections.Section_Id; Marked : String);

   overriding
   procedure Set_Colour (Self : in out Sections_Kept; Key : Sections.Section_Id; Colour : Sections.Colour_Value);

private

   type Store_Access is access all Projects.Store;

   type Sections_Kept is limited new Library with record
      Store : Store_Access;
   end record;

end Outline_VM.Stored;
