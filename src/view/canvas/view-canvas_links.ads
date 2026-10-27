with View.Canvas_Windows;

--  The links between the project's items on the canvas, and the pins they
--  are dragged from: for tests.

package View.Canvas_Links is

   function Link_Count (Item : Session) return Natural
   with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many there are between the project's items.

   procedure Link_Items (Item : in out Session; From, To : Positive)
   with
     Pre =>
       Is_Open (Item)
       and then Screen (Item) = Project
       and then From <= Canvas_Windows.Item_Count (Item)
       and then To <= Canvas_Windows.Item_Count (Item)
       and then From /= To;
   --  Join the Fromth and Toth items, as dragging from a pin of one to a
   --  pin of the other does: for tests, which need not find the pins.

   function Link_Selected (Item : Session) return Boolean
   with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Whether a link is selected.

   function Link_Description (Item : Session; Number : Positive) return String
   with Pre => Is_Open (Item) and then Screen (Item) = Project and then Number <= Link_Count (Item);
   --  How the link is drawn and where it ends, as words: its stroke, its
   --  end, its colour's number, and the side it ends on.

   function Pin_Count (Item : Session) return Natural
   with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many pins, to drag a link from, are shown.

end View.Canvas_Links;
