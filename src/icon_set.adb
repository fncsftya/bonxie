package body Icon_Set is

   procedure Install (Library : in out Pomarine.Icons.Library; Directory : String) is
   begin
      Pomarine.Icons.Set_Directory (Library, Directory);
      Pomarine.Icons.Set_File (Library, Edit, "edit.svg");
      Pomarine.Icons.Set_File (Library, Delete, "delete.svg");
      Pomarine.Icons.Set_File (Library, Window, "window.svg");
      Pomarine.Icons.Set_File (Library, Restore, "restore.svg");
      Pomarine.Icons.Set_File (Library, List, "list.svg");
      Pomarine.Icons.Set_File (Library, Show, "show.svg");
      Pomarine.Icons.Set_File (Library, Hide, "hide.svg");
      Pomarine.Icons.Set_File (Library, Link, "link.svg");
      Pomarine.Icons.Set_File (Library, Cursor, "cursor.svg");
      Pomarine.Icons.Set_File (Library, Eraser, "eraser.svg");
      Pomarine.Icons.Set_File (Library, Stroke_Solid, "stroke_solid.svg");
      Pomarine.Icons.Set_File (Library, Stroke_Dots, "stroke_dots.svg");
      Pomarine.Icons.Set_File (Library, Stroke_Dashed, "stroke_dashed.svg");
      Pomarine.Icons.Set_File (Library, End_Plain, "end_plain.svg");
      Pomarine.Icons.Set_File (Library, End_Arrow, "end_arrow.svg");
      Pomarine.Icons.Set_File (Library, Microphone, "microphone.svg");
      Pomarine.Icons.Set_File (Library, Stop, "stop.svg");
      Pomarine.Icons.Set_File (Library, Pin, "pin.svg");
      Pomarine.Icons.Set_File (Library, Plus, "plus.svg");
      Pomarine.Icons.Set_File (Library, Back, "back.svg");
      Pomarine.Icons.Set_File (Library, Document, "document.svg");
      Pomarine.Icons.Set_File (Library, Settings, "settings.svg");
      Pomarine.Icons.Set_File (Library, Highlighter, "highlighter.svg");
      Pomarine.Icons.Set_File (Library, Folder, "folder.svg");
   end Install;

end Icon_Set;
