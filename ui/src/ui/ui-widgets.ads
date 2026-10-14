with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;
with UI.Clipboards;
with UI.Icons;
with UI.Line_Texts;
with UI.Themes;
with Yoga.Nodes;

--  A tree of widgets: the parts of a window, each in a box that Yoga's
--  flexbox layout gives it, which draw themselves, take events and keep
--  their own state.
--
--  The application owns the widgets, as it owns the documents they show:
--  they are declared where it declares them, and added to a tree, which
--  holds links to them but allocates nothing. They must be there as long
--  as the tree is used, and the tree after the renderer they draw to.
--  Building goes from the top down: set the root, then add each widget to
--  one that is already in the tree. A widget can be taken out again
--  (Remove) and put elsewhere, or hidden (Set_Visible) so that it takes
--  no room and shows nothing, and be shown again.
--
--  How a widget's box is set is Yoga's: a widget has a node, with
--  Node, to style. The tree lays them out in pixels. Widgets are drawn in
--  order, parents first, and are clipped to their boxes and their
--  parents'. Events go to the widget under the pointer, or to the one
--  with the focus, and then to its parents.
--
--  What has to be drawn again is kept as damage: a box that grows as
--  widgets say they have changed (Invalidate), or are moved or resized by
--  a layout. Setting something to what it was damages nothing, so a
--  frame with no damage needs no drawing. Data flows down, from the
--  application's models to widgets' setters, and what widgets have to say
--  comes back as plain values, taken with a procedure (as a Button's
--  Take_Click) -- there are no callbacks.
--
--  A loop looks like this:
--
--     Dispatch (Tree, Event, Handled);   --  for each event
--     Update (Tree, Ticks);              --  timers, and models that changed
--     if Needs_Paint (Tree) then
--        Paint (Tree, Target, Colors, Retained => ...);
--        Present (Target);
--     end if;
--     wait no longer than Until_Update (Tree)
package UI.Widgets is

   type Tree is tagged limited private;
   --  The widgets of one window, and what they share: the density of its
   --  pixels, the clipboard, which has the focus, what is damaged.

   type Widget is abstract tagged limited private;
   --  The part of every widget that is in the tree. A kind of widget
   --  derives from it, and overrides what it needs of the operations
   --  below.

   type Widget_Access is access all Widget'Class;

   type Pixel_Box is record
      Left, Top, Width, Height : Integer := 0;
   end record;
   --  In pixels from the top left of the target. Empty if it has no
   --  width or no height.

   function Is_Empty (Item : Pixel_Box) return Boolean is
     (Item.Width <= 0 or else Item.Height <= 0);

   --  What a widget does: the operations for a kind of widget to override

   procedure Placed
     (Item : in out Widget; Left, Top, Width, Height : Float) is null;
   --  The tree has put it Left, Top (from the top left of the target)
   --  and made it Width x Height, in pixels: called when those change,
   --  and when the density does.

   procedure Draw
     (Item   : in out Widget;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme) is null;
   --  Draw it, in its box, which is the clip: whatever it draws outside
   --  is not seen. What it draws over is not cleared for it, so a widget
   --  that is not opaque shows what is behind it, and one that is must
   --  fill its box. Often only a part of it is to be drawn: see
   --  Painting_Part.

   procedure Draw_Over
     (Item   : in out Widget;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme) is null;
   --  Draw what goes over its children, in its box, as Draw does: a
   --  scroll bar, say, which they must not hide.

   procedure Handle
     (Item    : in out Widget;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);
   --  Take Event if it is for it, and say so. A widget that has changed
   --  how it looks says so with Invalidate. By default it takes none.
   --
   --  Mouse events come to the widget under the pointer, and then to its
   --  parents until one takes it; and, once one has taken a press, to
   --  that widget alone until the button is let go. Keys and typing come
   --  to the widget with the focus and its parents; keys that none of
   --  them take come to every widget in turn, as shortcuts.

   procedure Update
     (Item : in out Widget; Now : SDL3.Events.Milliseconds) is null;
   --  Say the time is Now, as SDL3.Events.Ticks, and that the models it
   --  shows may have changed: to blink a caret, to notice the document
   --  has changed. It says with Invalidate if it has to be drawn again.

   function Until_Update (Item : Widget) return Integer is (-1);
   --  How many milliseconds after the time last said it needs to be told
   --  the time to change: negative if it does not.

   function Cursor (Item : Widget) return SDL3.Cursors.Kind is
     (SDL3.Cursors.Default);
   --  The shape the pointer should have over it, or while it holds a
   --  press. Default leaves it to the widgets it is in.

   function Accepts_Focus (Item : Widget) return Boolean is (False);
   --  Whether a click on it, or on a widget inside it that does not,
   --  gives it the focus.

   procedure Focus_Changed (Item : in out Widget; Focused : Boolean) is null;
   --  It has the focus now, or has lost it.

   procedure Hover_Changed (Item : in out Widget; Hovered : Boolean) is null;
   --  The pointer has come over it or something in it, or left.

   --  Building

   procedure Set_Root (Item : in out Tree; Root : in out Widget'Class)
     with Pre  => not Has_Root (Item) and then not Is_Attached (Root),
          Post => Is_Attached (Root);
   --  Make Root the whole of Item: its node is Yoga's root.

   function Has_Root (Item : Tree) return Boolean;

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class)
     with Pre  => Is_Attached (Parent) and then not Is_Attached (Child)
                  and then Child_Count (Child) = 0,
          Post => Is_Attached (Child) and then Parent_Of (Child) /= null;
   --  Put Child after Parent's other children, and so above them.

   function Is_Attached (Item : Widget'Class) return Boolean;
   --  Whether it is in a tree.

   function Node (Item : Widget'Class) return Yoga.Nodes.Node
     with Pre => Is_Attached (Item);
   --  Its node, to style. Changing the style of a widget's node is
   --  changing its layout: say so with Request_Layout.

   function Parent_Of (Item : Widget'Class) return Widget_Access;
   --  null for the root.

   procedure Remove (Item : in out Widget'Class)
     with Pre  => Is_Attached (Item) and then Parent_Of (Item) /= null,
          Post => not Is_Attached (Item) and then Child_Count (Item) = 0;
   --  Take Item out of the tree, with everything in it: they and their
   --  nodes are gone from it, and its parent's other children take up
   --  the room, at the next layout. If any of them had the focus, or
   --  the pointer, they do not now. Each is as it was before it was
   --  added, so that one can be added again, with its children, as
   --  below it was built, and styled again.

   procedure Raise_To_Front (Item : in out Widget'Class)
     with Pre => Is_Attached (Item) and then Parent_Of (Item) /= null;
   --  Make it the last of its parent's children: the one drawn over the
   --  others, and found first where they overlap. Only that order
   --  changes, not the layout, so it is for widgets placed by their
   --  edges (Yoga.Absolute).

   procedure Set_Visible (Item : in out Widget'Class; To : Boolean)
     with Pre => Is_Attached (Item);
   --  Show it, or hide it, with all of its children: hidden, it takes no
   --  room in its parent, is not drawn, and nothing is taken by it, nor
   --  can it have the focus or the pointer over it. It is still in the
   --  tree, with its place in the order, and keeps its state and its
   --  style.

   function Is_Visible (Item : Widget'Class) return Boolean;
   --  Whether it has not been hidden. Its children are not shown if it
   --  is not: see Is_Shown.

   function Is_Shown (Item : Widget'Class) return Boolean;
   --  Whether it and every widget it is in is visible.

   function Child_Count (Item : Widget'Class) return Natural;

   function Child_At (Item : Widget'Class; Index : Positive)
      return Widget_Access
     with Pre => Index <= Child_Count (Item);

   --  What a tree shares

   procedure Set_Density (Item : in out Tree; To : Float)
     with Pre => To >= 1.0;
   --  Pixels to a point of the window, which events are in. Layout is in
   --  pixels: the application styles nodes in them.

   function Density (Item : Tree) return Float;

   procedure Set_Settled (Item : in out Tree; To : Boolean);
   --  Say whether what is shown has stopped changing (as a zoom has), so
   --  that widgets which draw quickly while it does can draw their best.
   --  Changing it damages the root.

   function Is_Settled (Item : Tree) return Boolean;

   procedure Set_Clipboard
     (Item : in out Tree; Board : in out Clipboards.Clipboard'Class);
   --  The clipboard for widgets to cut, copy and paste with. It must be
   --  there as long as the tree is used.

   type Clipboard_Access is access all Clipboards.Clipboard'Class;

   procedure Set_Line_Texts
     (Item : in out Tree; Lines : aliased in out Line_Texts.Drawer);
   --  The system font for widgets' single lines of text, labels and
   --  buttons', drawn from Lines, which must be there as long as the
   --  tree is used, and after the renderer. Without it they use the
   --  debug font of SDL3.Windows.Renderers.

   type Line_Texts_Access is access all Line_Texts.Drawer;

   procedure Set_Icons
     (Item : in out Tree; Library : aliased in out Icons.Library);
   --  The icons for widgets to draw, as buttons', from Library, which
   --  must be there as long as the tree is used, and after the renderer.

   type Icons_Access is access all Icons.Library;

   function Icon_Library (Item : Widget'Class) return Icons_Access
     with Pre => Is_Attached (Item);
   --  null if the tree has none.

   function Text_Lines (Item : Widget'Class) return Line_Texts_Access
     with Pre => Is_Attached (Item);
   --  null if the tree has none.

   --  Layout, damage and drawing

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Windows.Renderers.Renderer)
     with Pre => Has_Root (Item);
   --  Fit the widgets to the size of Target, in pixels, and place any that
   --  have moved or been resized (see Placed), damaging where they were
   --  and where they are. Paint does so too: it is for when the layout is
   --  needed sooner.

   procedure Request_Layout (Item : in out Widget'Class)
     with Pre => Is_Attached (Item);
   --  Say that its style, or its content that sizes it, has changed, so
   --  that Needs_Paint is true until the layout has been looked at again.

   procedure Invalidate (Item : in out Widget'Class)
     with Pre => Is_Attached (Item);
   --  Say that all of it must be drawn again.

   procedure Invalidate (Item : in out Widget'Class; Part : Pixel_Box)
     with Pre => Is_Attached (Item);
   --  Say that Part must be drawn again, in pixels from the top left of
   --  the target, as of a caret; only what is in the widget counts.

   procedure Invalidate_All (Item : in out Tree);
   --  Say that what the target shows is lost, as when a window is
   --  exposed or an offscreen target resized: the next Paint draws it
   --  all.

   function Needs_Paint (Item : Tree) return Boolean;
   --  Whether there is anything to draw: damage, a layout to look at, or
   --  a target to draw to afresh.

   function Damage (Item : Tree) return Pixel_Box;
   --  What widgets have said, since the last Paint, to draw again, as of
   --  the last layout; Is_Empty if nothing. Not what Invalidate_All says.

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Windows.Renderers.Renderer;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
     with Pre => Has_Root (Item);
   --  Lay out, and draw the widgets that are in the damage over
   --  Colors.Background, then say there is none. It does not present
   --  Target.
   --
   --  Retained says Target still has what was last drawn on it, so that
   --  only the damage need be drawn again: true of an offscreen target,
   --  not of a window, whose frames are swapped (draw it all). When the
   --  target has changed size, or is new, or has been said to be lost, it
   --  is drawn all.

   --  Events and time

   procedure Dispatch
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);
   --  Give Event to the widgets, as Handle says. A click gives the focus
   --  to the widget it is on, or the one inside which it is, that
   --  accepts it; a click on none, that nothing takes, takes the focus
   --  away (and is taken). The pointer's moving keeps which widget it is
   --  over for Hover_Changed. Events other than the mouse's, keys' and
   --  typing are left to the application.

   procedure Update (Item : in out Tree; Now : SDL3.Events.Milliseconds);
   --  Tell every widget the time.

   function Until_Update (Item : Tree) return Integer;
   --  The fewest milliseconds any widget says it must wait after the time
   --  last said; negative if none needs the time. As a timeout to wait
   --  for events for.

   function Wanted_Cursor (Item : Tree) return SDL3.Cursors.Kind;
   --  The cursor to show: the one of the widget holding a press, or of the
   --  deepest one under the pointer that wants any but the default, going
   --  out through the widgets it is in.

   function Hit (Item : Tree; X, Y : Float) return Widget_Access;
   --  The widget at pixel X, Y: the last of the deepest. null if none.

   --  Focus: at most one widget has it, and takes keys and typing.

   procedure Focus (Item : in out Widget'Class)
     with Pre  => Is_Attached (Item) and then Accepts_Focus (Item),
          Post => Has_Focus (Item);
   --  Give it the focus, taking it from the widget that had it.

   procedure Release_Focus (Item : in out Widget'Class)
     with Pre => Is_Attached (Item);
   --  Take the focus from it, if it has it.

   procedure Clear_Focus (Item : in out Tree);

   function Has_Focus (Item : Widget'Class) return Boolean;

   function Focus_Of (Item : Tree) return Widget_Access;
   --  null if none.

   --  A widget's place and surroundings

   function Left_Of (Item : Widget'Class) return Float;
   function Top_Of (Item : Widget'Class) return Float;
   function Width_Of (Item : Widget'Class) return Float;
   function Height_Of (Item : Widget'Class) return Float;
   --  Its box in pixels from the top left of the target, as of the last
   --  layout; zeroes before.

   function Is_Placed (Item : Widget'Class) return Boolean;
   --  Whether it has had a layout.

   function Contains (Item : Widget'Class; X, Y : Float) return Boolean;
   --  Whether pixel X, Y is in its box.

   function Painting_Part (Item : Widget'Class) return Pixel_Box;
   --  While it is drawn: the part of its box that is to be, which is all
   --  that it is clipped to. A widget that has a lot to draw can leave
   --  what is outside it, as when only a caret is to be drawn again.

   function Is_Hovered (Item : Widget'Class) return Boolean;
   --  Whether the pointer is over it, or something in it.

   function Density (Item : Widget'Class) return Float
     with Pre => Is_Attached (Item);

   function Is_Settled (Item : Widget'Class) return Boolean
     with Pre => Is_Attached (Item);

   function Clipboard (Item : Widget'Class) return Clipboard_Access
     with Pre => Is_Attached (Item);
   --  null if the tree has none.

private

   type Tree_Access is access all Tree;

   type Widget is abstract tagged limited record
      Owner  : Tree_Access;
      Parent : Widget_Access;
      First  : Widget_Access;
      Last   : Widget_Access;
      --  Its children, in order, to add to the end.
      Next   : Widget_Access;
      --  The next of its parent's.
      Count  : Natural := 0;

      Yoga_Node : Yoga.Nodes.Node;

      Placed_Box : Boolean := False;
      Box_Left, Box_Top, Box_Width, Box_Height : Float := 0.0;
      --  In pixels: where the last layout put it.

      Hovered : Boolean := False;
      Focused : Boolean := False;
      Visible : Boolean := True;
      Paint_Box : Pixel_Box;
      --  Of its box, what is being drawn.
   end record;

   type Tree is tagged limited record
      Yoga_Tree : Yoga.Nodes.Tree;
      Root      : Widget_Access;
      Density   : Float := 1.0;
      Settled   : Boolean := True;
      Board     : Clipboard_Access;
      Lines     : Line_Texts_Access;
      Pictures  : Icons_Access;

      Focus     : Widget_Access;
      Hover     : Widget_Access;
      --  The deepest widget the pointer was last over.
      Capture   : Widget_Access;
      Capture_Button : Natural := 0;
      --  The widget that took a press, and which button, until it is
      --  let go.

      Replace_All    : Boolean := False;
      --  Every widget is to be placed again at the next layout.
      Layout_Pending : Boolean := False;
      Lost           : Boolean := True;
      --  What the target shows is not what was drawn, or nothing was.
      Painted_Width, Painted_Height : Natural := 0;
      Damaged        : Pixel_Box;
   end record;

end UI.Widgets;
