with SDL3.Windows;
with SDL3.Windows.Renderers;
with UI.Line_Texts;
with UI.Widgets;
with Viewer.Style;

package body Viewer.Painting is

   package Widgets renames UI.Widgets;
   package Editors renames UI.Widgets.Editors;

   use SDL3.Windows.Renderers;

   procedure Tell_Input_Method (Item : in out Session);
   --  Where the caret is, so that an input method can show its choices
   --  beside it.

   procedure Paint (Item : in out Session) is
   begin
      UI.Line_Texts.Begin_Frame (Item.Lines);
      --  The target keeps what is drawn on it, offscreen and in a window,
      --  so that only what has changed need be drawn again.
      Widgets.Paint
        (Item.Widgets, Item.Target, Style.Colors,
         Retained => Keeps_Frame (Item.Target));
   end Paint;

   procedure Tell_Input_Method (Item : in out Session) is
      X, Y, Width, Height : Float;
   begin
      if Editors.Is_Focused (Item.Area) then
         Editors.Caret_Box (Item.Area, X, Y, Width, Height);
         declare
            Across : constant Integer := Integer (X / Item.Density);
         begin
            --  Once a line, not once a character: the input method's
            --  choices would jump about as it is typed into.
            if Across /= Item.Input_Area then
               Item.Input_Area := Across;
               SDL3.Windows.Set_Text_Input_Area
                 (Item.Win, Across, Integer (Y / Item.Density),
                  Integer (Float'Ceiling (Width / Item.Density)),
                  Integer (Float'Ceiling (Height / Item.Density)));
            end if;
         end;
      end if;
   end Tell_Input_Method;

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
      Tell_Input_Method (Item);
   end Draw;

end Viewer.Painting;
