--  Questions and texts shared by the outline's parts.
private package Viewer.Outlines.Support is

   function In_Outline (Item : Session) return Boolean;
   --  Whether the outline is the view in use, and not under a dialog.

   function Cut (Content : String; Most : Positive) return String;
   --  Content, or its first Most bytes, less any part of a character.

   function Trimmed (Content : String) return String;
   --  Without the spaces at either end.

   procedure Load_Sections (Item : in out Session; Owner : Projects.Id);
   --  Read the sections and their links again. A section shows its notes
   --  if it did, or if it has some now.

end Viewer.Outlines.Support;
