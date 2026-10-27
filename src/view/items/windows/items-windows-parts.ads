--  Small questions about the widgets of a window, shared by the rest.

private package Items.Windows.Parts is

   function Across_Of (Item : Window) return Float;
   --  How far across it is scrolled: only a source's picture is.

   function Scroll_Of (Item : in out Window) return Float;
   --  How far the content is scrolled now (see Items.Info.Scroll).

   function Shown_Marks_Version (Item : Window) return Natural;
   --  Of the widget shown, whatever the item is.

end Items.Windows.Parts;
