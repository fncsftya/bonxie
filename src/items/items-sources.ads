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

   procedure Set_Document
     (Store      : in out Projects.Store;
      Key        : Id;
      Document   : String;
      Page_Count : Natural)
     with Pre => Projects.Is_Open (Store);
   --  Say the source is a document of that ending (as "pdf"), of
   --  Page_Count pages, at its first; or, with "" and 0, a web page.

   procedure Set_Origin
     (Store : in out Projects.Store; Key : Id; Origin : Origins)
     with Pre => Projects.Is_Open (Store);
   --  Say whether the source is a link or a file (see Origins).

   function Is_Vector (Document : String) return Boolean;
   --  Whether a document of this ending is shown page by page as shapes
   --  and text (see Items.Vector_Pages): a PDF.

   function Is_Text (Document : String) return Boolean;
   --  Whether a document with that ending is plain text, shown as text,
   --  not drawn as a picture.

   function Read_Text (File_Name : String) return String;
   --  What is in a text file, to be shown: as much of it as Max_Text
   --  bytes, as UTF-8 (a byte that is not is replaced by U+FFFD), with
   --  line feeds only (a CR LF, or a CR alone, is one).

   Max_Text : constant := 1_000_000;

   procedure Copy_File (From, To : String);
   --  Make To a copy of From, written beside it and then put in its place.
   --  Use_Error if it cannot be.

   procedure Convert_Image (From, To : String);
   --  Convert a system-supported image file to PNG. Use_Error if it cannot.

   procedure Set_Page (Store : in out Projects.Store; Key : Id; Page : Positive)
     with Pre => Projects.Is_Open (Store);
   --  Say which page of its document the source's picture is of. The
   --  picture is another: see Set_Captured.

   function Document_File
     (Store    : Projects.Store;
      Project  : Projects.Id;
      Key      : Id;
      Document : String) return String
     with Pre => Projects.Is_Open (Store);
   --  Where the file of a source that is a PDF or e-book is kept: beside
   --  its picture (see Image_File), with its ending.

   function Shown_File
     (Store : Projects.Store; Project : Projects.Id; Of_Item : Info) return String
     with Pre => Projects.Is_Open (Store);
   --  What a source's window shows: the text file of one that is a text,
   --  else its picture.

   procedure Delete_Files
     (Store : Projects.Store; Project : Projects.Id; Key : Id)
     with Pre => Projects.Is_Open (Store);
   --  Throw away the picture of a source, and its document if it has one.

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
