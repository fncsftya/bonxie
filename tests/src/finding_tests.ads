--  Tests of finding sources for a text: what the model is asked and how its
--  replies are read (no model is run), the pages and the scoring of them, and
--  the button, toast and list that show the work. See Goldens.
package Finding_Tests is

   procedure Reading_Queries;
   procedure Reading_Evaluations;
   --  What the model replies, as it is read: what is wrong with it, and what
   --  is passed over.

   procedure Reading_Banners;
   --  What the model says covers a page, and which button closes it.
   procedure Choosing_Links;
   --  Which addresses are of PDFs, and which pages are the front of one.

   procedure Button;
   --  The Find Sources button of a note on the canvas and of a page of the
   --  writing view: off with the AI off or the text blank, on otherwise; with
   --  no model chosen, a click says so in the toast.
   procedure Review;
   --  The toast and the list of what was found: shown, the sources added,
   --  one or all, linked from the note, or put away.
   procedure Documents;
   --  A PDF that was found: shown in the preview as pages, and added as a document
   --  (drawn a page at a time, as one that was fetched is), not as a picture.
   procedure Messages;
   --  What the toast says when nothing was found, and when it is not looked
   --  at.

   procedure Cancelling;
   --  Stopping the work half way, by the toast's button: it says so, and when it
   --  has stopped, the toast and the pictures are gone and work can be begun again.

end Finding_Tests;
