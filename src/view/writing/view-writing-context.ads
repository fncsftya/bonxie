--  The menu at a right click, and what its rows do.

private package View.Writing.Context is

   procedure Open_At (Item : in out Session; X, Y : Float; Opened : out Boolean)
   with Pre => Screen (Item) = Project;
   --  The right button was pressed at X, Y, in points of the window: show
   --  the menu of what is there, if it has one: in the writing view, a row
   --  of the sidebar, a page's text or a source's window; on the canvas,
   --  the text or the picture of a window.

   procedure Do_Context (Item : in out Session; Chosen : Positive);
   --  Do what the row clicked of the menu does, and put it away.

   procedure Delete_Tree_Node (Item : in out Session; Node : Tree_Entry; Delete_Documents : Boolean := False)
   with Pre => Screen (Item) = Project and then Node.Kind /= Overview_Node;
   --  Delete a document or a folder subtree. Keep its documents at the top
   --  level unless Delete_Documents is selected.

end View.Writing.Context;
