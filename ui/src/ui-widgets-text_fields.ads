with UI.Widgets.Editors;

--  A field to type a line of text in: an editor (see UI.Widgets.Editors)
--  of one line. The text is not wrapped, but scrolls across to keep the
--  caret in view. Return does not break the line: the application takes
--  it, as it takes a button's click. Line feeds typed or pasted become
--  spaces.
package UI.Widgets.Text_Fields is

   type Text_Field is new Editors.Editor with null record;

   procedure Configure
     (Item   : in out Text_Field;
      Family : String;
      Size   : Float)
     with Post => Is_Configured (Item);
   --  Set the text in font Family at Size layout units: as an editor's,
   --  with no limit to the length of the line that is practical. The
   --  field should be as high as a line and its padding: about
   --  2.5 x Size, in points. Do it before the layout.

   procedure Take_Return (Item : in out Text_Field; Pressed : out Boolean);
   --  Say whether Return has been pressed in it since this was last
   --  called, and forget it.

end UI.Widgets.Text_Fields;
