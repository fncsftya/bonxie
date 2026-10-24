with Items.Readers;
--  The windows of the sources here: made, pinned, opened, and their highlights kept.
private package View.Writing.Reader_Windows is

   package Readers renames Items.Readers;

   function Picture_Of (Item : Session; Which : Items.Slot) return String;
   --  The picture of a source, or the text file of one that is a text.

   procedure Make_Reader (Item : in out Session; Which : Items.Slot);
   --  Make the source's window here, closed.

   procedure Unpin (Item : in out Session; Reopen : Boolean);
   --  Let go of the pinned source: close it, or show it in a window.

   procedure Pin (Item : in out Session; Which : Items.Slot);
   --  Show the source in the pane, in place of any other.

   procedure Toggle_Source (Item : in out Session; Which : Items.Slot);
   --  A source's row was clicked: open its window, or close it.

   procedure Keep_Marks
     (Item  : in out Session;
      Which : Items.Slot;
      Shown : in out Readers.Reader;
      Sync  : in out Sync_State);
   --  Make the highlights of the source's window here and on the canvas
   --  the same, whichever was marked.

   procedure Keep_Title
     (Item : Session; Which : Items.Slot; Shown : in out Readers.Reader);
   --  Make the window's title that of the source.

end View.Writing.Reader_Windows;
