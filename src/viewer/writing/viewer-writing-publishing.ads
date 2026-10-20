--  The publish view's headings.
private package Viewer.Writing.Publishing is

   package Widgets renames Pomarine.Widgets;

   procedure Refresh_Publish (Item : in out Session);
   --  Compose the preview with real paragraph kinds for optional headings.

   procedure Publish_Options_Changed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

end Viewer.Writing.Publishing;
