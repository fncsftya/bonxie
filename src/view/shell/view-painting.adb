with Settings_VM;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with Pomarine.Line_Texts;
with Pomarine.Widgets;
with View.Canvas_Items;
with View.Navigation;
with View.Outlines;
with View.Style;
with View.Search;
with View.Settings_View;
with View.Writing;

package body View.Painting is

   package Widgets renames Pomarine.Widgets;

   use SDL3.Windows.Renderers;

   procedure Paint (Item : in out Session) is
   begin
      Search.Update (Item);
      Item.Root.Window_Panel.Dark := Style.Is_Dark;
      Pomarine.Line_Texts.Begin_Frame (Item.Host.Lines);
      if Screen (Item) = Project then
         --  The canvas may be panned or laid out afresh since the items
         --  were put on it.
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Canvas_Items.Sync (Item);
         if View_Mode (Item) in Write | Publish then
            Writing.Fit (Item);
            Search.Reveal (Item);
            --  What was typed in a section's notes is kept.
            Outlines.Sync (Item);
         elsif View_Mode (Item) = Outline then
            Outlines.Sync (Item);
         end if;
         --  The toolbar shows the project's name as the outline has it now.
         Navigation.Sync (Item);
      elsif Settings_VM.Is_Showing (Item.Choices.Model) then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Settings_View.Fit (Item);
      end if;
      --  The target keeps what is drawn on it, offscreen and in a window,
      --  so that only what has changed need be drawn again.
      Widgets.Paint (Item.Root.Widgets, Item.Host.Target, Style.Colors, Retained => Keeps_Frame (Item.Host.Target));
   end Paint;

   procedure Fit_Density (Item : in out Session) is
   begin
      if Item.Shell.Windowed then
         declare
            Now : constant Float := SDL3.Windows.Pixel_Density (Item.Host.Win);
         begin
            if Now > 0.0 and then Now /= Item.Shell.Density then
               Item.Shell.Density := Now;
               Widgets.Set_Density (Item.Root.Widgets, Now);
               Widgets.Invalidate_All (Item.Root.Widgets);
            end if;
         end;
      end if;
   end Fit_Density;

   procedure Fit_Buttons (Item : Session) is
   begin
      if Item.Shell.Windowed then
         SDL3.Windows.Set_Title_Bar_Height (Item.Host.Win, Style.Toolbar_Size, Style.Button_Inset);
      end if;
   end Fit_Buttons;

   procedure Draw (Item : in out Session) is
      Resized : Boolean;
   begin
      --  A window that has changed size has a new image to draw to.
      Fit (Item.Host.Target, Resized);
      if Resized then
         Widgets.Invalidate_All (Item.Root.Widgets);
      end if;
      Fit_Density (Item);
      Fit_Buttons (Item);
      Paint (Item);
      Present (Item.Host.Target);
   end Draw;

end View.Painting;
