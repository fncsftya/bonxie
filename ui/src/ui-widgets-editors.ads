with SDL3.Events;
with SDL3.Windows.Renderers;
with Texts.Documents;
with UI.Icons;
with UI.Text_Areas;

--  A text area (see UI.Text_Areas) as a widget: it is placed by the
--  layout, takes the focus when clicked, and is drawn, updated and given
--  events by the tree, with the tree's clipboard. It is drawn again when
--  anything it shows changes, including its document, which the
--  application may change.
--
--  As a field it is white, outlined; with the focus, the outline is the
--  theme's focus colour, and thicker. It can say that what is in it will
--  not do (outlined in the danger colour), be turned off (tinted, faint,
--  and taking nothing), show a hint while it is empty, and an icon before
--  a single line.
--
--  Declare it after the renderer it is drawn to, and after the document
--  it shows.
package UI.Widgets.Editors is

   type Editor is new Widget with private;

   procedure Configure
     (Item    : in out Editor;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0)
     with Post => Is_Configured (Item);
   --  As UI.Text_Areas.Configure. Do it before the layout.

   function Is_Configured (Item : Editor) return Boolean;

   procedure Attach
     (Item : in out Editor; Doc : not null Texts.Documents.Document_Access)
     with Pre => Is_Configured (Item), Post => Has_Document (Item);
   --  Show Doc: as UI.Text_Areas.Attach.

   function Has_Document (Item : Editor) return Boolean;

   procedure Set_Zoom (Item : in out Editor; To : Float)
     with Pre => To > 0.0;
   --  Make the text Zoom times its size.

   procedure Set_Paper (Item : in out Editor; To : Themes.Color);
   --  Draw on To, not white.

   function Zoom (Item : Editor) return Float;

   procedure Set_Invalid (Item : in out Editor; To : Boolean);
   --  Outline it in the danger colour, as of what will not do, until it
   --  is said to be valid again. The focus's outline is over it.

   function Is_Invalid (Item : Editor) return Boolean;

   procedure Set_Enabled (Item : in out Editor; To : Boolean);
   --  Turn it on, or off: off, it is tinted, its text faint, and it takes
   --  no events nor the focus. It is on to begin with.

   function Is_Enabled (Item : Editor) return Boolean;

   Hint_Capacity : constant := 32;

   procedure Set_Placeholder (Item : in out Editor; Text : String)
     with Pre => Text'Length <= Hint_Capacity;
   --  Show Text, faint, where its text begins, while it has none: a hint
   --  of what to put in it. None to begin with.

   procedure Set_Icon (Item : in out Editor; To : UI.Icons.Icon)
     with Pre => Is_Configured (Item)
                 and then UI.Text_Areas.Is_Single_Line (Area (Item).all);
   --  Show the icon, faint, before its single line, leaving room for it.

   procedure Clear_Icon (Item : in out Editor);
   --  Show none, and leave no room for it.

   function Is_Focused (Item : Editor) return Boolean;

   procedure Caret_Box
     (Item : in out Editor;
      X, Y, Width, Height : out Float)
     with Pre => Has_Document (Item);
   --  Where the caret is drawn, in pixels: as UI.Text_Areas.Caret_Box.

   function Area (Item : in out Editor)
      return not null access UI.Text_Areas.Text_Area;
   --  The text area, to move the caret and so on. Whatever it does that
   --  changes how it looks, it does not say: say with Invalidate.

   overriding procedure Placed
     (Item : in out Editor; Left, Top, Width, Height : Float);

   overriding procedure Draw
     (Item   : in out Editor;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Editor; Hovered : Boolean);

   overriding procedure Handle
     (Item    : in out Editor;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Update
     (Item : in out Editor; Now : SDL3.Events.Milliseconds);

   overriding function Until_Update (Item : Editor) return Integer;

   overriding function Accepts_Focus (Item : Editor) return Boolean;

   overriding procedure Focus_Changed
     (Item : in out Editor; Focused : Boolean);

private

   type Editor is new Widget with record
      Text    : aliased UI.Text_Areas.Text_Area;
      Zoomed  : Float := 1.0;
      Has_Paper : Boolean := False;
      Paper     : Themes.Color := (0, 0, 0, 255);
      Invalid   : Boolean := False;
      Enabled   : Boolean := True;
      Hint      : String (1 .. Hint_Capacity) := [others => ' '];
      Hint_Length : Natural range 0 .. Hint_Capacity := 0;
      Iconed    : Boolean := False;
      Which     : UI.Icons.Icon := UI.Icons.Icon'First;
      Shown   : Texts.Documents.Version := 0;
      Shown_Serial : Natural := 0;
      --  Of the document, as of the last time it was drawn or seen to be
      --  changed.
   end record;

end UI.Widgets.Editors;
