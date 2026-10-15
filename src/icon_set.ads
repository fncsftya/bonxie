with Pomarine.Icons;

--  The application's icons: the files in share/bonxie/icons, each given a
--  number in the library of Pomarine.Icons, which has no pictures of its own.
--  The widgets' own (check, close, minimize, the chevrons) have theirs in
--  Pomarine.Icons, and files of the same names here.
package Icon_Set is

   Edit         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (0);
   Delete       : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (1);
   Window       : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (2);
   Restore      : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (3);
   List         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (4);
   Show         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (5);
   Hide         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (6);
   Link         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (7);
   Cursor       : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (8);
   Eraser       : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (9);
   Stroke_Solid : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (10);
   Stroke_Dots  : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (11);
   Stroke_Dashed : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (12);
   End_Plain    : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (13);
   End_Arrow    : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (14);
   Microphone   : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (15);
   Stop         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (16);
   Pin          : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (17);
   Plus         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (18);
   Back         : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (19);
   Document     : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (20);
   Settings     : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (21);
   Highlighter  : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (22);
   Folder       : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (23);

   procedure Install (Library : in out Pomarine.Icons.Library; Directory : String);
   --  Where the files are, and which is which: each is its name in lower
   --  case, with ".svg".

end Icon_Set;
