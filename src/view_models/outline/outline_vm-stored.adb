package body Outline_VM.Stored is

   procedure Open (Self : in out Sections_Kept; Store : not null access Projects.Store) is
   begin
      Self.Store := Store.all'Unrestricted_Access;
   end Open;

   overriding
   procedure Project_Words
     (Self              : in out Sections_Kept;
      Owner             : Projects.Id;
      Found             : out Boolean;
      Name, Description : out Projects.Titles.Text)
   is
      Result : Projects.Project;
   begin
      Projects.Find (Self.Store.all, Owner, Found, Result);
      if Found then
         Name := Result.Title;
         Description := Projects.Titles.To_Text (Projects.Stored_Description (Self.Store.all, Result.Key));
      end if;
   end Project_Words;

   overriding
   procedure Rename_Project (Self : in out Sections_Kept; Owner : Projects.Id; Name : String) is
   begin
      Projects.Rename (Self.Store.all, Owner, Name);
   end Rename_Project;

   overriding
   procedure Keep_Description (Self : in out Sections_Kept; Owner : Projects.Id; Marked : String) is
   begin
      Projects.Set_Description (Self.Store.all, Owner, Marked);
   end Keep_Description;

   overriding
   procedure Load
     (Self  : in out Sections_Kept;
      Owner : Projects.Id;
      Order : out Sections.Section_List;
      Links : out Sections.Link_List) is
   begin
      Sections.Load (Self.Store.all, Owner, Order);
      Sections.Load_Links (Self.Store.all, Owner, Links);
   end Load;

   overriding
   procedure Load_Links (Self : in out Sections_Kept; Owner : Projects.Id; Links : out Sections.Link_List) is
   begin
      Sections.Load_Links (Self.Store.all, Owner, Links);
   end Load_Links;

   overriding
   function Add (Self : in out Sections_Kept; Owner : Projects.Id; Name : String) return Sections.Section_Id
   is (Sections.Add (Self.Store.all, Owner, Name));

   overriding
   procedure Rename (Self : in out Sections_Kept; Key : Sections.Section_Id; Name : String) is
   begin
      Sections.Rename (Self.Store.all, Key, Name);
   end Rename;

   overriding
   procedure Delete (Self : in out Sections_Kept; Key : Sections.Section_Id) is
   begin
      Sections.Delete (Self.Store.all, Key);
   end Delete;

   overriding
   procedure Set_Order (Self : in out Sections_Kept; Owner : Projects.Id; Order : Sections.Key_Array) is
   begin
      Sections.Set_Order (Self.Store.all, Owner, Order);
   end Set_Order;

   overriding
   function Stored_Notes (Self : in out Sections_Kept; Key : Sections.Section_Id) return String
   is (Sections.Stored_Notes (Self.Store.all, Key));

   overriding
   procedure Keep_Notes (Self : in out Sections_Kept; Key : Sections.Section_Id; Marked : String) is
   begin
      Sections.Set_Stored_Notes (Self.Store.all, Key, Marked);
   end Keep_Notes;

   overriding
   procedure Set_Colour (Self : in out Sections_Kept; Key : Sections.Section_Id; Colour : Sections.Colour_Value) is
   begin
      Sections.Set_Colour (Self.Store.all, Key, Colour);
   end Set_Colour;

end Outline_VM.Stored;
