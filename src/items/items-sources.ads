with Projects;

--  What is of a source (an item of Kind Source) alone: how its picture is
--  zoomed, when it was taken, and where it is kept.
package Items.Sources is

   function Percent (Zoom : Float) return String;
   --  A zoom as a whole number of percents, as "150%".

   function To_Slider (Zoom : Float) return Float;
   --  Where a zoom is along a slider, from 0.0 to 1.0. Zooms go by ratios,
   --  so the slider is on a logarithmic scale.

   function From_Slider (Along : Float) return Float
     with Post => From_Slider'Result in Min_Zoom .. Max_Zoom;
   --  The zoom a place along a slider is, to whole percents.

   procedure Set_Zoom
     (Store : in out Projects.Store; Key : Id; Zoom : Zoom_Level)
     with Pre => Projects.Is_Open (Store);
   --  Of a source: how its picture is zoomed within its window.

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Id; At_Time : Projects.Seconds)
     with Pre => Projects.Is_Open (Store);
   --  Say the picture of a source was taken at At_Time. The text found in
   --  the picture before is of another picture: it is forgotten (see
   --  Clear_Words).

   function Image_File
     (Store : Projects.Store; Project : Projects.Id; Key : Id) return String
     with Pre => Projects.Is_Open (Store);
   --  Where the picture of a source is kept, as a PNG file: in the
   --  project's folder (see Projects.Folder), in sources, named for the
   --  item. It does not make the folder: see Make_Image_Folder.

   procedure Make_Image_Folder
     (Store : Projects.Store; Project : Projects.Id)
     with Pre => Projects.Is_Open (Store);

end Items.Sources;
