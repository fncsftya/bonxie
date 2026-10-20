--  Where the sections and pages are put, and the caret brought into view.
private package Viewer.Writing.Layout is

   procedure Fit_Pages (Item : in out Session)
     with Pre => Screen (Item) = Project and then Item.Toolbar.Mode in Write | Publish;
   --  Size the pages to their text and the window, once it is laid out,
   --  and bring the caret into view.

end Viewer.Writing.Layout;
