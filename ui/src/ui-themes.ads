with SDL3.Windows.Renderers;

--  The colours components are drawn in.
package UI.Themes is

   subtype Color is SDL3.Windows.Renderers.Color;

   type Theme is record
      Background : Color;  --  of the window, and of fields
      Foreground : Color;  --  text, and outlines
      Accent     : Color;  --  what has focus, and the caret
   end record;

   Light : constant Theme :=
     (Background => (16#CD#, 16#D5#, 16#D1#, 255),
      Foreground => (16#09#, 16#0A#, 16#0B#, 255),
      Accent     => (16#FF#, 16#7F#, 16#11#, 255));

   function Mix (From, To : Color; Amount : Float) return Color
     with Pre => Amount in 0.0 .. 1.0;
   --  Amount of the way from From to To.

   function Selection (Item : Theme) return Color is
     (Mix (Item.Background, Item.Accent, 0.4));
   --  Behind selected text, when it has focus.

   function Inactive_Selection (Item : Theme) return Color is
     (Mix (Item.Background, Item.Foreground, 0.15));
   --  Behind selected text, when it has not.

end UI.Themes;
