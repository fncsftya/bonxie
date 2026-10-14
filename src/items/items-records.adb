with Ada.Directories;
with Items.Sources;
with Repository.Item;

package body Items.Records is

   function Create
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String;
      Where   : Frame;
      Text    : String := "";
      Kind    : Kinds := Note) return Id is
   begin
      pragma Assert (Count (Store, Project) < Capacity);
      return Repository.Item.Insert (Store, Project, Title, Where, Text, Kind);
   end Create;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Info_List) is
   begin
      Repository.Item.Load (Store, Project, Result);
   end Load;

   function Count
     (Store : Projects.Store; Project : Projects.Id) return Natural is
     (Repository.Item.Count (Store, Project));

   function Content (Store : Projects.Store; Key : Id) return String is
     (Repository.Item.Content (Store, Key));

   procedure Set_Title
     (Store : in out Projects.Store; Key : Id; Title : String) is
   begin
      Repository.Item.Set_Title (Store, Key, Title);
   end Set_Title;

   procedure Set_Content
     (Store : in out Projects.Store; Key : Id; Text : String) is
   begin
      Repository.Item.Set_Content (Store, Key, Text);
   end Set_Content;

   procedure Set_Frame
     (Store : in out Projects.Store; Key : Id; Where : Frame) is
   begin
      Repository.Item.Set_Frame (Store, Key, Where);
   end Set_Frame;

   procedure Set_State
     (Store : in out Projects.Store; Key : Id; State : States) is
   begin
      Repository.Item.Set_State (Store, Key, State);
   end Set_State;

   procedure Set_Scroll
     (Store : in out Projects.Store; Key : Id; Scroll, Across : Float) is
   begin
      Repository.Item.Set_Scroll (Store, Key, Scroll, Across);
   end Set_Scroll;

   procedure Delete (Store : in out Projects.Store; Key : Id) is
      use type Projects.Id;
      Project : constant Projects.Id := Repository.Item.Owner (Store, Key);
   begin
      Repository.Item.Delete (Store, Key);
      if Project /= 0 then
         declare
            Picture : constant String :=
              Sources.Image_File (Store, Project, Key);
         begin
            if Ada.Directories.Exists (Picture) then
               Ada.Directories.Delete_File (Picture);
            end if;
         end;
      end if;
   end Delete;

end Items.Records;
