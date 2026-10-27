--  The browser pane: a bar of controls over a live web view (see Browser_Hosts) that floats over the right of the
--  project's views, in each of them, from the toolbar to the dock, and takes no room from them. The button at the
--  right of the toolbar and Command with G put it up and away. It is shown as the navigation says (Nav_VM.
--  Browser_Shown); until an address has been gone to it shows a place to type one, and the page, which keeps the
--  person's place in it, is asked for then and not before.

package View.Browsers is

   procedure Build (Item : in out Session);
   --  The controls of the pane and the web view, after the project screen is built.

   procedure Sync (Item : in out Session);
   --  Put the pane up or away as the navigation says, and show the button as pressed while it is asked for.

   procedure Update (Item : in out Session);
   --  Once a frame, while the pane is up: look at the page, and show what changed (where it is).

end View.Browsers;
