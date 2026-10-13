with SDL3.Windows.Renderers;
with UI.Line_Texts;
with UI.Widgets;
with Viewer.Canvas_Items;
with Viewer.Style;
with Viewer.Writing;

package body Viewer.Painting is

   package Widgets renames UI.Widgets;

   use SDL3.Windows.Renderers;

   procedure Paint (Item : in out Session) is
   begin
      UI.Line_Texts.Begin_Frame (Item.Lines);
      if Item.Shown = Project then
         --  The canvas may be panned or laid out afresh since the items
         --  were put on it.
         Widgets.Layout (Item.Widgets, Item.Target);
         Canvas_Items.Sync (Item);
         if Item.Mode = Write then
            Writing.Fit (Item);
         end if;
      end if;
      --  The target keeps what is drawn on it, offscreen and in a window,
      --  so that only what has changed need be drawn again.
      Widgets.Paint
        (Item.Widgets, Item.Target, Style.Colors,
         Retained => Keeps_Frame (Item.Target));
   end Paint;

   procedure Draw (Item : in out Session) is
      Resized : Boolean;
   begin
      --  A window that has changed size has a new image to draw to.
      Fit (Item.Target, Resized);
      if Resized then
         Widgets.Invalidate_All (Item.Widgets);
      end if;
      Paint (Item);
      Present (Item.Target);
   end Draw;

end Viewer.Painting;
