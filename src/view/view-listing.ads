--  The list of the project's items: a dialog over the project screen, with
--  a scrolling row for each item, to show it on the canvas or hide it, or
--  remove it for good.
with Pomarine.Models;
with Pomarine.Widgets;

private package View.Listing is

   procedure Open (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Put the list up, if Nav_VM lets it be.

   procedure Close (Item : in out Session);
   --  Put it away.

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

   --  What the list says (see View.Responses, which gives them to it):

   procedure Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A row was clicked, or Return pressed on it: show the item on the
   --  canvas, and put the list away.

   procedure Acted
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);
   --  A button of a row: show or hide its item, or remove it.

end View.Listing;
