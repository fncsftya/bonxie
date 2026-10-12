with SDL3.Windows.Renderers;

--  The colours components are drawn in.
package UI.Themes is

   subtype Color is SDL3.Windows.Renderers.Color;

   type Theme is record
      Background : Color;  --  of the window, and of fields
      Foreground : Color;  --  text, and outlines
      Accent     : Color;  --  what has focus, and the caret
      Primary    : Color;  --  the main, positive action, as making
      Danger     : Color;  --  what cannot be undone, as deleting
   end record;

   Light : constant Theme :=
     (Background => (16#CD#, 16#D5#, 16#D1#, 255),
      Foreground => (16#09#, 16#0A#, 16#0B#, 255),
      Accent     => (16#FF#, 16#7F#, 16#11#, 255),
      Primary    => (16#2E#, 16#7D#, 16#32#, 255),
      Danger     => (16#C6#, 16#28#, 16#28#, 255));

   function Mix (From, To : Color; Amount : Float) return Color
     with Pre => Amount in 0.0 .. 1.0;
   --  Amount of the way from From to To.

   function Highlight (Face : Color) return Color is
     (Mix (Face, (255, 255, 255, 255), 0.55));
   function Shade (Face : Color) return Color is
     (Mix (Face, (0, 0, 0, 255), 0.35));
   --  The edges of a bevel round a face: of the light, from above and
   --  the left, and away from it.

   function Scrim (Item : Theme) return Color is
     (Item.Foreground.Red, Item.Foreground.Green, Item.Foreground.Blue, 128);
   --  Over what is behind a dialog, to grey it out.

   function Selection (Item : Theme) return Color is
     (Mix (Item.Background, Item.Accent, 0.4));
   --  Behind selected text, when it has focus.

   function Inactive_Selection (Item : Theme) return Color is
     (Mix (Item.Background, Item.Foreground, 0.15));
   --  Behind selected text, when it has not.

end UI.Themes;
