--  The publish view's headings, format and export.

with Publish_VM;

private package View.Writing.Publishing is

   procedure Refresh_Publish (Item : in out Session);
   --  Compose the preview with real paragraph kinds for optional headings.

   function Document_As (Item : Session; Which : Publish_VM.Formats) return String;
   --  The document of the publish view as a file of the format: its text, or the bytes of its file.

   procedure Synchronize (Item : in out Session);
   --  Apply the model's choices, menu geometry and preview changes.

   procedure Close_Format_Menu (Item : in out Session);

   procedure Menu_Pressed (Item : in out Session; X, Y : Float);
   --  Put the format menu away for a press outside it and the select.

end View.Writing.Publishing;
