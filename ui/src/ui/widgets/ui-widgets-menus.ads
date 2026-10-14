with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;
with UI.Icons;

--  A menu, as of a dropdown or a context menu: a column of rows on a white
--  box, outlined, casting a solid shadow. A row is a heading, the small
--  faint name of what follows; an action to click, with an icon before it
--  if it is given one; a box to tick, with a square of a colour if it is
--  given one; a line between rows; or a note, faint, as of there being
--  nothing to choose. An action or a box can be plain, or in the theme's
--  primary or danger colour, as of what it does.
--
--  The row under the pointer, of those that can be clicked, is shaded.
--  A click on one is the application's to take (Take_Choice), as a
--  button's; it says back how the rows are to be, as by ticking one.
--
--  It is as tall as its rows (and sets its own node's height, so), and as
--  wide as the application makes it. The application shows it, over what
--  is there, and hides it.
package UI.Widgets.Menus is

   Row_Capacity  : constant := 24;
   Text_Capacity : constant := 48;
   --  Rows, and bytes of the text of each.

   type Row_Kind is (Heading, Action, Check, Separator, Note);

   type Tone is (Plain, Primary, Danger);

   type Menu is new Widget with private;

   procedure Clear (Item : in out Menu)
     with Post => Row_Count (Item) = 0;

   procedure Add
     (Item    : in out Menu;
      Kind    : Row_Kind;
      Text    : String := "";
      Shade   : Tone := Plain;
      Checked : Boolean := False)
     with Pre  => Row_Count (Item) < Row_Capacity
                  and then Text'Length <= Text_Capacity,
          Post => Row_Count (Item) = Row_Count (Item)'Old + 1;
   --  Add a row after the others.

   function Row_Count (Item : Menu) return Natural;

   procedure Set_Icon (Item : in out Menu; Row : Positive; To : UI.Icons.Icon)
     with Pre => Row <= Row_Count (Item);

   procedure Set_Swatch
     (Item : in out Menu; Row : Positive; To : Themes.Slot)
     with Pre => Row <= Row_Count (Item);

   procedure Set_Checked (Item : in out Menu; Row : Positive; To : Boolean)
     with Pre => Row <= Row_Count (Item);

   function Kind_Of (Item : Menu; Row : Positive) return Row_Kind
     with Pre => Row <= Row_Count (Item);

   function Text_Of (Item : Menu; Row : Positive) return String
     with Pre => Row <= Row_Count (Item);

   function Is_Checked (Item : Menu; Row : Positive) return Boolean
     with Pre => Row <= Row_Count (Item);

   function Height_For (Item : Menu) return Float;
   --  In points: of its rows, its padding and outline, and its shadow.

   function Hovered_Row (Item : Menu) return Natural;
   --  The row that can be clicked under the pointer; 0 if none.

   procedure Take_Choice (Item : in out Menu; Chosen : out Natural);
   --  The row clicked since this was last called, 0 if none, and forget
   --  it.

   overriding procedure Handle
     (Item    : in out Menu;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Menu;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Menu; Hovered : Boolean);

   overriding function Cursor (Item : Menu) return SDL3.Cursors.Kind;

private

   type Line is record
      Kind     : Row_Kind := Note;
      Text     : String (1 .. Text_Capacity) := [others => ' '];
      Length   : Natural range 0 .. Text_Capacity := 0;
      Shade    : Tone := Plain;
      Checked  : Boolean := False;
      Iconed   : Boolean := False;
      Which    : UI.Icons.Icon := UI.Icons.Icon'First;
      Swatched : Boolean := False;
      Swatch   : Themes.Slot := Themes.Primary;
   end record;

   type Line_Array is array (1 .. Row_Capacity) of Line;

   type Menu is new Widget with record
      Rows    : Line_Array;
      Used    : Natural range 0 .. Row_Capacity := 0;
      Over    : Natural range 0 .. Row_Capacity := 0;
      --  The row that can be clicked under the pointer.
      Pressed : Natural range 0 .. Row_Capacity := 0;
      Chosen  : Natural range 0 .. Row_Capacity := 0;
   end record;

end UI.Widgets.Menus;
