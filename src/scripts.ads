with Texts.Documents;
private with Ada.Strings.Unbounded;

--  A script, as bonxie edits it: its text, which views show and edit,
--  the file it is kept in, and whether it is as saved there.
package Scripts is

   type Script is limited private;

   procedure Load
     (Item : in out Script; Content : String; Kept_In : String := "");
   --  Make Content the text, a paragraph to each line, kept in file
   --  Kept_In ("" for none yet), and as saved.

   function Document
     (Item : aliased in out Script) return Texts.Documents.Document_Access;
   --  Its text, for views to show: they must not outlive Item.

   function Text (Item : Script) return String;
   --  All of it, a line to each paragraph.

   function File_Name (Item : Script) return String;

   function Is_Modified (Item : Script) return Boolean;
   --  Whether the text has changed since it was loaded or saved: not if
   --  it was changed and changed back by undoing.

   function Title (Item : Script) return String;
   --  For a window: the file's name, and whether it has been edited.

   procedure Save (Item : in out Script)
     with Pre => File_Name (Item) /= "";
   --  Write the text to the file, a line to each paragraph.

private

   type Script is limited record
      Doc       : aliased Texts.Documents.Document;
      File_Name : Ada.Strings.Unbounded.Unbounded_String;
      Saved     : Natural := 0;  --  the text's state when saved
   end record;

end Scripts;
