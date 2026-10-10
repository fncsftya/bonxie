with Ada.Finalization;
with System;

package SDL3.Windows.Renderers.Textures is

   type Texture is limited private;
   --  An image on the GPU, drawn by a Renderer. Must not outlive the
   --  Renderer it was made for.

   procedure Create_Premultiplied_RGBA
     (Item   : in out Texture;
      Target : Renderer;
      Columns, Rows : Positive;
      Pixels : System.Address;
      Pitch  : Positive)
     with Pre => Pitch >= 4 * Columns;
   --  Replace Item with a Columns x Rows image copied from Pixels: rows
   --  of Pitch bytes, each pixel the bytes R, G, B, A with the colour
   --  already multiplied by the alpha. It is drawn with that blend, and
   --  without smoothing, so that text stays crisp at its own size.

   procedure Create_Blank
     (Item    : in out Texture;
      Target  : Renderer;
      Columns, Rows : Positive;
      Smooth  : Boolean);
   --  Replace Item with a transparent image to fill in with
   --  Update_Region. Its pixels are not premultiplied, unlike those
   --  above: the software renderer blends geometry, as Draw_Quads draws,
   --  only so. With Smooth, drawn scaled it is smoothed, otherwise it is
   --  not.

   procedure Update_Region
     (Item   : Texture;
      Left, Top, Columns, Rows : Natural;
      Pixels : System.Address;
      Pitch  : Positive)
     with Pre => not Is_Empty (Item)
                 and then Left + Columns <= Width (Item)
                 and then Top + Rows <= Height (Item)
                 and then Pitch >= 4 * Columns;
   --  Copy Pixels, rows of Pitch bytes, each pixel the bytes R, G, B, A,
   --  premultiplied or not as Item is, over the part of Item whose top
   --  left is at Left, Top.

   function Is_Empty (Item : Texture) return Boolean;

   procedure Draw
     (Target : Renderer;
      Item   : Texture;
      X, Y   : Float)
     with Pre => not Is_Empty (Item);
   --  Draw Item, at its own size, with its top left at X, Y.

   function Width (Item : Texture) return Positive
     with Pre => not Is_Empty (Item);
   function Height (Item : Texture) return Positive
     with Pre => not Is_Empty (Item);

   --  Many images from one texture in one go

   type Vertex is record
      X, Y  : Float;  --  where on the target
      Red, Green, Blue, Alpha : Float;
      --  What the texture's colour is multiplied by: for premultiplied
      --  images, so are Red, Green and Blue by Alpha.
      U, V  : Float;  --  where in the texture, 0.0 .. 1.0
   end record
     with Convention => C;

   type Vertex_Array is array (Positive range <>) of Vertex
     with Convention => C;

   Max_Quads : constant := 4096;

   procedure Draw_Quads
     (Target     : Renderer;
      Item       : Texture;
      Vertices   : Vertex_Array;
      Quad_Count : Natural)
     with Pre => not Is_Empty (Item)
                 and then Quad_Count <= Max_Quads
                 and then Vertices'Length >= 4 * Quad_Count;
   --  Draw Quad_Count rectangles of the texture in one call: each is
   --  four consecutive Vertices, in the order top left, top right,
   --  bottom left, bottom right.

private

   type Texture is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
      Wide   : Natural := 0;
      High   : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Texture);

end SDL3.Windows.Renderers.Textures;
