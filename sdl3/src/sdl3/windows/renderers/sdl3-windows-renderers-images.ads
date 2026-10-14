private with Ada.Finalization;
private with SDL3.Thin;

--  Images in memory, eight bits a channel: what a renderer has drawn,
--  and PNG files.
package SDL3.Windows.Renderers.Images is

   type Image is limited private;

   procedure Create (Item : in out Image; Columns, Rows : Positive)
     with Post => not Is_Empty (Item);
   --  Replace Item with a transparent black image Columns x Rows.

   procedure Read (Item : in out Image; From : Renderer)
     with Post => not Is_Empty (Item);
   --  Replace Item with what From has drawn since it last presented.

   procedure Load_PNG (Item : in out Image; File_Name : String)
     with Post => not Is_Empty (Item);

   procedure Save_PNG (Item : Image; File_Name : String)
     with Pre => not Is_Empty (Item);

   function Is_Empty (Item : Image) return Boolean;

   function Width (Item : Image) return Positive
     with Pre => not Is_Empty (Item);
   function Height (Item : Image) return Positive
     with Pre => not Is_Empty (Item);

   function Pixel (Item : Image; X, Y : Natural) return Color
     with Pre => not Is_Empty (Item)
                 and then X < Width (Item) and then Y < Height (Item);
   --  X across and Y down from the top left.

   procedure Set_Pixel (Item : in out Image; X, Y : Natural; Value : Color)
     with Pre => not Is_Empty (Item)
                 and then X < Width (Item) and then Y < Height (Item);

private

   type Image is new Ada.Finalization.Limited_Controlled with record
      Surface : Thin.Surface_Access;  --  RGBA32
   end record;

   overriding procedure Finalize (Item : in out Image);

end SDL3.Windows.Renderers.Images;
