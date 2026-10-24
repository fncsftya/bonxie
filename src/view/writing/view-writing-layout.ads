--  Where the sections and pages are put, and the caret brought into view.
private package View.Writing.Layout is

   procedure Fit_Pages (Item : in out Session)
     with Pre => Screen (Item) = Project and then View_Mode (Item) in Write | Publish;
   --  Size the pages to their text and the window, once it is laid out,
   --  and bring the caret into view.

end View.Writing.Layout;
