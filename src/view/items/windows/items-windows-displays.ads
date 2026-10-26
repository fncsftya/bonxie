--  Showing what a window's model says: its title, words, link, pager and zoom, by the kind it is, and how a source's
--  picture stands.
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
   --  The title as edited, for the bar and the bar in the dock.

   procedure Show_Look (Item : in out Window);
   --  Everything of how the model's item looks but where it is: its kind, the origin of a source, its zoom, its tool,
   --  how its picture stands, and what its status line says.

   procedure Show_Status (Item : in out Window);
   --  What its status line says, the bar along its foot and the button to dictate: as the model has them now.

   procedure Show_Picture (Item : in out Window);
   --  Load the picture, or open the pages, that the model has.

   procedure Show_Words (Item : in out Window);
   --  The words found in the picture, to select.

   procedure Show_Marks (Item : in out Window);
   --  The marks the model has on the picture.

   procedure Show_Where (Item : in out Window);
   --  Whether it is a window, a bar in the dock, or not shown, and where.

   procedure Show_Tool (Item : in out Window);

   procedure Show_Zoom (Item : in out Window);
   --  The zoom of a source's picture, and what shows it: the slider, the button and the menu.

end Items.Windows.Displays;
