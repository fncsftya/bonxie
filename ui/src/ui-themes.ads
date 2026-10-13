with SDL3.Windows.Renderers;

--  The colours components are drawn in.
package UI.Themes is

   subtype Color is SDL3.Windows.Renderers.Color;

   type Theme is record
      Background : Color;  --  of the window, and of fields
      Foreground : Color;  --  text
      Accent     : Color;  --  what is chosen or has focus, and the caret
      Primary    : Color;  --  the main, positive action, as making
      Danger     : Color;  --  what cannot be undone, as deleting
      Face       : Color;  --  of a button
      Border     : Color;  --  the outline of a box, a point wide
      Shadow     : Color;  --  cast by a box: solid, offset, never blurred
      Bar        : Color;  --  the dark bars: a window's title, the top
      Tint       : Color;  --  a strip of a box, as a status line
      Marker     : Color;  --  the highlighter's
   end record;

   Light : constant Theme :=
     (Background => (16#C6#, 16#CF#, 16#CB#, 255),
      Foreground => (16#09#, 16#0A#, 16#0B#, 255),
      Accent     => (16#E5#, 16#A1#, 16#5F#, 255),
      Primary    => (16#27#, 16#72#, 16#2D#, 255),
      Danger     => (16#C6#, 16#28#, 16#28#, 255),
      Face       => (16#A9#, 16#B1#, 16#AD#, 255),
      Border     => (16#8A#, 16#92#, 16#8E#, 255),
      Shadow     => (16#AE#, 16#B6#, 16#B2#, 255),
      Bar        => (16#4F#, 16#5B#, 16#56#, 255),
      Tint       => (16#D6#, 16#DC#, 16#D9#, 255),
      Marker     => (16#FF#, 16#D4#, 16#28#, 255));

   White : constant Color := (255, 255, 255, 255);

   Shadow_Offset : constant Float := 3.0;
   --  In points, down and to the right, of a shadow.

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
