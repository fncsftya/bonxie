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

   function Lift (Density : Float) return Float is
     (Float'Max (1.0, Float'Rounding (Themes.Raise_Offset * Density)));
   function Shift (Density : Float) return Float is
     (Float'Max (1.0, Float'Rounding (Themes.Press_Shift * Density)));
   --  In whole pixels: of the shadow of a control that stands up, and how
   --  far it goes when pressed in.

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

   procedure Bevel
     (Target  : SDL3.Windows.Renderers.Renderer;
      Face    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False)
     with Pre => Density > 0.0;
   --  The edges of a face that stands up, a point wide, just inside the
   --  box: light (Themes.Highlight) at its top and left, dark
   --  (Themes.Shade) at its foot and right; the other way round if it is
   --  Sunken, as pressed in. Flat colours, never a gradient.

   type Raised_Look is record
      Face    : Themes.Color := (0, 0, 0, 255);
      Border  : Themes.Color := (0, 0, 0, 255);
      Drop    : Themes.Color := (0, 0, 0, 255);
      Pressed : Boolean := False;
      Flat    : Boolean := False;
   end record;
   --  A control that stands up, as a button: a face, outlined, bevelled,
   --  and casting a small solid shadow (Lift); pressed, the bevel turns
   --  over, the shadow goes and the face goes down and right by Shift;
   --  Flat, as of one that is turned off, it has no bevel or shadow.

   procedure Draw_Raised
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Raised_Look;
      Left, Top, Width, Height : Float;
      Density : Float)
     with Pre => Density > 0.0;
   --  In the box, with the room for the shadow inside it at the right
   --  and the foot (as a box's: see Raised_Face), pressed or not.

   procedure Raised_Face
     (Item    : Raised_Look;
      Left, Top, Width, Height : Float;
      Density : Float;
      Face_Left, Face_Top, Face_Width, Face_Height : out Float);
   --  Where the face of a control so drawn is, in the box: what is on it
   --  goes with it when it is pressed.

end UI.Boxes;
