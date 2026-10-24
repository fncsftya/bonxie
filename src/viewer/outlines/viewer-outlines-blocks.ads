--  The blocks of the sections: shown, dragged to another place, and their order kept.
private package Viewer.Outlines.Blocks is

   package Widgets renames Pomarine.Widgets;

   procedure Show_Blocks (Item : in out Session);
   --  Show a block for each section, with its title, and the note that
   --  there are none if there are none.

   function Drop_Before (Item : Session; Y : Float) return Natural;
   --  Which block the one dragged would go in front of, if let go at Y
   --  points down the window: Count + 1 for last; 0 where it already is.

   procedure Show_Drop_Line (Item : in out Session);
   --  Put the line where a block would go between two, or hide it.

   procedure Show_Ghost (Item : in out Session);
   --  Put the ghost of the block dragged under the pointer, or hide it.

   procedure Block_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Block_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

end Viewer.Outlines.Blocks;
