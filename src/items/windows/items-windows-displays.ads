--  Showing what a window holds: its title, words, link, pager and zoom, by the kind it is.
private package Items.Windows.Displays is

   procedure Show_Fetch (Item : in out Window);
   --  Show the button to take the picture of a source's link, and leave
   --  room for it, while there is none and the link is shown.

   procedure Fit_Zoom (Item : in out Window);
   --  Show what the zoom leaves room for: compact, the bar is smaller and
   --  there is no status line, nor link in a source.

   procedure Show_Mode (Item : in out Window);
   --  Show what the source is now: its two buttons, its text or its
   --  picture, and the tools for a picture.

   procedure Show_Title (Item : in out Window);
   --  Take the title as edited, for the item and the bar in the dock.

   procedure Show_Words (Item : in out Window);
   --  Count the words, and say how many.

   procedure Show_Kind (Item : in out Window);
   --  Make the text area the item's text, or its one line, the link; and
   --  show the picture of a source.

end Items.Windows.Displays;
