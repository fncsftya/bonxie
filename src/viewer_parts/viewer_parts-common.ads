with SDL3.Windows.Renderers;
with Projects;
with SDL3.Cursors;
with Ada.Strings.Unbounded;
with Items;
with Projects.Sections;
with SDL3.Windows;
with Scripts;
with Typeset.Views;
with Pomarine.Accessibility;
with Pomarine.Clipboards;
with Pomarine.Native_Menus;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Widgets;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;

--  What the other parts of a viewer's session share, and the small parts of it.
package Viewer_Parts.Common is

   type Slot_Array is array (Items.Slot) of Items.Slot;

   type Dir_Array is array (Items.Slot) of Natural;

   type Sync_State is record
      Own, Peer : Natural := 0;
   end record;
   --  Of a reader's highlights: the version of its picture's, and of its
   --  window's on the canvas, when they were last made the same.

   type Sync_Array is array (Items.Slot) of Sync_State;

   type Placed_Array is array (Items.Slot) of Boolean;

   type Root_Parts is limited record
      Widgets      : Pomarine.Widgets.Tree;
      Window_Panel : Pomarine.Widgets.Panels.Panel;
      --  The root, of both screens, one of which is hidden.
      Header_Panel : Pomarine.Widgets.Panels.Panel;
      Header_Title : Pomarine.Widgets.Labels.Label;
      --  Across the top of a window, where its title bar was: under the
      --  window's own buttons.
   end record;
   --  The tree of widgets and the panels at the top of both screens.

   type Host_Resources is limited record
      Script       : aliased Scripts.Script;
      Win          : SDL3.Windows.Window;
      Assistive    : Pomarine.Accessibility.Adapter;
      Menus        : Pomarine.Native_Menus.Menu_Bar;
      --  after Win: it is let go of the window first
      Target       : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Pictures     : aliased Pomarine.Icons.Library;
      --  after Target, which it draws to
      Lines        : aliased Pomarine.Line_Texts.Drawer;
      --  after Target, which it draws to
      Doc_Resources : aliased Typeset.Views.Shared_Resources;
      --  after Target, which its atlas draws to
   end record;
   --  The text, the window and what draws to it: declared in the order they
   --  are destroyed in, the last first.

   Section_Capacity : constant := Projects.Sections.Max_Sections;

   type Opened_State is limited record
      Current      : Projects.Id := 0;
      --  The project shown, at the project screen.
      Project_Name : Ada.Strings.Unbounded.Unbounded_String;
      --  Its name, for the window's title.
   end record;
   --  The project shown.

   type Shell_State is limited record
      Density      : Float := 1.0;
      --  Pixels to a point of the window.

      Shown_Cursor : SDL3.Cursors.Kind := SDL3.Cursors.Default;
      --  The one the window has been given.

      Shown_Title  : Ada.Strings.Unbounded.Unbounded_String;

      Windowed     : Boolean := False;
      Moving       : Boolean := False;
      --  Whether a press on the bar is moving the window, from where the
      --  pointer and the window were when it was pressed.
      Grab_X, Grab_Y       : Float := 0.0;
      Grab_Left, Grab_Top  : Integer := 0;
      System_Board : Pomarine.Clipboards.System_Clipboard;
      Own_Board    : Pomarine.Clipboards.Memory_Clipboard;
      --  The clipboard used offscreen.

      Done         : Boolean := False;
   end record;
   --  The window as the system has it, and the clipboards.

end Viewer_Parts.Common;
