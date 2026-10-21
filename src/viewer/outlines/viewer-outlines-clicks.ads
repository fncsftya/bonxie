--  What the outline's buttons and field say.
private package Viewer.Outlines.Clicks is

   package Widgets renames Pomarine.Widgets;

   procedure Colour_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   procedure Colour_Accepted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   procedure Colour_Cancelled
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Add_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Up_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Down_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Remove_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Notes_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Title_Submitted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  Return in a section's title: it is done with.

end Viewer.Outlines.Clicks;
