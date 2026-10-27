with Ada.Finalization;
with Backgrounds;
with Pomarine.UI;
with SDL3.Windows.Renderers;
with SDL3.Cursors;
with Ada.Strings.Unbounded;
with Canvas_VM;
with Growing;
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

package View_Parts.Common is

   package Slot_Lists renames Canvas_VM.Slot_Lists;
   subtype Slot_Array is Slot_Lists.List;
   --  Slots (of windows), in some order; sized to the slots there are.

   type Sync_State is record
      Own, Peer : Natural := 0;
   end record;
   --  Of a reader's highlights: the version of its picture's, and of its
   --  window's on the canvas, when they were last made the same.

   package Sync_Lists is new Growing (Sync_State);
   subtype Sync_Array is Sync_Lists.List;

   package Placed_Lists is new Growing (Boolean);
   subtype Placed_Array is Placed_Lists.List;

   type Screen_Access is access Pomarine.UI.View;

   type Screen_Holder is new Ada.Finalization.Limited_Controlled with record
      Screen : Screen_Access;
   end record;
   --  A view of a screen's controls (Pomarine.UI), made when the screen is built: its tree is the session's,
   --  which a component of the session cannot name as a discriminant. Declare it last of the screen's parts,
   --  so that it goes first, with its panels out of the others'.

   overriding
   procedure Finalize (Item : in out Screen_Holder);

   type Form_Kinds is
     (Settings_Region,
      Confirm_Region,
      List_Region,
      Home_Region,
      Project_Region,
      Tray_Region,
      Publish_Region,
      Outline_Region,
      Search_Region,
      Writing_Region,
      Canvas_Region,
      Grammar_Region,
      Header_Region,
      Browser_Region);
   --  The views of the session's controls (Pomarine.UI), one for each region of the window.

   type Form_Array is array (Form_Kinds) of Screen_Holder;

   function Tag_Base (Kind : Form_Kinds) return Positive
   is (10_000 * (Form_Kinds'Pos (Kind) + 1));
   --  The tags of a form's commands begin here: clear of the ones the session's own models have, and of
   --  the other forms'.

   procedure Open (Holder : in out Screen_Holder; Tree : not null access Pomarine.Widgets.Tree; Kind : Form_Kinds);
   --  Make the view of a region's controls, with its tags from Tag_Base (before any control is made).

   type Root_Parts is limited record
      Widgets      : aliased Pomarine.Widgets.Tree;
      Window_Panel : Backgrounds.Panel;
      --  The root, of both screens, one of which is hidden.
      Header_Panel : Pomarine.Widgets.Panels.Panel;
      Header_Title : Pomarine.Widgets.Labels.Label;
      --  Across the top of a window, where its title bar was: under the
      --  window's own buttons.
   end record;
   --  The tree of widgets and the panels at the top of both screens.

   type Host_Resources is limited record
      Script        : aliased Scripts.Script;
      Win           : SDL3.Windows.Window;
      Assistive     : Pomarine.Accessibility.Adapter;
      Menus         : Pomarine.Native_Menus.Menu_Bar;
      --  after Win: it is let go of the window first
      Target        : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Background    : aliased Backgrounds.Cache;
      Pictures      : aliased Pomarine.Icons.Library;
      --  after Target, which it draws to
      Lines         : aliased Pomarine.Line_Texts.Drawer;
      --  after Target, which it draws to
      Doc_Resources : aliased Typeset.Views.Shared_Resources;
      --  after Target, which its atlas draws to
   end record;
   --  The text, the window and what draws to it: declared in the order they
   --  are destroyed in, the last first.

   type Shell_State is limited record
      Density : Float := 1.0;
      --  Pixels to a point of the window.

      Shown_Cursor : SDL3.Cursors.Kind := SDL3.Cursors.Default;
      --  The one the window has been given.

      Shown_Title : Ada.Strings.Unbounded.Unbounded_String;

      Windowed            : Boolean := False;
      Moving              : Boolean := False;
      --  Whether a press on the bar is moving the window, from where the
      --  pointer and the window were when it was pressed.
      Grab_X, Grab_Y      : Float := 0.0;
      Grab_Left, Grab_Top : Integer := 0;
      System_Board        : Pomarine.Clipboards.System_Clipboard;
      Own_Board           : Pomarine.Clipboards.Memory_Clipboard;
      --  The clipboard used offscreen.

      Done : Boolean := False;
   end record;
   --  The window as the system has it, and the clipboards.

end View_Parts.Common;
