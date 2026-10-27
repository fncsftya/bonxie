--  Opening a source: a link downloaded or its page captured, or a file chosen, as a picture, a document or text.

private package View.Canvas_Items.Opening is

   procedure Start_Capture (Item : in out Session; Which : Items.Slot);
   --  Begin to take the picture of the page the source's text links to, or
   --  show the file its text is the path of.

   procedure Open_Fetched (Item : in out Session; Which : Items.Slot; Ending : String);
   --  The file of the source's document (a PDF, of Ending "pdf") is in its place
   --  already, fetched by another: count its pages and draw the first, as when
   --  a link to one has been fetched.

   procedure Pick_File (Item : in out Session; Which : Items.Slot);

   procedure Poll_Download (Item : in out Session);
   --  Take the file that has been fetched, or say that it was not.

   procedure Poll_Pick (Item : in out Session);
   --  Take the file that has been chosen, in the dialog.

end View.Canvas_Items.Opening;
