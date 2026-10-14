with Ada.Directories;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Items.Marks;
with Items.Words;
with Repository.Item;

package body Items.Sources is

   function Percent (Zoom : Float) return String is
     (Ada.Strings.Fixed.Trim
        (Integer'Image (Integer (Float'Rounding (Zoom * 100.0))),
         Ada.Strings.Both) & "%");

   function To_Slider (Zoom : Float) return Float is
     (Float'Min
        (1.0,
         Float'Max
           (0.0,
            Ada.Numerics.Elementary_Functions.Log (Zoom / Min_Zoom)
            / Ada.Numerics.Elementary_Functions.Log (Max_Zoom / Min_Zoom))));

   function From_Slider (Along : Float) return Float is
     (Float'Min
        (Max_Zoom,
         Float'Max
           (Min_Zoom,
            Float'Rounding
              (100.0 * Min_Zoom
               * Ada.Numerics.Elementary_Functions."**"
                   (Max_Zoom / Min_Zoom, Along)) / 100.0)));

   procedure Set_Zoom
     (Store : in out Projects.Store; Key : Id; Zoom : Zoom_Level) is
   begin
      Repository.Item.Set_Zoom (Store, Key, Zoom);
   end Set_Zoom;

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Id; At_Time : Projects.Seconds) is
   begin
      Repository.Item.Set_Captured (Store, Key, At_Time);
      Words.Clear_Words (Store, Key);
      Marks.Clear_Marks (Store, Key);
   end Set_Captured;

   function Image_Folder
     (Store : Projects.Store; Project : Projects.Id) return String is
     (Projects.Folder (Store, Project) & "/sources");

   function Image_File
     (Store : Projects.Store; Project : Projects.Id; Key : Id) return String
   is
     (Image_Folder (Store, Project) & "/"
      & Ada.Strings.Fixed.Trim (Key'Image, Ada.Strings.Both) & ".png");

   procedure Make_Image_Folder
     (Store : Projects.Store; Project : Projects.Id) is
   begin
      Ada.Directories.Create_Path (Image_Folder (Store, Project));
   end Make_Image_Folder;

end Items.Sources;
