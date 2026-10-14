with SDL3.Windows.Renderers;
with UI.Line_Texts;
with UI.Widgets;
with Viewer.Canvas_Items;
with Viewer.Style;
with Viewer.Settings_View;
with Viewer.Writing;

package body Viewer.Painting is

   package Widgets renames UI.Widgets;

   use SDL3.Windows.Renderers;

   procedure Paint (Item : in out Session) is
   begin
      UI.Line_Texts.Begin_Frame (Item.Host.Lines);
      if Item.Nav.Shown = Project then
         --  The canvas may be panned or laid out afresh since the items
         --  were put on it.
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Canvas_Items.Sync (Item);
         if Item.Toolbar.Mode = Write then
            Writing.Fit (Item);
         end if;
      elsif Item.Prefs.Showing_Settings then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Settings_View.Fit (Item);
      end if;
      --  The target keeps what is drawn on it, offscreen and in a window,
      --  so that only what has changed need be drawn again.
      Widgets.Paint
        (Item.Root.Widgets, Item.Host.Target, Style.Colors,
         Retained => Keeps_Frame (Item.Host.Target));
   end Paint;

   procedure Draw (Item : in out Session) is
      Resized : Boolean;
   begin
      --  A window that has changed size has a new image to draw to.
      Fit (Item.Host.Target, Resized);
      if Resized then
         Widgets.Invalidate_All (Item.Root.Widgets);
      end if;
      Paint (Item);
      Present (Item.Host.Target);
   end Draw;

end Viewer.Painting;
