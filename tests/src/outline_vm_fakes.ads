with Outline_VM;
with Projects;
with Projects.Sections;

--  The outline's sections as a test of the view-model has them: kept in memory, with a count of what was
--  written, so that a test can say a rule did not write.

package Outline_VM_Fakes is

   type Kept is limited new Outline_VM.Library with record
      Title  : Projects.Titles.Text := Projects.Titles.To_Text ("Great skua");
      Words  : Projects.Titles.Text := Projects.Titles.To_Text ("A bird");
      Table  : aliased Projects.Sections.Section_List;
      Links  : aliased Projects.Sections.Link_List;
      Next   : Projects.Sections.Section_Id := 1;
      Writes : Natural := 0;
      --  How many times anything was kept.
   end record;

   procedure Put (Self : in out Kept; Title : String; Notes : String := "");
   --  A section, last.

   procedure Link (Self : in out Kept; Item : Long_Integer; Section : Positive);
   --  The item is of the section in the Sectionth place.

   function Titles (Self : Kept) return String;
   --  The titles in order, apart by a comma.

   overriding
   procedure Project_Words
     (Self : in out Kept; Owner : Projects.Id; Found : out Boolean; Title, Description : out Projects.Titles.Text);
   overriding
   procedure Rename_Project (Self : in out Kept; Owner : Projects.Id; Title : String);
   overriding
   procedure Keep_Description (Self : in out Kept; Owner : Projects.Id; Stored : String);
   overriding
   procedure Load
     (Self  : in out Kept;
      Owner : Projects.Id;
      Order : out Projects.Sections.Section_List;
      Links : out Projects.Sections.Link_List);
   overriding
   procedure Load_Links (Self : in out Kept; Owner : Projects.Id; Links : out Projects.Sections.Link_List);
   overriding
   function Add (Self : in out Kept; Owner : Projects.Id; Title : String) return Projects.Sections.Section_Id;
   overriding
   procedure Rename (Self : in out Kept; Key : Projects.Sections.Section_Id; Title : String);
   overriding
   procedure Delete (Self : in out Kept; Key : Projects.Sections.Section_Id);
   overriding
   procedure Set_Order (Self : in out Kept; Owner : Projects.Id; Order : Projects.Sections.Key_Array);
   overriding
   function Stored_Notes (Self : in out Kept; Key : Projects.Sections.Section_Id) return String;
   overriding
   procedure Keep_Notes (Self : in out Kept; Key : Projects.Sections.Section_Id; Stored : String);
   overriding
   procedure Set_Colour
     (Self : in out Kept; Key : Projects.Sections.Section_Id; Colour : Projects.Sections.Colour_Value);

end Outline_VM_Fakes;
