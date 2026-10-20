--  Opening a source: a link downloaded or its page captured, or a file chosen, as a picture, a document or text.
private package Viewer.Canvas_Items.Opening is

   procedure Start_Capture (Item : in out Session; Which : Items.Slot);
   --  Begin to take the picture of the page the source's text links to, or
   --  show the file its text is the path of.

   procedure Pick_File (Item : in out Session; Which : Items.Slot);

   procedure Poll_Download (Item : in out Session);
   --  Take the file that has been fetched, or say that it was not.

   procedure Poll_Pick (Item : in out Session);
   --  Take the file that has been chosen, in the dialog.

end Viewer.Canvas_Items.Opening;
