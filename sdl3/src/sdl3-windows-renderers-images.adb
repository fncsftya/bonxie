with Interfaces.C.Strings;
with System.Storage_Elements;
with SDL3.Errors;

package body SDL3.Windows.Renderers.Images is

   use type System.Address;
   use type Thin.Surface_Access;
   use type System.Storage_Elements.Storage_Offset;

   type RGBA is array (0 .. 3) of Interfaces.Unsigned_8
     with Convention => C;
   --  A pixel as it is in memory.

   procedure Take (Item : in out Image; Surface : Thin.Surface_Access);
   --  Replace Item's surface with Surface, which it then owns.

   procedure Take (Item : in out Image; Surface : Thin.Surface_Access) is
   begin
      Finalize (Item);
      Item.Surface := Surface;
   end Take;

   procedure Adopt
     (Item : in out Image; Found : System.Address; Context : String);
   --  Take a copy of the surface Found in RGBA32, and destroy Found.

   procedure Adopt
     (Item : in out Image; Found : System.Address; Context : String)
   is
      Converted : Thin.Surface_Access;
   begin
      if Found = System.Null_Address then
         Errors.Raise_Last_Error (Context);
      end if;
      Converted := Thin.Convert_Surface (Found, Thin.Pixel_Format_RGBA32);
      Thin.Destroy_Surface (Found);
      if Converted = null then
         Errors.Raise_Last_Error ("SDL_ConvertSurface");
      end if;
      Take (Item, Converted);
   end Adopt;

   procedure Create (Item : in out Image; Columns, Rows : Positive) is
      Made : constant Thin.Surface_Access :=
        Thin.Create_Surface
          (Interfaces.C.int (Columns), Interfaces.C.int (Rows),
           Thin.Pixel_Format_RGBA32);
   begin
      if Made = null then
         Errors.Raise_Last_Error ("SDL_CreateSurface");
      end if;
      Take (Item, Made);
   end Create;

   procedure Read (Item : in out Image; From : Renderer) is
   begin
      Adopt
        (Item, Thin.Render_Read_Pixels (From.Handle, System.Null_Address),
         "SDL_RenderReadPixels");
   end Read;

   procedure Load_PNG (Item : in out Image; File_Name : String) is
      Name   : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (File_Name);
      Loaded : constant Thin.Surface_Access := Thin.Load_PNG (Name);
   begin
      Interfaces.C.Strings.Free (Name);
      Adopt
        (Item, (if Loaded = null then System.Null_Address
                else Loaded.all'Address),
         "SDL_LoadPNG " & File_Name);
   end Load_PNG;

   procedure Save_PNG (Item : Image; File_Name : String) is
      Name  : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (File_Name);
      Saved : constant Interfaces.C.C_bool :=
        Thin.Save_PNG (Item.Surface, Name);
   begin
      Interfaces.C.Strings.Free (Name);
      Errors.Check (Saved, "SDL_SavePNG " & File_Name);
   end Save_PNG;

   function Is_Empty (Item : Image) return Boolean is (Item.Surface = null);

   function Width (Item : Image) return Positive is
     (Positive (Item.Surface.W));
   function Height (Item : Image) return Positive is
     (Positive (Item.Surface.H));

   function Address_Of (Item : Image; X, Y : Natural) return System.Address
   is (Item.Surface.Pixels
       + System.Storage_Elements.Storage_Offset
           (Y * Natural (Item.Surface.Pitch) + 4 * X));

   function Pixel (Item : Image; X, Y : Natural) return Color is
      Found : constant RGBA
        with Import, Address => Address_Of (Item, X, Y);
   begin
      return (Color_Component (Found (0)), Color_Component (Found (1)),
              Color_Component (Found (2)), Color_Component (Found (3)));
   end Pixel;

   procedure Set_Pixel (Item : in out Image; X, Y : Natural; Value : Color)
   is
      Into : RGBA
        with Import, Address => Address_Of (Item, X, Y);
   begin
      Into := [Interfaces.Unsigned_8 (Value.Red),
               Interfaces.Unsigned_8 (Value.Green),
               Interfaces.Unsigned_8 (Value.Blue),
               Interfaces.Unsigned_8 (Value.Alpha)];
   end Set_Pixel;

   overriding procedure Finalize (Item : in out Image) is
   begin
      if Item.Surface /= null then
         Thin.Destroy_Surface (Item.Surface.all'Address);
         Item.Surface := null;
      end if;
   end Finalize;

end SDL3.Windows.Renderers.Images;
