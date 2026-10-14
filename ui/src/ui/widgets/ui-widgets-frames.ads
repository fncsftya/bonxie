with Texts.Documents;
with UI.Widgets.Buttons;
with UI.Widgets.Editors;
with UI.Widgets.Grips;
with UI.Widgets.Labels;
with UI.Widgets.Panels;
with UI.Widgets.Text_Fields;

--  A window of the application's own, over a canvas or in a pane: an
--  outline round a column of a title bar, the content, and a status line
--  with a corner to size it by. The title bar has a square of a colour (the
--  tag), the title, and a button to close it; it is dragged to move the
--  window. A window can also have its title edited in place, and be
--  minimised to a bar in a dock.
--
--  A Frame is the chrome alone. It is built with its content left to the
--  application, which adds that where it belongs (Add_Content,
--  Add_Status_Item, ...), styles it, and says where the window is (Place).
--  It keeps nothing of what the window is for: it says how far the title
--  bar and the corner have been dragged, and which buttons were clicked, as
--  a button says it was (Take_Close), and the application moves and sizes
--  the window.
package UI.Widgets.Frames is

   --  In points

   Outline       : constant Float := 1.0;
   Bar_Height    : constant Float := 28.0;
   Button_Size   : constant Float := 18.0;
   Button_Gap    : constant Float := 4.0;
   Label_Height  : constant Float := 20.0;
   Status_Height : constant Float := 26.0;
   Corner_Size   : constant Float := 18.0;
   --  Of the outline, the title bar, the buttons in it (and the gap
   --  between them), the label of its title, the status line, and the
   --  corner at the right of that.

   type Frame is limited private;

   type Placements is (Floating, Filling);
   --  Floating: placed by its edges (see Place), casting a shadow, with a
   --  corner to size it by. Filling: filling its parent, as a pane does,
   --  with neither.

   procedure Build
     (Item           : in out Frame;
      Parent         : in out Widget'Class;
      Bar            : Themes.Slot;
      Pixels         : Float;
      Placement      : Placements := Floating;
      Editable_Title : Boolean := False;
      Dock           : access Widget'Class := null)
     with Pre => Is_Attached (Parent) and then Pixels > 0.0
                 and then (Dock = null or else Is_Attached (Dock.all));
   --  Add the window's widgets, hidden, to Parent, which is in the tree
   --  already: its title bar and status line, with the corner. Do it once,
   --  before the layout, with the tree's density (Pixels to a point). With Editable_Title the
   --  title can be edited where it is (see Begin_Title_Edit). With a Dock,
   --  a button to minimise it is in the title bar, and a bar for it
   --  is in the Dock, in which it is while it is minimised.

   --  Content: widgets are added in the order they are laid out in.

   procedure Add_Title_Button
     (Item : in out Frame; Button : in out Widget'Class);
   --  After the title, before the button to close it.

   procedure Add_Content
     (Item : in out Frame; Part : in out Widget'Class);
   --  After the title bar, before the status line.

   procedure Add_Status_Item
     (Item : in out Frame; Part : in out Widget'Class);
   --  In the status line, before the corner.

   procedure Add_Over_Content
     (Item : in out Frame; Part : in out Widget'Class);
   --  After the status line: as a menu over the content.

   procedure Add_Over_Status
     (Item : in out Frame; Part : in out Widget'Class);
   --  In the status line, after the corner: over it.

   --  Looks

   procedure Set_Title (Item : in out Frame; To : String);
   --  Show the title (as much as fits), and in the bar in the dock.

   procedure Set_Tag (Item : in out Frame; To : Themes.Slot);
   --  The colour of the square before the title.

   procedure Set_Tag_Visible (Item : in out Frame; To : Boolean);

   procedure Set_Scale (Item : in out Frame; To : Float)
     with Pre => To > 0.0;
   --  Show the title bar and what is in it, and the margin of the title
   --  and the tag, at To times their size (1.0 to begin with): as a
   --  window is smaller, with less in it, when the canvas is zoomed out.

   procedure Set_Status_Visible (Item : in out Frame; To : Boolean);

   procedure Set_Ring (Item : in out Frame; To : Boolean);
   --  Draw a ring round the window in the accent, as of one being typed
   --  in.

   procedure Set_Shown (Item : in out Frame; Window, Docked : Boolean);
   --  Show the window, and the bar in the dock, or not.

   procedure Raise_To_Front (Item : in out Frame);
   --  Put the window over the others.

   procedure Place
     (Item : in out Frame; At_Left, At_Top, Wide, High : Float);
   --  Put the window there, in pixels from the top left of its parent: a
   --  Floating one.

   function Status_Width (Item : Frame; Wide : Float) return Float;
   --  How wide the status line is, in pixels, in a window Wide.

   function Left_Of (Item : Frame) return Float;
   function Top_Of (Item : Frame) return Float;
   function Width_Of (Item : Frame) return Float;
   function Height_Of (Item : Frame) return Float;
   --  Where the window was put, in pixels, as of the last layout.

   function Owns (Item : Frame; Part : Widget_Access) return Boolean;
   --  Whether the widget, or one of those it is in, is the window's.

   function Is_Hovered (Item : Frame) return Boolean;

   --  Taking what was done

   function Is_Dragging (Item : Frame) return Boolean;
   --  Whether the window is being moved or sized.

   function Is_Sizing (Item : Frame) return Boolean;

   procedure Take_Move (Item : in out Frame; Across, Down : out Float);
   --  How far the title bar has been dragged, in points to the right and
   --  down, since this was last called.

   procedure Take_Size (Item : in out Frame; Across, Down : out Float);
   --  How far the corner has been.

   procedure Take_Close (Item : in out Frame; Clicked : out Boolean);
   --  Whether the button to close it, in the window or the bar in the
   --  dock, was clicked.

   procedure Take_Minimize (Item : in out Frame; Clicked : out Boolean);

   procedure Take_Restore (Item : in out Frame; Clicked : out Boolean);
   --  Whether the bar in the dock was clicked, to bring the window back.

   --  The title, edited in place

   procedure Attach_Title
     (Item : in out Frame; Doc : not null Texts.Documents.Document_Access);
   --  Edit the document as the title.

   procedure Share_Title
     (Item   : in out Frame;
      Shared : not null Editors.Shared_Access);
   --  Direct its editor to share the font registry and glyph atlas.

   function Is_Editing_Title (Item : Frame) return Boolean;
   --  Whether the title is a field to type in, rather than text.

   function Title_Has_Focus (Item : Frame) return Boolean;

   procedure Begin_Title_Edit (Item : in out Frame)
     with Pre => not Is_Editing_Title (Item);
   --  Make the title a field, with all of it selected, to type over.

   procedure End_Title_Edit (Item : in out Frame)
     with Post => not Is_Editing_Title (Item);
   --  Make it text again, as it has been edited.

   procedure Reset_Title_Edit (Item : in out Frame);
   --  As End_Title_Edit, but nothing is shown of the title: for when the
   --  window is given another.

   procedure Take_Title_Double_Click
     (Item : in out Frame; Doubled : out Boolean);

   procedure Take_Title_Return (Item : in out Frame; Entered : out Boolean);
   --  Whether Return was pressed in the field.

private

   type Frame is limited record
      Pixels    : Float := 1.0;
      Scale     : Float := 1.0;
      Editable  : Boolean := False;
      Docked    : Boolean := False;
      Floating  : Boolean := True;
      Editing   : Boolean := False;

      Outline_Panel : Panels.Panel;
      --  On the canvas: the outline, round the bar, the content and the
      --  status line.
      Title_Bar     : Grips.Grip;
      Title_Area    : Grips.Grip;
      Tag           : Panels.Panel;
      Title_Label   : Labels.Label;
      Title_Field   : Text_Fields.Text_Field;
      Spacer        : Panels.Panel;
      Minimize_Button : Buttons.Button;
      Close_Button  : Buttons.Button;
      Status_Bar    : Panels.Panel;
      Corner        : Grips.Grip;

      Mini          : Panels.Panel;
      --  In the dock.
      Mini_Area     : Grips.Grip;
      Mini_Title    : Labels.Label;
      Mini_Close    : Buttons.Button;
   end record;

end UI.Widgets.Frames;
