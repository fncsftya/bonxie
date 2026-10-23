--  The publish view's headings, format and export.
private package Viewer.Writing.Publishing is

   package Widgets renames Pomarine.Widgets;

   procedure Refresh_Publish (Item : in out Session);
   --  Compose the preview with real paragraph kinds for optional headings.

   procedure Publish_Options_Changed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Format_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The format select was clicked: show its menu, or put it away.

   procedure Format_Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A row of the format menu was chosen: Markdown splits the content area into its text and the
   --  page as rendered.

   procedure Export_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  Ask, in the system's dialog, where to save the export (see Poll_Export).

   procedure Copy_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  Put the Markdown on the clipboard, and have the button say Copied for a few seconds.

   function Copy_Remaining (Item : Session) return Integer;
   --  Milliseconds until the button goes back to its label; -1 if it is not saying Copied.

   procedure Poll_Export (Item : in out Session);
   --  Write the export to the file the dialog chose, once it has.

   procedure Close_Format_Menu (Item : in out Session);

   procedure Menu_Pressed (Item : in out Session; X, Y : Float);
   --  Put the format menu away for a press outside it and the select.

end Viewer.Writing.Publishing;
