--  What the outline's colour box and title fields ask (Outline_VM's Choose_Colour, Accept_Colour, Cancel_Colour
--  and End_Title): done here, as they are of the widgets.

private package View.Outlines.Clicks is

   procedure Colour_Clicked (Item : in out Session; Index : Positive);
   --  The swatch of the section of this row was pressed: the box to choose its colour is over it.
   procedure Colour_Accepted (Item : in out Session);
   procedure Colour_Cancelled (Item : in out Session);

   procedure Title_Submitted (Item : in out Session);
   --  Return in a section's title: it is done with.

end View.Outlines.Clicks;
