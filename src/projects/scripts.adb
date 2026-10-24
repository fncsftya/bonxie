with Ada.Directories;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Files;

package body Scripts is

   use Ada.Strings.Unbounded;

   package Docs renames Texts.Documents;

   Edited : constant String :=
     Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
       (" " & Wide_Wide_Character'Val (16#2014#) & " Edited");
   --  After the name, an em dash: in UTF-8, as titles are.

   procedure Load
     (Item : in out Script; Content : String; Kept_In : String := "") is
   begin
      Docs.Load_Stored (Item.Doc, Content);
      Item.File_Name := To_Unbounded_String (Kept_In);
      Item.Saved := Docs.State (Item.Doc);
   end Load;

   function Document
     (Item : aliased in out Script) return Texts.Documents.Document_Access
   is (Item.Doc'Unchecked_Access);

   function Text (Item : Script) return String is (Docs.Whole (Item.Doc));

   function File_Name (Item : Script) return String is
     (To_String (Item.File_Name));

   function Is_Modified (Item : Script) return Boolean is
     (Docs.State (Item.Doc) /= Item.Saved);

   function Title (Item : Script) return String is
     ((if File_Name (Item) = "" then "Untitled"
       else Ada.Directories.Simple_Name (File_Name (Item)))
      & (if Is_Modified (Item) then Edited else ""));

   procedure Save (Item : in out Script) is
   begin
      Files.Write (File_Name (Item), Docs.Stored (Item.Doc));
      Item.Saved := Docs.State (Item.Doc);
   end Save;

end Scripts;
