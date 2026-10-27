with Ada.Strings.Unbounded;

package body Outline_VM_Fakes is

   package Sections renames Projects.Sections;

   use type Sections.Section_Id;

   function Place (Self : Kept; Key : Sections.Section_Id) return Natural is
   begin
      for Each in 1 .. Self.Table.Count loop
         if Self.Table (Each).Key = Key then
            return Each;
         end if;
      end loop;
      return 0;
   end Place;

   procedure Put (Self : in out Kept; Title : String; Notes : String := "") is
   begin
      Self.Table.Append
        ((Key    => Self.Next,
          Title  => Sections.Title_Texts.To_Text (Title),
          Notes  => Sections.Note_Texts.To_Text (Notes),
          others => <>));
      Self.Next := Self.Next + 1;
   end Put;

   procedure Link (Self : in out Kept; Item : Long_Integer; Section : Positive) is
   begin
      Self.Links.Append ((Item => Item, Section => Self.Table (Section).Key));
   end Link;

   function Titles (Self : Kept) return String is
      Said : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Each in 1 .. Self.Table.Count loop
         if Each > 1 then
            Ada.Strings.Unbounded.Append (Said, ",");
         end if;
         Ada.Strings.Unbounded.Append (Said, Sections.Title_Texts.To_String (Self.Table (Each).Title));
      end loop;
      return Ada.Strings.Unbounded.To_String (Said);
   end Titles;

   overriding
   procedure Project_Words
     (Self : in out Kept; Owner : Projects.Id; Found : out Boolean; Title, Description : out Projects.Titles.Text)
   is
      pragma Unreferenced (Owner);
   begin
      Found := True;
      Title := Self.Title;
      Description := Self.Words;
   end Project_Words;

   overriding
   procedure Rename_Project (Self : in out Kept; Owner : Projects.Id; Title : String) is
      pragma Unreferenced (Owner);
   begin
      Self.Title := Projects.Titles.To_Text (Title);
      Self.Writes := Self.Writes + 1;
   end Rename_Project;

   overriding
   procedure Keep_Description (Self : in out Kept; Owner : Projects.Id; Stored : String) is
      pragma Unreferenced (Owner);
   begin
      Self.Words := Projects.Titles.To_Text (Stored);
      Self.Writes := Self.Writes + 1;
   end Keep_Description;

   overriding
   procedure Load
     (Self : in out Kept; Owner : Projects.Id; Order : out Sections.Section_List; Links : out Sections.Link_List)
   is
      pragma Unreferenced (Owner);
   begin
      Order := Self.Table;
      Links := Self.Links;
   end Load;

   overriding
   procedure Load_Links (Self : in out Kept; Owner : Projects.Id; Links : out Sections.Link_List) is
      pragma Unreferenced (Owner);
   begin
      Links := Self.Links;
   end Load_Links;

   overriding
   function Add (Self : in out Kept; Owner : Projects.Id; Title : String) return Sections.Section_Id is
      pragma Unreferenced (Owner);
   begin
      Put (Self, Title);
      Self.Writes := Self.Writes + 1;
      return Self.Next - 1;
   end Add;

   overriding
   procedure Rename (Self : in out Kept; Key : Sections.Section_Id; Title : String) is
   begin
      declare
         Section : Sections.Section renames Self.Table (Place (Self, Key));
      begin
         Section.Title := Sections.Title_Texts.To_Text (Title);
      end;
      Self.Writes := Self.Writes + 1;
   end Rename;

   overriding
   procedure Delete (Self : in out Kept; Key : Sections.Section_Id) is
      Kept_Links : Sections.Link_List;
   begin
      Self.Table.Delete (Place (Self, Key));
      for Each in 1 .. Self.Links.Count loop
         if Self.Links (Each).Section /= Key then
            Kept_Links.Append (Self.Links (Each));
         end if;
      end loop;
      Self.Links := Kept_Links;
      Self.Writes := Self.Writes + 1;
   end Delete;

   overriding
   procedure Set_Order (Self : in out Kept; Owner : Projects.Id; Order : Sections.Key_Array) is
      pragma Unreferenced (Owner);
      Old : constant Sections.Section_List := Self.Table;
   begin
      for Each in Order'Range loop
         for Before in 1 .. Old.Count loop
            if Old (Before).Key = Order (Each) then
               Self.Table (Each - Order'First + 1) := Old (Before);
            end if;
         end loop;
      end loop;
      Self.Writes := Self.Writes + 1;
   end Set_Order;

   overriding
   function Stored_Notes (Self : in out Kept; Key : Sections.Section_Id) return String
   is ("<" & Sections.Note_Texts.To_String (Self.Table (Place (Self, Key)).Notes) & ">");

   overriding
   procedure Keep_Notes (Self : in out Kept; Key : Sections.Section_Id; Stored : String) is
   begin
      declare
         Section : Sections.Section renames Self.Table (Place (Self, Key));
      begin
         Section.Notes := Sections.Note_Texts.To_Text (Stored);
      end;
      Self.Writes := Self.Writes + 1;
   end Keep_Notes;

   overriding
   procedure Set_Colour (Self : in out Kept; Key : Sections.Section_Id; Colour : Sections.Colour_Value) is
   begin
      declare
         Section : Sections.Section renames Self.Table (Place (Self, Key));
      begin
         Section.Colour := Colour;
      end;
      Self.Writes := Self.Writes + 1;
   end Set_Colour;

end Outline_VM_Fakes;
