with Interfaces;

package SDL3.Windows.Renderers is

   type Renderer is limited private;
   --  Draws into a Window. Must not outlive that Window: declare it after
   --  the Window so it is destroyed first.

   type Color_Component is new Interfaces.Unsigned_8;

   type Color is record
      Red, Green, Blue : Color_Component;
      Alpha            : Color_Component := 255;
   end record;

   Debug_Text_Size : constant := 8;
   --  Width and height in pixels of one Draw_Text character at Scale 1.

   procedure Create
     (Item       : in out Renderer;
      Target     : Window;
      VSync      : Boolean := True;
      Keep_Frame : Boolean := True);
   --  With VSync, Present waits for the display's refresh: no tearing,
   --  and it paces the render loop. Without it frames are as fast as
   --  they can be drawn, as for measuring.
   --
   --  With Keep_Frame, drawing is to an image of its own the size of the
   --  window, which Present copies to it, so that what is drawn stays
   --  for the next frame, and only what has changed need be drawn
   --  again; see Keeps_Frame, Fit. Without, the window's own frames are
   --  swapped, and are not as they were left: draw each one all.

   procedure Create_Offscreen
     (Item : in out Renderer; Width, Height : Positive)
     with Post => Is_Offscreen (Item);
   --  Draw, without a window, into a Width x Height image of its own, in
   --  software: the same drawing gives the same pixels every time, as for
   --  testing. Read them with Images.Read.

   function Is_Offscreen (Item : Renderer) return Boolean;

   function Keeps_Frame (Item : Renderer) return Boolean;
   --  Whether what is drawn stays until it is drawn over: of an
   --  offscreen renderer, and of a window's with Keep_Frame.

   procedure Fit (Item : in out Renderer; Changed : out Boolean);
   --  Make the image a window's renderer keeps the size of the window,
   --  if that has changed, which loses what was drawn: Changed says so.
   --  Do it before drawing a frame. Nothing is done otherwise.

   procedure Resize (Item : in out Renderer; Width, Height : Positive)
     with Pre => Is_Offscreen (Item);
   --  Make the image Width x Height, losing what is drawn.

   procedure Output_Size
     (Item : Renderer; Width, Height : out Natural);
   --  Size of the drawable area in pixels: of the image drawn to, which
   --  Fit makes the window's size.

   procedure Clear (Item : Renderer; Value : Color);

   procedure Fill_Rect
     (Item : Renderer;
      Value : Color;
      X, Y, Width, Height : Float);

   type Blends is (Solid, Multiply, Add);
   --  How a fill meets what is behind: Solid, as Fill_Rect does; Multiply,
   --  where white takes on the colour and black stays black; Add, where
   --  black takes on the colour and white stays white.

   procedure Fill_Rect
     (Item : Renderer;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float);
   --  The colour's alpha is not used, unless Solid.

   procedure Draw_Line
     (Item : Renderer;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0)
     with Pre => Width > 0.0;
   --  A straight line Width pixels wide, its edges smoothed, blended with
   --  what is behind by the colour's alpha.

   procedure Fill_Circle
     (Item : Renderer;
      Value : Color;
      Centre_X, Centre_Y, Radius : Float)
     with Pre => Radius > 0.0;
   --  A disc, its edge smoothed, blended with what is behind by the
   --  colour's alpha.

   procedure Set_Clip (Item : Renderer; X, Y, Width, Height : Integer)
     with Pre => Width >= 0 and then Height >= 0;
   --  Draw only into the rectangle Width x Height pixels with its top
   --  left at X, Y, until Clear_Clip.

   procedure Clear_Clip (Item : Renderer);
   --  Draw anywhere again.

   --  Clips that nest: to draw into part of a part, whatever clip the
   --  caller has set.

   type Clip is private;
   --  The clip rectangle, or none.

   function Current_Clip (Item : Renderer) return Clip;

   procedure Restore_Clip (Item : Renderer; Value : Clip);
   --  Set the clip to Value, as Current_Clip gave it.

   procedure Narrow_Clip (Item : Renderer; X, Y, Width, Height : Integer)
     with Pre => Width >= 0 and then Height >= 0;
   --  Draw only where the clip allows and in the rectangle Width x Height
   --  pixels with its top left at X, Y, until Restore_Clip.

   procedure Draw_Text
     (Item  : Renderer;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1);
   --  Draw Text with SDL's built-in 8x8 debug font; the result is
   --  Text'Length * Debug_Text_Size * Scale pixels wide.

   procedure Save_BMP (Item : Renderer; File_Name : String);
   --  Write what has been drawn since the last Present to a BMP file,
   --  to see it without looking at the screen. Call before Present.

   procedure Present (Item : Renderer);
   --  Show what is drawn in the window; what was drawn is kept if the
   --  renderer Keeps_Frame.

private

   type Clip is record
      Enabled : Boolean := False;
      X, Y, Width, Height : Integer := 0;
   end record;

   type Renderer is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
      Surface : System.Address := System.Null_Address;
      Canvas  : System.Address := System.Null_Address;
      --  Offscreen, the surface the renderer is made for, and the texture
      --  it draws to: a target texture can be resized, a surface not. In
      --  a window, with Keep_Frame, the texture it draws to, to copy to
      --  the window.
      Canvas_Width, Canvas_Height : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Renderer);

end SDL3.Windows.Renderers;
