with System;
with Items.Marks;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Texts.Documents;
with Pomarine.Widgets.Frames;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pictures;
with Pomarine.Widgets.Sliders;
with Items.Vector_Pages;
with Pomarine.Pages;
with Pomarine.Widgets.Page_Views;
with Vision;

--  What shows a source in the writing view: the picture of its page, in a
--  window to drag by its title bar and size by its corner, with a status
--  line of the tools to mark it with (the cursor, the highlighter and the
--  eraser) and a slider to zoom it; or, pinned, in the pane at the
--  right, to fill that. It is of one item at a time, or of none.
--
--  It is not the item's window on the canvas (see Items.Windows), and
--  keeps nothing of its own in the database: where it is, whether it is
--  open, how it is zoomed and scrolled are for this view only. The
--  highlights are the item's, shown on the picture here as there: the
--  application keeps them the same (Marks_Version, Get_Marks, Set_Marks).
package Items.Readers is

   use type Pomarine.Widgets.Pictures.Tools;

   type Reader is limited private;

   type Actions is (None, Close, Toggle_Pin, Visit);
   --  What a reader's buttons ask for. Toggle_Pin pins a window, and lets
   --  go of the pinned one. Visit asks to open the source's page in the
   --  browser.

   Window_Width  : constant Float := 380.0;
   Window_Height : constant Float := 440.0;
   Least_Width      : constant Float := 240.0;
   Least_Height     : constant Float := 180.0;
   --  Of a window, in points.

   procedure Build
     (Item    : in out Reader;
      Parent  : in out Pomarine.Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float;
      Pinned  : Boolean := False);
   --  Add the reader's widgets, hidden, to Parent, which is in the tree
   --  already: a window placed by its edges in it, or, if Pinned, a
   --  column that fills it. Do it once, before the layout, with the
   --  tree's density.

   procedure Set_Pinnable (Item : in out Reader; To : Boolean);
   --  Show the pin button of the title bar, or not: a reader that is not for
   --  the writing view's pane (a preview) has no use for it. Shown to begin with.

   procedure Set_Visitable (Item : in out Reader; To : Boolean);
   --  Show the "Visit Source" button at the right of the status line, or not.
   --  Hidden to begin with.

   procedure Set_Tag (Item : in out Reader; To : Pomarine.Themes.Slot);
   --  Show the source's colour, in a square before its title.

   function Is_Assigned (Item : Reader) return Boolean;

   procedure Assign
     (Item         : in out Reader;
      Of_Item      : Items.Info;
      Where        : Items.Frame;
      Picture_File : String := "")
     with Pre => not Is_Assigned (Item) and then Of_Item.Kind = Source;
   --  Make it the reader of the source, closed, to be put at Where. A
   --  source that has been captured shows Picture_File, a PNG.

   procedure Release (Item : in out Reader)
     with Post => not Is_Assigned (Item);
   --  Hide it, and forget the item.

   function Details (Item : Reader) return Items.Info
     with Pre => Is_Assigned (Item);
   --  Its title, where its window is, and whether it is open: Open or
   --  Closed (a pinned reader is open while it is pinned). The zoom is
   --  its own.

   procedure Set_State (Item : in out Reader; To : States)
     with Pre  => Is_Assigned (Item) and then To /= Minimized,
          Post => Details (Item).State = To;
   --  Show it, or not. A picture is let go of while it is not shown.

   procedure Set_Title (Item : in out Reader; To : String)
     with Pre => Is_Assigned (Item);

   procedure Set_Document
     (Item : in out Reader; Document : String; Page, Count : Natural)
     with Pre => Is_Assigned (Item);
   --  Say the source is a file of that ending ("" for a web page), and
   --  its picture is of its Page'th of Count pages: as a text file, it is
   --  shown as text, to be read and selected, not as a picture (see
   --  Set_Picture). Do it before Set_Picture.

   procedure Go_To_Page (Item : in out Reader; Page : Positive)
     with Pre => Is_Assigned (Item);
   --  Of a document shown as pages one under another, scroll to the page;
   --  nothing is done for one that is not.

   procedure Follow_Page (Item : in out Reader)
     with Pre => Is_Assigned (Item);
   --  Of such a document, say in the status which page is being read, as
   --  it is scrolled.

   procedure Set_Picture
     (Item : in out Reader; File : String; At_Time : Projects.Seconds)
     with Pre => Is_Assigned (Item) and then File /= "";
   --  Show the PNG File, as taken at At_Time: the words and highlights of
   --  the picture before are forgotten. Of a text file (see
   --  Set_Document), File is the text file, and its text is shown.

   procedure Set_Recognized
     (Item : in out Reader; Found : Vision.Result)
     with Pre => Is_Assigned (Item);
   --  Say what words are in the picture, to be selected as text over it.

   function Recognized_Count (Item : Reader) return Natural
     with Pre => Is_Assigned (Item);

   function Selected_Text (Item : Reader) return String
     with Pre => Is_Assigned (Item);

   function Picture_Contains
     (Item : Reader; X, Y : Float) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether pixel X, Y is in its picture.

   function Is_Over_Selection
     (Item : Reader; X, Y : Float) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether pixel X, Y is over a selected word of its picture.

   function Has_Words (Item : Reader) return Boolean
     with Pre => Is_Assigned (Item);

   procedure Select_All (Item : in out Reader)
     with Pre => Is_Assigned (Item);
   --  Select all the words of its picture.

   procedure Copy (Item : Reader)
     with Pre => Is_Assigned (Item);
   --  Put the selected words on the clipboard.

   function Marks_Version (Item : Reader) return Natural
     with Pre => Is_Assigned (Item);

   function Is_Marking (Item : Reader) return Boolean
     with Pre => Is_Assigned (Item);

   procedure Get_Marks (Item : Reader; Into : out Items.Marks.Mark_List)
     with Pre => Is_Assigned (Item);

   procedure Set_Marks (Item : in out Reader; Kept : Items.Marks.Mark_List)
     with Pre => Is_Assigned (Item);

   function Tool (Item : Reader) return Pomarine.Widgets.Pictures.Tools
     with Pre => Is_Assigned (Item);

   procedure Select_Tool
     (Item : in out Reader; To : Pomarine.Widgets.Pictures.Tools)
     with Pre => Is_Assigned (Item), Post => Tool (Item) = To;

   function Zoom (Item : Reader) return Float
     with Pre => Is_Assigned (Item);

   procedure Set_Zoom (Item : in out Reader; To : Float)
     with Pre  => Is_Assigned (Item)
                  and then To in Items.Min_Zoom .. Items.Max_Zoom,
          Post => Zoom (Item) = To;

   function Box (Item : Reader) return Items.Frame
     with Pre => Is_Assigned (Item);
   --  Where its window is on the screen, in pixels, as of the last layout.

   procedure Place (Item : in out Reader)
     with Pre => Is_Assigned (Item);
   --  Put the window of a reader that is not pinned where it is, in
   --  points from the top left of its parent.

   procedure Set_Frame (Item : in out Reader; Where : Items.Frame)
     with Pre => Is_Assigned (Item);
   --  Put the window at Where, in points from the top left of its parent,
   --  no smaller than it may be.

   procedure Bring_To_Front (Item : in out Reader)
     with Pre => Is_Assigned (Item);

   function Is_Dragging (Item : Reader) return Boolean;
   --  Whether it is being moved or sized.

   procedure Update (Item : in out Reader)
     with Pre => Is_Assigned (Item);
   --  Raise it when it is used. What the buttons, the corner and the bar
   --  say is done as it is said, and what is for the application is told
   --  to it (see Items.Readers.Callbacks).

