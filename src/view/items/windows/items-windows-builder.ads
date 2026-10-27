--  Making the widgets of a window.

private package Items.Windows.Builder is

   procedure Make_Parts
     (Item    : in out Window;
      Canvas  : in out Pomarine.Widgets.Widget'Class;
      Dock    : in out Pomarine.Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float);
   --  Add the window's widgets, hidden: its window to the canvas, its
   --  bar to the dock, both in the tree already. Do it once, before the
   --  layout, with the tree's density.

end Items.Windows.Builder;
