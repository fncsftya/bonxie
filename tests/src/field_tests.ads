--  Tests of a text field, the widget for one line: what it draws as it
--  is typed into and clicked, and that Return and line feeds do not break
--  its line. See Goldens.
package Field_Tests is

   procedure Typing;
   procedure Returning;
   procedure Pasting;
   procedure Long_Line;
   procedure Clicking;
   procedure Up_And_Down;

end Field_Tests;
