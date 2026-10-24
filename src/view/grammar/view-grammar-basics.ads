with Harper;
with Pomarine.Themes;
with Texts.Documents;

--  Questions and the colours shared by the grammar checks' parts.
private package View.Grammar.Basics is

   package Docs renames Texts.Documents;

   --  Harper desktop: src-tauri/src/lint_kind_color.rs at the vendored
   --  revision. draw_highlight.rs uses alpha 24 and a two-pixel underline.
   Colors : constant array (Harper.Lint_Kind) of Pomarine.Themes.Color :=
     [(16#22#, 16#8B#, 16#22#, 255), (16#8B#, 16#45#, 16#13#, 255),
      (16#54#, 16#0D#, 16#6E#, 255), (16#FF#, 16#8C#, 16#00#, 255),
      (16#0E#, 16#AD#, 16#69#, 255), (16#7D#, 16#3C#, 16#98#, 255),
      (16#9B#, 16#59#, 16#B6#, 255), (16#C7#, 16#15#, 16#85#, 255),
      (16#3B#, 16#CE#, 16#AC#, 255), (16#00#, 16#8B#, 16#8B#, 255),
      (16#D4#, 16#85#, 16#0F#, 255), (16#2E#, 16#8B#, 16#57#, 255),
      (16#46#, 16#82#, 16#B4#, 255), (16#C0#, 16#61#, 16#CB#, 255),
      (16#00#, 16#A6#, 16#7C#, 255), (16#EE#, 16#42#, 16#66#, 255),
      (16#FF#, 16#D2#, 16#3F#, 255), (16#FF#, 16#6B#, 16#35#, 255),
      (16#1E#, 16#90#, 16#FF#, 255), (16#22#, 16#8B#, 16#22#, 255),
      (16#4D#, 16#4D#, 16#FF#, 255)];

   function Active (Item : Session) return Boolean;

   function Image (Total : Natural) return String;

   function Valid (Item : Session; Row : Grammar_Row) return Boolean;
   --  Whether the row still describes its document. Not tied to Active: the rows
   --  and the marks outlive a visit to another tab, and are shown again on return.

   function Flagged (Item : Session; Row : Grammar_Row) return String
     with Pre => Valid (Item, Row);
   --  The text the row marks, if it lies in one paragraph; otherwise empty.

   procedure Load_Rules (Item : in out Session);
   --  Read the open project's rules, if those held are not its.

   function Advance (Doc : Docs.Document; From : Texts.Position; Bytes : Natural) return Texts.Position;

end View.Grammar.Basics;
