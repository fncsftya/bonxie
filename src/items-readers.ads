with UI.Themes;
with UI.Widgets.Buttons;
with UI.Widgets.Grips;
with UI.Widgets.Labels;
with UI.Widgets.Panels;
with UI.Widgets.Pictures;
with UI.Widgets.Sliders;
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

   use type UI.Widgets.Pictures.Tools;

   type Reader is limited private;

   type Reader_Array is array (Slot) of Reader;

   type Actions is (None, Close, Toggle_Pin);
   --  What a reader's buttons ask for. Toggle_Pin pins a window, and lets
   --  go of the pinned one.

   Window_Width  : constant Float := 380.0;
   Window_Height : constant Float := 440.0;
   Least_Width      : constant Float := 240.0;
   Least_Height     : constant Float := 180.0;
   --  Of a window, in points.

   procedure Build
     (Item    : in out Reader;
      Parent  : in out UI.Widgets.Widget'Class;
      Colors  : UI.Themes.Theme;
      Bar     : UI.Themes.Color;
      Density : Float;
      Pinned  : Boolean := False);
   --  Add the reader's widgets, hidden, to Parent, which is in the tree
   --  already: a window placed by its edges in it, or, if Pinned, a
   --  column that fills it. Do it once, before the layout, with the
   --  tree's density.

   procedure Set_Tag (Item : in out Reader; To : UI.Themes.Color);
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

   procedure Set_Picture
     (Item : in out Reader; File : String; At_Time : Projects.Seconds)
     with Pre => Is_Assigned (Item) and then File /= "";
   --  Show the PNG File, as taken at At_Time: the words and highlights of
   --  the picture before are forgotten.

   procedure Set_Recognized
     (Item : in out Reader; Found : Vision.Result)
     with Pre => Is_Assigned (Item);
   --  Say what words are in the picture, to be selected as text over it.

   function Recognized_Count (Item : Reader) return Natural
     with Pre => Is_Assigned (Item);

   function Selected_Text (Item : Reader) return String
     with Pre => Is_Assigned (Item);

   function Marks_Version (Item : Reader) return Natural
     with Pre => Is_Assigned (Item);

   function Is_Marking (Item : Reader) return Boolean
     with Pre => Is_Assigned (Item);

   procedure Get_Marks (Item : Reader; Into : out Items.Mark_List)
     with Pre => Is_Assigned (Item);

   procedure Set_Marks (Item : in out Reader; Kept : Items.Mark_List)
     with Pre => Is_Assigned (Item);

   function Tool (Item : Reader) return UI.Widgets.Pictures.Tools
     with Pre => Is_Assigned (Item);

   procedure Select_Tool
     (Item : in out Reader; To : UI.Widgets.Pictures.Tools)
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

   procedure Poll (Item : in out Reader; Action : out Actions)
     with Pre => Is_Assigned (Item);
   --  Move and size it as dragged, raise it when it is used, and say
   --  which button was clicked, if any.

private

   type Reader is limited record
      Assigned : Boolean := False;
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

      Frame       : UI.Widgets.Panels.Panel;
      Title_Bar   : UI.Widgets.Grips.Grip;
      Tag         : UI.Widgets.Panels.Panel;
      --  Before the title: a square of the source's colour.
      Title_Label : UI.Widgets.Labels.Label;
      Pin_Button  : UI.Widgets.Buttons.Button;
      Close_Button : UI.Widgets.Buttons.Button;
      Picture     : UI.Widgets.Pictures.Picture;
      Status_Bar  : UI.Widgets.Panels.Panel;
      Tools       : UI.Widgets.Panels.Panel;
      Cursor_Button : UI.Widgets.Buttons.Button;
      Marker_Button : UI.Widgets.Buttons.Button;
      Eraser_Button : UI.Widgets.Buttons.Button;
      Zoom_Slider : UI.Widgets.Sliders.Slider;
      Zoom_Label  : UI.Widgets.Labels.Label;
      Status      : UI.Widgets.Labels.Label;
      Corner      : UI.Widgets.Grips.Grip;
   end record;

end Items.Readers;
