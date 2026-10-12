with Projects;
with SDL3.Events;
with Texts.Documents;
with UI.Themes;
with UI.Widgets.Buttons;
with UI.Widgets.Grips;
with UI.Widgets.Labels;
with UI.Widgets.Panels;
with UI.Widgets.Text_Fields;
with UI.Widgets.Editors;

--  What shows one item: a window on the canvas, which can be dragged by
--  its title bar and sized by its corner, with a title to edit, buttons to
--  minimise and close it, its text to edit, and a status line; and, when
--  it is minimised, a short bar in the dock above the tools.
--
--  A window is of one item at a time, or of none. It keeps the item's
--  details, and what has to be written to the database (see Flush); it
--  says what the buttons have asked for, to be taken (Poll), and the
--  application does it. Zoom and pan are the canvas's: it is told them
--  (Place) and puts the window there; the window's text is zoomed with
--  the canvas, its title bar and status line are not.
package Items.Windows is

   type Window is limited private;

   type Window_Array is array (Slot) of Window;

   type Actions is (None, Minimize, Restore, Close);
   --  What a window's buttons ask for.

   Idle_Delay : constant := 500;
   --  Milliseconds the text is left alone for before it is written,
   --  although it is still being typed in.

   function Count_Words (Of_Text : String) return Natural;
   --  Of runs of anything but spaces, tabs and line breaks.

   procedure Build
     (Item    : in out Window;
      Canvas  : in out UI.Widgets.Widget'Class;
      Dock    : in out UI.Widgets.Widget'Class;
      Colors  : UI.Themes.Theme;
      Bar     : UI.Themes.Color;
      Density : Float);
   --  Add the window's widgets, hidden: its window to the canvas, its
   --  bar to the dock, both in the tree already. Do it once, before the
   --  layout, with the tree's density.

   function Is_Assigned (Item : Window) return Boolean;

   procedure Assign
     (Item       : in out Window;
      Of_Item    : Items.Info;
      Saved_Text : String)
     with Pre => not Is_Assigned (Item);
   --  Make it the window of the item, with its text Saved_Text, as saved:
   --  shown as its state says, once it is placed.

   procedure Release (Item : in out Window)
     with Post => not Is_Assigned (Item);
   --  Hide it, and forget the item: whatever was not written is lost.

   function Details (Item : Window) return Items.Info
     with Pre => Is_Assigned (Item);
   --  As the window has it now: the title as edited, where it has been
   --  moved and sized to.

   function Text (Item : Window) return String
     with Pre => Is_Assigned (Item);

   function Words (Item : Window) return Natural
     with Pre => Is_Assigned (Item);

   procedure Set_State (Item : in out Window; To : States)
     with Pre => Is_Assigned (Item), Post => Details (Item).State = To;
   --  Show it as a window, as a bar in the dock, or not at all. Writing
   --  it is for the application.

   procedure Place
     (Item : in out Window; Zoom, Origin_X, Origin_Y : Float)
     with Pre => Zoom > 0.0;
   --  Put it where the canvas, which is at Zoom with its origin at
   --  Origin_X, Origin_Y points from its top left, has it.

   procedure Bring_To_Front (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Put its window over the others on the canvas.

   function Is_Editing_Title (Item : Window) return Boolean;
   --  Whether the title is a field to type in, rather than text: it
   --  becomes one when it is double-clicked, and text again when Return
   --  is pressed, or the focus goes elsewhere.

   procedure Focus_Text (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Give the text the focus, at its start.

   procedure Poll (Item : in out Window; Action : out Actions)
     with Pre => Is_Assigned (Item);
   --  Move and size it as dragged, raise it when it is used, keep the
   --  title and word count as edited, and say which button was clicked,
   --  if any.

   function Is_Dragging (Item : Window) return Boolean;
   --  Whether it is being moved or sized.

   procedure Flush
     (Item  : in out Window;
      Store : in out Projects.Store;
      Now   : SDL3.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
     with Pre => Is_Assigned (Item) and then Projects.Is_Open (Store);
   --  Write to the database what has changed: where it has been put, once
   --  it is let go; the title and text, once they are no longer being
   --  typed in, or have not changed for Idle_Delay, or whenever Force.
   --  Wrote says whether anything was written. Now is as
   --  SDL3.Events.Ticks.

private

   package Docs renames Texts.Documents;

   type Window is limited record
      Assigned : Boolean := False;
      Details  : Items.Info;
      Title_Doc    : aliased Docs.Document;
      Content_Doc  : aliased Docs.Document;
      --  Before the widgets that show them.
      Title_Saved   : Natural := 0;
      Content_Saved : Natural := 0;
      --  The states of the documents when they were written.
      Title_Seen    : Natural := 0;
      Content_Seen  : Natural := 0;
      Changed_At    : SDL3.Events.Milliseconds := 0;
      --  The last time either was seen to differ from what it was.
      Title_Version : Docs.Version := 0;
      Content_Version : Docs.Version := 0;
      Word_Count    : Natural := 0;
      Frame_Dirty   : Boolean := False;
      --  Moved or sized, and not written.
      Was_Used      : Boolean := False;
      Pixels : Float := 1.0;
      Zoom, Origin_X, Origin_Y : Float := 1.0;
      Placed_Once : Boolean := False;

      Frame        : UI.Widgets.Panels.Panel;
      --  On the canvas: the outline, round the bar, the text and the
      --  status line.
      Title_Bar    : UI.Widgets.Grips.Grip;
      Title_Area   : UI.Widgets.Grips.Grip;
      Title_Label  : UI.Widgets.Labels.Label;
      --  The title as text, in the place the field takes to edit it.
      Editing      : Boolean := False;
      Title_Field  : UI.Widgets.Text_Fields.Text_Field;
      Spacer       : UI.Widgets.Panels.Panel;
      Minimize_Button : UI.Widgets.Buttons.Button;
      Close_Button : UI.Widgets.Buttons.Button;
      Body_Text    : UI.Widgets.Editors.Editor;
      Status_Bar   : UI.Widgets.Panels.Panel;
      Status       : UI.Widgets.Labels.Label;
      Corner       : UI.Widgets.Grips.Grip;

      Mini         : UI.Widgets.Panels.Panel;
      --  In the dock.
      Mini_Title   : UI.Widgets.Labels.Label;
      Restore_Button : UI.Widgets.Buttons.Button;
      Mini_Close   : UI.Widgets.Buttons.Button;
   end record;

end Items.Windows;
