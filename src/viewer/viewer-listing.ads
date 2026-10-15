--  The list of the project's items: a dialog over the project screen, with
--  a scrolling row for each item, to show it on the canvas or hide it, or
--  remove it for good.
private package Viewer.Listing is

   procedure Open (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Show the list, from its start.

   procedure Close (Item : in out Session);
   --  Hide it.

   procedure Refresh (Item : in out Session);
   --  Make the rows those of the items there are now.

   procedure Respond (Item : in out Session; What : Command; Row : Natural)
     with Pre => Screen (Item) = Project and then Item.Item_List.Showing_List;
   --  Do what a button of the list was clicked for: Close_List, or of the
   --  row of the item Row, Reveal_Item, Toggle_Item or Remove_Item.

end Viewer.Listing;
