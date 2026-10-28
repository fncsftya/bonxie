with Ada.Containers.Vectors;
with Browser_Hosts;
with Browser_VM;
with Pomarine.UI;
with Pomarine.View_Models;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Embeds;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Panels;

--  The browser pane, floating over the right of a project's views: its view-model, the web view and the widgets
--  that stand for it.

package View_Parts.Browser is

   Pane_Width : constant Float := 420.0;
   --  In points, to begin with.

   Least_Width : constant Float := 280.0;
   --  The narrowest it is made, and the room it leaves of the views, at the most, are in points.

   Room_Left : constant Float := 160.0;

   type Card is limited record
      Whole : Pomarine.Widgets.Grips.Grip;
      Name  : Pomarine.Widgets.Labels.Label;
      Site  : Pomarine.Widgets.Labels.Label;
   end record;
   --  A favourite, as a card of the page's colour with its title and its site.

   type Card_Access is access Card;

   package Card_Vectors is new Ada.Containers.Vectors (Positive, Card_Access);

   type Browser_Choices is limited record
      Model           : aliased Browser_VM.Model;
      Seen            : Pomarine.View_Models.Watch;
      Live            : aliased Browser_Hosts.Live_Page;
      --  The page the model moves; after it in the record are what refers to it.
      Host            : aliased Browser_Hosts.Browser_Host;
      Pane            : Pomarine.Widgets.Panels.Panel;
      --  The column over the right of the views: the bar of controls over the page, or over the place to start.
      Edge            : Pomarine.Widgets.Grips.Grip;
      --  The strip down its left edge, which is dragged to make the pane wider or narrower.
      Wide            : Float := Pane_Width;
      --  How wide it is now, in points.
      Home            : Pomarine.Widgets.Panels.Panel;
      --  What there is to see until an address has been gone to: the line that follows, over the favourites.
      Start           : Pomarine.Widgets.Labels.Label;
      --  What it says: to enter an address, or that these are the favourites.
      Cards           : Pomarine.Widgets.Panels.Panel;
      --  The favourites' cards, one after another and on to another line.
      Pool            : Card_Vectors.Vector;
      --  The cards made so far: as many as the favourites there have been at the most, those not wanted hidden.
      Seen_Favourites : Pomarine.View_Models.Watch;
      Star            : Pomarine.UI.Button_Handle;
      --  The button that marks the page a favourite: filled in while it is one.
      Starred         : Boolean := False;
      --  Whether it is filled in now.
      Tray            : Pomarine.Widgets.Panels.Panel;
      --  The bar at the foot, which marks the page a favourite and captures it.
      Page            : aliased Pomarine.Widgets.Embeds.Embed;
      --  Where the web view is.
   end record;

end View_Parts.Browser;
