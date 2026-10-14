with SDL3.Windows.Renderers;

--  The colours components are drawn in. A theme is light or dark; the
--  colours a widget keeps are slots, resolved to the theme's colour when
--  it is drawn, so that a widget need not be built again to change theme.
package UI.Themes is

   subtype Color is SDL3.Windows.Renderers.Color;

   type Theme is record
      Background : Color;  --  of the desk, the canvas
      Foreground : Color;  --  text
      Accent     : Color;  --  what is chosen or switched on, and the caret
      Focus      : Color;  --  the ring round what has the keyboard's focus
      Primary    : Color;  --  the main, positive action, as making
      Danger     : Color;  --  what cannot be undone, as deleting
      Face       : Color;  --  of a button
      Border     : Color;  --  the outline of a box, a point wide
      Shadow     : Color;  --  cast by a box: solid, offset, never blurred
      Bar        : Color;  --  the dark bars: a window's title, the top
      Tint       : Color;  --  a strip of a box, as a status line
      Marker     : Color;  --  the highlighter's
      Page       : Color;  --  pages, windows and fields
      Rail       : Color;  --  the side rail, and the writing view's desk
      Dock       : Color;  --  behind the minimised items
      Dot        : Color;  --  the dots of the canvas's grid
      Muted      : Color;  --  what is said of something, as a count
      Closed     : Color;  --  the title of an item that is not shown
      Hint       : Color;  --  a hint in a field
      Rule       : Color;  --  a line on a dark bar
      Hover_Row  : Color;  --  a row of a list, under the pointer
      Drop_Shadow : Color;  --  of a control that stands up
      Face_Hover : Color;  --  of a secondary button, under the pointer
      Face_Pressed : Color;  --  of one held down
      Face_Light : Color;  --  its bevel, at the top and left
      Face_Shade : Color;  --  its bevel, at the foot and right
      Face_Edge  : Color;  --  its outline
      Primary_Light : Color;  --  the bevel of the main action
      Primary_Shade : Color;
      Danger_Light  : Color;  --  the bevel of what cannot be undone
      Danger_Shade  : Color;
      Primary_Ink : Color;  --  green as text
      Primary_Mix : Color;  --  green, a little toward the text, as a label
      Danger_Ink  : Color;  --  red as text
      On_Accent   : Color;  --  text on the accent, which stays dark
      Bar_Ink     : Color;  --  text on a dark bar
      Scrim       : Color;  --  over what is behind a dialog, to grey it out
      Source_Blue : Color;  --  the first source's colour, lighter in the dark
   end record;

   --  The colours a widget may keep. Source_1 .. Source_8 are the colours
   --  of the sources, in order: Source_1 is the theme's own blue, and the
   --  rest are `Source_Inks`, the same in both themes.
   type Slot is
     (Background, Foreground, Accent, Focus, Primary, Danger, Face, Border,
      Shadow, Bar, Tint, Marker, Page, Rail, Dock, Dot, Muted, Closed, Hint,
      Rule, Hover_Row, Drop_Shadow, Face_Hover, Face_Pressed, Face_Light,
      Face_Shade, Face_Edge, Primary_Light, Primary_Shade, Danger_Light,
      Danger_Shade, Primary_Ink, Primary_Mix, Danger_Ink, On_Accent,
      Bar_Ink, Scrim,
      Source_1, Source_2, Source_3, Source_4, Source_5, Source_6, Source_7,
      Source_8);

   Light : constant Theme;
   Dark  : constant Theme;

   White : constant Color := (255, 255, 255, 255);

   Source_Inks : constant array (1 .. 8) of Color :=
     [(16#25#, 16#63#, 16#D4#, 255),   --  blue
      (16#27#, 16#72#, 16#2D#, 255),   --  green
      (16#C6#, 16#28#, 16#28#, 255),   --  red
      (16#7A#, 16#4E#, 16#B8#, 255),   --  violet
      (16#0E#, 16#7C#, 16#7B#, 255),   --  teal
      (16#B4#, 16#5A#, 16#09#, 255),   --  rust
      (16#A2#, 16#3B#, 16#72#, 255),   --  plum
      (16#5B#, 16#6B#, 16#2F#, 255)];  --  olive
   --  Of the sources, in the order they were made, and round again.

   Shadow_Offset : constant Float := 3.0;
   --  In points, down and to the right, of a shadow.

   Raise_Offset : constant Float := 2.0;
   Press_Shift  : constant Float := 1.0;
   --  In points, down and to the right: of the shadow of a control that
   --  stands up, as a button; and how far it goes when pressed in.

   function Channel
     (A, B : SDL3.Windows.Renderers.Color_Component; Amount : Float)
      return SDL3.Windows.Renderers.Color_Component is
     (SDL3.Windows.Renderers.Color_Component
        (Float'Rounding (Float (A) + (Float (B) - Float (A)) * Amount)))
     with Pre => Amount in 0.0 .. 1.0;

   function Mix (From, To : Color; Amount : Float) return Color is
     ((Red   => Channel (From.Red, To.Red, Amount),
       Green => Channel (From.Green, To.Green, Amount),
       Blue  => Channel (From.Blue, To.Blue, Amount),
       Alpha => Channel (From.Alpha, To.Alpha, Amount)))
     with Pre => Amount in 0.0 .. 1.0;
   --  Amount of the way from From to To.

   function Highlight (Base : Color) return Color is
     (Mix (Base, (255, 255, 255, 255), 0.55));
   function Shade (Base : Color) return Color is
     (Mix (Base, (0, 0, 0, 255), 0.35));
   --  The edges of a bevel round a face: of the light, from above and
   --  the left, and away from it.

   function Dull (Item : Theme; Base : Color) return Color is
     (Mix (Base, Item.Background, 0.55));
   --  A face, or an ink, of what is turned off: flat, and faint.

   function Quiet (Item : Theme) return Color is (Item.Muted);
   --  Of what is said of something, as a count, or a hint in a field.

   function Selection (Item : Theme) return Color is
     (Mix (Item.Background, Item.Accent, 0.4));
   --  Behind selected text, when it has focus.

   function Inactive_Selection (Item : Theme) return Color is
     (Mix (Item.Background, Item.Foreground, 0.15));
   --  Behind selected text, when it has not.

   function Resolve (Item : Theme; Which : Slot) return Color;
   --  The colour Which is in the theme Item.

private

   --  The light theme's derived colours are those the components made
   --  from its base colours before the dark theme was added, so that the
   --  light theme is drawn as it was.

   Light_Foreground : constant Color := (16#11#, 16#11#, 16#11#, 255);
   Light_Background : constant Color := (16#C6#, 16#CF#, 16#CB#, 255);
   Light_Face       : constant Color := (16#A9#, 16#B1#, 16#AD#, 255);
   Light_Border     : constant Color := (16#8A#, 16#92#, 16#8E#, 255);
   Light_Bar        : constant Color := (16#4F#, 16#5B#, 16#56#, 255);
   Light_Primary    : constant Color := (16#27#, 16#72#, 16#2D#, 255);
   Light_Danger     : constant Color := (16#C6#, 16#28#, 16#28#, 255);
   Light_Source_Blue : constant Color := (16#25#, 16#63#, 16#D4#, 255);

   Light : constant Theme :=
     (Background    => Light_Background,
      Foreground    => Light_Foreground,
      Accent        => (16#E5#, 16#A1#, 16#5F#, 255),
      Focus         => (16#25#, 16#63#, 16#D4#, 255),
      Primary       => Light_Primary,
      Danger        => Light_Danger,
      Face          => Light_Face,
      Border        => Light_Border,
      Shadow        => (16#AE#, 16#B6#, 16#B2#, 255),
      Bar           => Light_Bar,
      Tint          => (16#D6#, 16#DC#, 16#D9#, 255),
      Marker        => (16#FF#, 16#D4#, 16#28#, 255),
      Page          => White,
      Rail          => (16#B8#, 16#C0#, 16#BB#, 255),
      Dock          => (16#B8#, 16#C0#, 16#BB#, 255),
      Dot           => Light_Border,
      Muted         => Mix (Light_Foreground, Light_Background, 0.45),
      Closed        => Mix (Light_Foreground, Light_Background, 0.55),
      Hint          => Mix (Light_Foreground, Light_Background, 0.35),
      Rule          => Mix (Light_Bar, White, 0.3),
      Hover_Row     => Mix (Light_Face, White, 0.3),
      Drop_Shadow   => Mix (Light_Border, Light_Foreground, 0.4),
      Face_Hover    => Mix (Light_Face, White, 0.22),
      Face_Pressed  => Mix (Light_Face, Light_Foreground, 0.12),
      Face_Light    => Highlight (Light_Face),
      Face_Shade    => Shade (Light_Face),
      Face_Edge     => Light_Border,
      Primary_Light => Highlight (Light_Primary),
      Primary_Shade => Shade (Light_Primary),
      Danger_Light  => Highlight (Light_Danger),
      Danger_Shade  => Shade (Light_Danger),
      Primary_Ink   => Light_Primary,
      Primary_Mix   => Mix (Light_Primary, Light_Foreground, 0.25),
      Danger_Ink    => Light_Danger,
      On_Accent     => Light_Foreground,
      Bar_Ink       => White,
      Scrim         => (16#11#, 16#11#, 16#11#, 128),
      Source_Blue   => Light_Source_Blue);

   --  The dark theme: the same hue, the lightness flipped.

   Dark_Foreground : constant Color := (16#E6#, 16#EC#, 16#E8#, 255);
   Dark_Background : constant Color := (16#1C#, 16#22#, 16#20#, 255);
   Dark_Face       : constant Color := (16#4A#, 16#55#, 16#50#, 255);
   Dark_Bar        : constant Color := (16#12#, 16#16#, 16#14#, 255);

   Dark : constant Theme :=
     (Background    => Dark_Background,
      Foreground    => Dark_Foreground,
      Accent        => (16#E5#, 16#A1#, 16#5F#, 255),
      Focus         => (16#7D#, 16#A6#, 16#FF#, 255),
      Primary       => (16#2B#, 16#7F#, 16#33#, 255),
      Danger        => (16#D2#, 16#3A#, 16#3A#, 255),
      Face          => Dark_Face,
      Border        => Dark_Face,
      Shadow        => (16#0D#, 16#11#, 16#10#, 255),
      Bar           => Dark_Bar,
      Tint          => (16#2B#, 16#33#, 16#30#, 255),
      Marker        => (16#F2#, 16#CB#, 16#2E#, 255),
      Page          => (16#32#, 16#3B#, 16#37#, 255),
      Rail          => (16#24#, 16#2B#, 16#28#, 255),
      Dock          => Dark_Bar,
      Dot           => (16#38#, 16#44#, 16#40#, 255),
      Muted         => (16#A9#, 16#B4#, 16#AE#, 255),
      Closed        => Mix (Dark_Foreground, Dark_Background, 0.55),
      Hint          => Mix (Dark_Foreground, Dark_Background, 0.35),
      Rule          => Mix (Dark_Bar, White, 0.3),
      Hover_Row     => Mix (Dark_Face, White, 0.3),
      Drop_Shadow   => (16#0D#, 16#11#, 16#10#, 255),
      Face_Hover    => (16#54#, 16#60#, 16#59#, 255),
      Face_Pressed  => (16#3E#, 16#48#, 16#43#, 255),
      Face_Light    => (16#6A#, 16#77#, 16#71#, 255),
      Face_Shade    => (16#2D#, 16#35#, 16#32#, 255),
      Face_Edge     => (16#15#, 16#1A#, 16#18#, 255),
      Primary_Light => (16#62#, 16#B5#, 16#6B#, 255),
      Primary_Shade => (16#17#, 16#48#, 16#1C#, 255),
      Danger_Light  => (16#EE#, 16#8A#, 16#8A#, 255),
      Danger_Shade  => (16#8E#, 16#1B#, 16#1B#, 255),
      Primary_Ink   => (16#6F#, 16#CB#, 16#78#, 255),
      Primary_Mix   =>
        Mix ((16#2B#, 16#7F#, 16#33#, 255), Dark_Foreground, 0.25),
      Danger_Ink    => (16#FF#, 16#8A#, 16#80#, 255),
      On_Accent     => (16#11#, 16#11#, 16#11#, 255),
      Bar_Ink       => White,
      Scrim         => (16#0D#, 16#11#, 16#10#, 160),
      Source_Blue   => (16#5B#, 16#8D#, 16#F0#, 255));

end UI.Themes;
