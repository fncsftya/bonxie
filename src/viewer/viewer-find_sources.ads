with Items;
with Items.Windows;
with SDL3.Events;

--  Finding sources for the text of a note (see Source_Finder): the note's Find
--  Sources button starts it; a toast at the top right of the content area says
--  how it goes, and has a button to stop it; what passed is listed under the
--  toast, to be added to the project as sources, linked from the note, or
--  put away.
private package Viewer.Find_Sources is

   procedure Build (Item : in out Session);
   --  Add the toast and the list to the content area, hidden, and listen to
   --  them. Do it once the content area has been built.

   procedure Start (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The Find Sources button of the note of the window was clicked: find
   --  sources for its text, if the AI is on and a model can be asked, and no
   --  other work of this kind is being done. If not, the toast says why.

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds);
   --  Do what is to be done as time goes: move the work on, show how it is
   --  going, act on what was clicked, put away a message that has been seen
   --  long enough, and turn the notes' buttons on or off as the AI is.

   function Working (Item : Session) return Boolean;
   --  Whether it should be looked at again soon: the work is under way, or a
   --  message is to be put away.

   procedure Leave (Item : in out Session);
   --  The project is left: stop the work, if it is going, and forget what it
   --  came to, throwing away the pictures.

   procedure Pressed (Item : in out Session; X, Y : Float);
   --  The pointer was pressed at X, Y, in points: the list is put away if that
   --  is outside it, and the toast.

   procedure Stop;
   --  For when the program is ending: stop the work without waiting.

end Viewer.Find_Sources;
