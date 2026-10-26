--  The list of the project's items: a dialog over the project screen, with
--  a scrolling row for each item, to show it on the canvas or hide it, or
--  remove it for good.
with Pomarine.Models;
with Pomarine.Widgets;

private package View.Listing is

   function Overlay (Item : Session) return access Pomarine.Widgets.Widget'Class;
   --  The grey over the screen, with the dialog in it.

   procedure Show_List (Item : in out Session);
   --  Show the list, from its start: the reaction to Nav_VM putting it up (see View.Navigation).

   procedure Hide_List (Item : in out Session);
   --  Show it away.

   procedure Refresh (Item : in out Session);
   --  Make the rows those of the items there are now.

   procedure Describe
     (Item    : Session;
      Row     : Positive;
      Content : out Pomarine.Models.Row_Content)
     with Pre => Row <= Item_List_VM.Count (Item.Item_List.Model);
   --  What the list shows for its Rowth item.

end View.Listing;
