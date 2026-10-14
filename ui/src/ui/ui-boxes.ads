with SDL3.Windows.Renderers;
with UI.Themes;

--  How a box is drawn: filled, with an outline a point wide, solid or
--  dashed, and a shadow cast down and to the right, solid and offset,
--  never blurred. Each is optional. The shadow is inside the box, so that
--  nothing is drawn outside it: the face is the box less the shadow's
--  offset at its right and foot, and what is in it is to be kept off that.
package UI.Boxes is

   type Sides is (Top_Side, Right_Side, Bottom_Side, Left_Side);
   --  The edges of a box.

   type Spot is record
      X, Y : Float;
   end record;

   function Side_Midpoint
     (Left, Top, Width, Height : Float; Side : Sides) return Spot is
     (case Side is
         when Top_Side    => (Left + Width / 2.0, Top),
         when Right_Side  => (Left + Width, Top + Height / 2.0),
         when Bottom_Side => (Left + Width / 2.0, Top + Height),
         when Left_Side   => (Left, Top + Height / 2.0));
   --  The middle of the edge of the box.

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

   function Lift (Density : Float) return Float is (0.0 * Density);
   function Shift (Density : Float) return Float is (0.0 * Density);
   --  In whole pixels: the shadow of a control that stands up, and how
   --  far it goes when pressed in. Neither: it has no shadow, and the
   --  bevel alone turns over.

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
      Light   : Themes.Color;
      Dark    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False)
     with Pre => Density > 0.0;
   --  The edges of a face that stands up, a point wide, just inside the
   --  box: Light at its top and left, Dark at its foot and right; the
   --  other way round if it is Sunken, as pressed in. Flat colours, never
   --  a gradient.

   type Raised_Look is record
      Face    : Themes.Color := (0, 0, 0, 255);
      Edges_Given : Boolean := False;
      --  Whether Lit and Shaded are the bevel's edges; if not, they are
      --  made from Face.
      Lit     : Themes.Color := (0, 0, 0, 255);  --  the bevel's light edge
      Shaded  : Themes.Color := (0, 0, 0, 255);  --  its dark edge
      Border  : Themes.Color := (0, 0, 0, 255);
      Drop    : Themes.Color := (0, 0, 0, 255);
      Pressed : Boolean := False;
      Flat    : Boolean := False;
   end record;
   --  A control that stands up, as a button: a face, outlined, bevelled,
   --  and no shadow; pressed, the bevel turns over;
   --  Flat, as of one that is turned off, it has no bevel.

   procedure Draw_Raised
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Raised_Look;
      Left, Top, Width, Height : Float;
      Density : Float)
     with Pre => Density > 0.0;
   --  In the box, pressed or not.

   procedure Raised_Face
     (Item    : Raised_Look;
      Left, Top, Width, Height : Float;
      Density : Float;
      Face_Left, Face_Top, Face_Width, Face_Height : out Float);
   --  Where the face of a control so drawn is, in the box: what is on it
   --  goes with it when it is pressed.

end UI.Boxes;
