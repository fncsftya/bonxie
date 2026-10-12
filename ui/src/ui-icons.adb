with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;

package body UI.Icons is

   package Textures renames SDL3.Windows.Renderers.Textures;

   use Ada.Strings.Unbounded;

   function File_Name (Which : Icon) return String is
     (Ada.Characters.Handling.To_Lower (Icon'Image (Which)) & File_Extension);

   procedure Set_Directory (Item : in out Library; Path : String) is
   begin
      Item.Folder := To_Unbounded_String (Path);
      for Each of Item.Icons loop
         Each.Size := 0;
         Each.Failed := 0;
      end loop;
   end Set_Directory;

   procedure Make
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Size   : Positive;
      Made_It : out Boolean);
   --  Have the icon Size pixels square, if it can be.

   procedure Make
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Size   : Positive;
      Made_It : out Boolean)
   is
      Each : Made renames Item.Icons (Which);
      Path : constant String :=
        To_String (Item.Folder) & "/" & File_Name (Which);
   begin
      Made_It := Each.Size = Size;
      if Made_It or else Each.Failed = Size or else Item.Folder = "" then
         return;
      end if;

      Each.Failed := Size;  --  until it is not
      if Ada.Directories.Exists (Path) then
         Each.Size := 0;
         Textures.Create_Mask_From_SVG (Each.Image, Target, Path, Size, Size);
         Each.Size := Size;
         Each.Failed := 0;
         Made_It := True;
      end if;
   exception
      when Problem : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Could not make icon " & Path & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Make;

   procedure Draw
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Value  : SDL3.Windows.Renderers.Color;
      Left, Top : Float;
      Size   : Positive;
      Drawn  : out Boolean) is
   begin
      Make (Item, Target, Which, Size, Drawn);
      if Drawn then
         Textures.Draw_Tinted
           (Target, Item.Icons (Which).Image, Left, Top, Value);
      end if;
   end Draw;

end UI.Icons;
