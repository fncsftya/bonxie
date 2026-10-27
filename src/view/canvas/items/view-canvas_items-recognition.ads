--  Finding the words of a source's picture, and showing a page of its document.

private package View.Canvas_Items.Recognition is

   procedure Start_Recognition (Item : in out Session; Which : Items.Slot);
   --  Begin to find the words in the source's picture, in the background,
   --  at the full size it was taken: they are what its window lets be
   --  selected.

   procedure Keep_Recognition (Item : in out Session; Which : Items.Slot);
   --  Take the words that have been found: write them to the database,
   --  and give them to the window.

   procedure Recognize_Kept (Item : in out Session; Which : Items.Slot);
   --  Of a source with a picture: show the words kept for it, or, if
   --  there are none (it was made before they were kept, or the program
   --  stopped before they were found), find them.

   procedure Name_From_Page (Item : in out Session; Which : Items.Slot; Heading : String);
   --  Give a source still called Untitled_Source the title of its page,
   --  or of its document.

   procedure Show_Page (Item : in out Session; Which : Items.Slot; Page : Positive; Heading : String := "");
   --  Draw the page of the window's source's document, as its picture,
   --  and find the words in it.

   procedure Turn_Page (Item : in out Session; Which : Items.Slot; By : Integer);
   --  Show the page of the source's document By pages on, or back, if
   --  there is one.

end View.Canvas_Items.Recognition;
