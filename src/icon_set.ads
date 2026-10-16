with Pomarine.Icons.Sets;

--  The application's icons: the files in share/bonxie/icons, each named for
--  its icon in lower case, with ".svg". The library has no pictures of its
--  own; the widgets' own (check, close, minimize, the chevrons) have theirs
--  in Pomarine.Icons, and files of the same names here.
package Icon_Set is

   package Names is
      type Name is
        (Edit, Delete, Window, Restore, List, Show,
         Hide, Link, Cursor, Eraser, Stroke_Solid, Stroke_Dots,
         Stroke_Dashed, End_Plain, End_Arrow, Microphone, Stop, Pin,
         Plus, Back, Document, Settings, Highlighter, Folder, Forward, Sparkles);
   end Names;

   package Sets is new Pomarine.Icons.Sets (Names.Name);

   Edit          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Edit);
   Delete        : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Delete);
   Window        : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Window);
   Restore       : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Restore);
   List          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.List);
   Show          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Show);
   Hide          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Hide);
   Link          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Link);
   Cursor        : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Cursor);
   Eraser        : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Eraser);
   Stroke_Solid  : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Stroke_Solid);
   Stroke_Dots   : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Stroke_Dots);
   Stroke_Dashed : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Stroke_Dashed);
   End_Plain     : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.End_Plain);
   End_Arrow     : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.End_Arrow);
   Microphone    : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Microphone);
   Stop          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Stop);
   Pin           : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Pin);
   Plus          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Plus);
   Back          : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Back);
   Document      : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Document);
   Settings      : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Settings);
   Highlighter   : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Highlighter);
   Folder        : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Folder);
   Forward       : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Forward);
   Sparkles      : constant Pomarine.Icons.Icon := Sets.Icon_Of (Names.Sparkles);

   procedure Install (Library : in out Pomarine.Icons.Library; Directory : String);
   --  Where the files are, and which is which.

end Icon_Set;
