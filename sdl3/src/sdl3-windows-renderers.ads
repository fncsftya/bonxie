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
     (Item : in out Renderer; Target : Window; VSync : Boolean := True);
   --  With VSync, Present waits for the display's refresh: no tearing,
   --  and it paces the render loop. Without it frames are as fast as
   --  they can be drawn, as for measuring.

   procedure Create_Offscreen
     (Item : in out Renderer; Width, Height : Positive)
     with Post => Is_Offscreen (Item);
   --  Draw, without a window, into a Width x Height image of its own, in
   --  software: the same drawing gives the same pixels every time, as for
   --  testing. Read them with Images.Read.

   function Is_Offscreen (Item : Renderer) return Boolean;

   procedure Resize (Item : in out Renderer; Width, Height : Positive)
     with Pre => Is_Offscreen (Item);
   --  Make the image Width x Height, losing what is drawn.

   procedure Output_Size
     (Item : Renderer; Width, Height : out Natural);
   --  Size of the drawable area in pixels.

   procedure Clear (Item : Renderer; Value : Color);

   procedure Fill_Rect
     (Item : Renderer;
      Value : Color;
      X, Y, Width, Height : Float);

   procedure Set_Clip (Item : Renderer; X, Y, Width, Height : Integer)
     with Pre => Width >= 0 and then Height >= 0;
   --  Draw only into the rectangle Width x Height pixels with its top
   --  left at X, Y, until Clear_Clip.

   procedure Clear_Clip (Item : Renderer);
   --  Draw anywhere again.

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

private

   type Renderer is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
      Surface : System.Address := System.Null_Address;
      Canvas  : System.Address := System.Null_Address;
      --  Offscreen, the surface the renderer is made for, and the texture
      --  it draws to: a target texture can be resized, a surface not.
   end record;

   overriding procedure Finalize (Item : in out Renderer);

end SDL3.Windows.Renderers;