private

   type Said_Runner is access procedure
     (Self, Proc : System.Address; Which : Natural; Action : Actions);

   type Reader is limited record
      Assigned : Boolean := False;
      Said      : Said_Runner;
      Said_Self : System.Address := System.Null_Address;
      Said_Proc : System.Address := System.Null_Address;
      Said_Which : Natural := 0;
      --  Who is told what its buttons ask for.
      Pinned   : Boolean := False;
      Details  : Items.Info;
      Pixels   : Float := 1.0;
      Was_Used : Boolean := False;
      Resizing : Boolean := False;
      Raw_Width, Raw_Height : Float := 0.0;
      --  While the corner is dragged, the size the cursor asks for, which
      --  may be under the minimum; the window is held at the minimum.
      Recognized : aliased Vision.Result;
      --  The words in the picture, that it lets be selected.
      Pages      : Pomarine.Widgets.Page_Views.Page_View;
      Paged      : Boolean := False;
      --  Of a document, its pages one under another, in place of Picture.
      Doc_Sizes  : Pomarine.Pages.Size_Array_Access;
      Doc_Source : aliased Items.Vector_Pages.File_Source;

      Chrome      : Pomarine.Widgets.Frames.Frame;
      --  Its tag is a square of the source's colour before the title.
      Pin_Button  : Pomarine.Widgets.Buttons.Button;
      Picture     : Pomarine.Widgets.Pictures.Picture;
      Text_Doc    : aliased Texts.Documents.Document;
      Text_View   : Pomarine.Widgets.Editors.Editor;
      --  Of a source that is a text file, in place of the picture.
      Tools       : Pomarine.Widgets.Panels.Panel;
      Cursor_Button : Pomarine.Widgets.Buttons.Button;
      Marker_Button : Pomarine.Widgets.Buttons.Button;
      Eraser_Button : Pomarine.Widgets.Buttons.Button;
      Visit_Button  : Pomarine.Widgets.Buttons.Button;
      Zoom_Slider : Pomarine.Widgets.Sliders.Slider;
      Zoom_Label  : Pomarine.Widgets.Labels.Label;
      Status      : Pomarine.Widgets.Labels.Label;
   end record;

end Items.Readers;
