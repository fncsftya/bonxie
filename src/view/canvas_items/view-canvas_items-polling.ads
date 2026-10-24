--  What is done in the background, looked at once a frame: pictures taken, words found, speech heard.
private package View.Canvas_Items.Polling is

   procedure Poll_Dictation (Item : in out Session);
   --  Show how dictating stands, and put in a note what has been heard.

   procedure Poll_Captures (Item : in out Session);
   --  Take the pictures that have been taken, and say what failed.

end View.Canvas_Items.Polling;
