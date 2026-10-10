--  A window showing a document, for scrolling and zooming.
package Viewer is

   procedure Run (Source : String);
   --  Open a window showing the text Source, a paragraph to each line,
   --  and run until it is closed. SDL must be initialized.

end Viewer;
