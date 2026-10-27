with Browser_Hosts;
with Browser_VM;
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

   type Browser_Choices is limited record
      Model : aliased Browser_VM.Model;
      Seen  : Pomarine.View_Models.Watch;
      Live  : aliased Browser_Hosts.Live_Page;
      --  The page the model moves; after it in the record are what refers to it.
      Host  : aliased Browser_Hosts.Browser_Host;
      Pane  : Pomarine.Widgets.Panels.Panel;
      --  The column over the right of the views: the bar of controls over the page, or over the place to start.
      Edge  : Pomarine.Widgets.Grips.Grip;
      --  The strip down its left edge, which is dragged to make the pane wider or narrower.
      Wide  : Float := Pane_Width;
      --  How wide it is now, in points.
      Start : Pomarine.Widgets.Labels.Label;
      --  What the page's place says until an address has been gone to.
      Page  : aliased Pomarine.Widgets.Embeds.Embed;
      --  Where the web view is.
   end record;

end View_Parts.Browser;
