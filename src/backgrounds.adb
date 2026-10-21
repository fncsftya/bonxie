with Ada.Exceptions;
with Ada.Text_IO;
with Files;
with Interfaces.C;

package body Backgrounds is

   use type System.Address;
   use type SDL3.Painters.Device_Access;
   package Textures renames SDL3.Windows.Renderers.Textures;

   function Time_Seed return Interfaces.C.C_float
     with Import, Convention => C, External_Name => "bonxie_background_seed";

   function Create (Source : Interfaces.C.char_array) return System.Address
     with Import, Convention => C, External_Name => "bonxie_background_create";

   function Render
     (Native : System.Address;
      Seed : Interfaces.C.C_float;
      Width, Height : Interfaces.C.int) return System.Address
     with Import, Convention => C, External_Name => "bonxie_background_render";

   procedure Release (Native : System.Address)
     with Import, Convention => C, External_Name => "bonxie_background_release";

   overriding procedure Finalize (Item : in out Cache) is
   begin
      Release (Item.Native);
      Item.Native := System.Null_Address;
   end Finalize;

   procedure Set_Shader (Item : in out Cache; File_Name : String) is
   begin
      Finalize (Item);
      Textures.Release (Item.Image);
      Item.Native := Create (Interfaces.C.To_C (Files.Read (File_Name)));
      Item.Seed := Float (Time_Seed);
      Item.Wide := 0;
      Item.High := 0;
      Item.Failed := Item.Native = System.Null_Address;
   exception
      when Problem : others =>
         Item.Failed := True;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "Watercolour background: " & Ada.Exceptions.Exception_Message (Problem));
   end Set_Shader;

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme)
   is
      use Pomarine.Widgets;
      Device : constant SDL3.Painters.Device_Access := Target.Device;
      Wide, High : Natural;
   begin
      Pomarine.Widgets.Panels.Panel (Item).Draw (Target, Colors);
      if Item.Painting = null or else Device = null then
         return;
      end if;
      declare
         Saved : Cache renames Item.Painting.all;
      begin
         if Saved.Failed or else Saved.Native = System.Null_Address then
            return;
         end if;
         Target.Output_Size (Wide, High);
         if Wide = 0 or else High = 0 then
            return;
         end if;
         if Wide /= Saved.Wide or else High /= Saved.High then
            declare
               --  Metal owns the full-size staging buffer; no image-sized
               --  allocation on the Ada stack and no internal resolution cap.
               Pixels : constant System.Address := Render
                 (Saved.Native, Interfaces.C.C_float (Saved.Seed),
                  Interfaces.C.int (Wide), Interfaces.C.int (High));
            begin
               if Pixels = System.Null_Address
               then
                  Saved.Failed := True;
                  Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Could not render watercolour background");
                  return;
               end if;
               Textures.Create_Blank (Saved.Image, Device.all, Wide, High, Smooth => False);
               Textures.Update_Region (Saved.Image, 0, 0, Wide, High, Pixels, 4 * Wide);
               Saved.Wide := Wide;
               Saved.High := High;
            end;
         end if;
         pragma Assert (not Textures.Is_Empty (Saved.Image));
         Target.Draw_Scaled
           (Saved.Image, Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
         if Item.Dark then
            Target.Fill_Rect
              ((0, 0, 0, 175), Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
         end if;
      end;
   end Draw;

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme)
   is
      Palette : Pomarine.Themes.Theme := Colors;
   begin
      if Item.Transparent then
         Palette.Slots (Pomarine.Themes.Background).Alpha := 0;
      end if;
      Pomarine.Widgets.Canvases.Canvas (Item).Draw (Target, Palette);
   end Draw;

end Backgrounds;
