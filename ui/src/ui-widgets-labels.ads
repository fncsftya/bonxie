with SDL3.Windows.Renderers;

--  A line of text to read, on the left of its box, in the middle of its
--  height. It takes no events.
package UI.Widgets.Labels is

   Text_Capacity : constant := 48;
   --  Characters.

   type Label is new Widget with private;

   procedure Set_Text (Item : in out Label; Value : String)
     with Pre => Value'Length <= Text_Capacity;
   --  Show Value, in the debug font of SDL3.Windows.Renderers, scaled to
   --  the density.

   function Text (Item : Label) return String;

   procedure Set_Style (Item : in out Label; To : Line_Texts.Style);
   --  Show it as a heading, or as regular text, which it is to begin with.
   --  Only in the system font: the debug font has the one size.

   function Style (Item : Label) return Line_Texts.Style;

   procedure Set_Scale (Item : in out Label; To : Float)
     with Pre => To > 0.0;
   --  Show the text at To times its size (1.0 to begin with), in the
   --  system font: as a title is smaller over a canvas zoomed out.

   procedure Set_Ink (Item : in out Label; To : Themes.Color);
   --  Show it in To, rather than the theme's foreground: as on a dark
   --  bar.

   overriding procedure Draw
     (Item   : in out Label;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

private

   type Label is new Widget with record
      Content : String (1 .. Text_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Text_Capacity := 0;
      Using   : Line_Texts.Style := Line_Texts.Regular;
      Inked   : Boolean := False;
      Ink     : Themes.Color := (0, 0, 0, 255);
      Scaled  : Float := 1.0;
   end record;

end UI.Widgets.Labels;
