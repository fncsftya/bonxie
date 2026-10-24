--  Questions and texts shared by the outline's parts.
private package View.Outlines.Support is

   function In_Outline (Item : Session) return Boolean;
   --  Whether the outline is the view in use, and not under a dialog.

   function Cut (Content : String; Most : Positive) return String;
   --  Content, or its first Most bytes, less any part of a character.

   function Trimmed (Content : String) return String;
   --  Without the spaces at either end.

   procedure Reserve (Item : in out Session);
   --  Have a block for each section of the view-model.

end View.Outlines.Support;
