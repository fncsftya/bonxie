with Items;
with Items.Readers;
with Projects;
with SDL3.Events;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Toasts;

--  Finding sources for a note: the toast that says how it goes, and the list
--  of what was found.
package Viewer_Parts.Finder is

   type Finder_Parts is limited record
      Toast        : Pomarine.Widgets.Toasts.Toast;
      --  At the top right of the content area, hidden until there is work to
      --  show: how it is going, with a button to stop it; what it came to.
      Review       : Pomarine.Widgets.Menus.Menu;
      --  Under it, in purple, hidden until its Review button is clicked: the
      --  sources that were found, to add one, or all, or to put them away.
      Preview      : Items.Readers.Reader;
      --  Beside it, in a window as a source's is in the writing view: the page of
      --  the source that is under the pointer in the list (or the first, to begin
      --  with), as it would be added, to see what is being chosen.
      Previewing   : Natural := 0;
      --  Which of the sources found it shows; 0 if none.
      Review_Open  : Boolean := False;
      Shown        : Boolean := False;
      --  Whether the toast is.
      Owner        : Boolean := False;
      --  Whether the work Source_Finder has (or its end) is this session's:
      --  there is one piece of it at a time, whichever session asked.
      Notice       : Boolean := False;
      --  Whether what the toast says is a word of its own (why nothing was
      --  started), not what Source_Finder is at.
      Project      : Projects.Id := 0;
      Note         : Items.Id := 0;
      --  The project and the item the sources are for: the item gets a link
      --  to each source that is added.
      Hide_After   : SDL3.Events.Milliseconds := 0;
      --  When a message that is only to be seen is put away; 0 if there is
      --  no message, or not yet a time for it.
   end record;

end Viewer_Parts.Finder;
