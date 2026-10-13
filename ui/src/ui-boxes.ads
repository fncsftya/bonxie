with SDL3.Windows.Renderers;
with UI.Themes;

--  How a box is drawn: filled, with an outline a point wide, solid or
--  dashed, and a shadow cast down and to the right, solid and offset,
--  never blurred. Each is optional. The shadow is inside the box, so that
--  nothing is drawn outside it: the face is the box less the shadow's
--  offset at its right and foot, and what is in it is to be kept off that.
package UI.Boxes is

   type Look is record
      Filled   : Boolean := False;
      Fill     : Themes.Color := (0, 0, 0, 255);
      Bordered : Boolean := False;
      Border   : Themes.Color := (0, 0, 0, 255);
      Dashed   : Boolean := False;
      Shadowed : Boolean := False;
      Shadow   : Themes.Color := (0, 0, 0, 255);
   end record;

   function Edge (Density : Float) return Float is
     (Float'Max (1.0, Float'Rounding (Density)));
   --  The width of an outline, in whole pixels: one that is not is a
   --  pixel more or less where it is drawn, or none.

   function Offset (Density : Float) return Float is
     (Float'Rounding (Themes.Shadow_Offset * Density));
   --  Of a shadow, in whole pixels.

   function Inset (Item : Look; Density : Float) return Float is
     (if Item.Shadowed then Offset (Density) else 0.0);
   --  What the shadow takes of the box at its right and its foot.

   procedure Draw
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Look;
      Left, Top, Width, Height : Float;
      Density : Float)
     with Pre => Density > 0.0;
   --  In pixels from the top left of Target.

   procedure Outline
     (Target  : SDL3.Windows.Renderers.Renderer;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Thick   : Float;
      Dashed  : Boolean := False;
      Density : Float := 1.0)
     with Pre => Thick > 0.0 and then Density > 0.0;
   --  A ring Thick pixels wide just inside the box: in dashes of a few
   --  points, if Dashed.

end UI.Boxes;
