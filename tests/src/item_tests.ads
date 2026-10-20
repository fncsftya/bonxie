--  Tests of the items on a project's canvas, as a person would use them:
--  added, typed in, moved, sized, minimised, closed, listed and removed,
--  and kept in the database. See Goldens.
package Item_Tests is

   procedure Counting_Words;
   procedure Stored;
   procedure Added;
   procedure Typing;
   procedure Dictating;
   procedure Dictating_Into_Empty;
   procedure Dictating_Live;
   procedure Titling;
   procedure Moving;
   procedure Sizing;
   procedure Smallest;
   procedure Minimizing;
   procedure Closing;
   procedure Listing;
   procedure Removing;
   procedure Keyboard_List;
   procedure Revealing;
   procedure Scrolling_Dock;
   procedure Scrolling_List;
   procedure Panning_And_Zooming;
   procedure Raising;
   procedure Repainting;
   procedure Fractional_Density;
   procedure Full;
   procedure Long_Title;
   procedure Many_Marks_And_Words;
   procedure Kept;
   procedure Linking;
   procedure Editing_Links;
   procedure Source_Windows;
   procedure Source_Pages;
   procedure Source_Words;
   procedure Source_Documents;
   procedure Source_Files;

   From_Url_X  : constant Float := 358.0;
   From_Url_Y  : constant Float := 241.0;
   From_File_Y : constant Float := 283.0;
   --  The buttons of a source yet to say where it comes from.

   Pager_Y    : constant Float := 339.0;
   Next_X     : constant Float := 244.0;
   Previous_X : constant Float := 208.0;
   --  The buttons that turn a source's page, at the left of its status line.

   Two_Pages : constant String :=
     "%PDF-1.4" & ASCII.LF
     & "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj" & ASCII.LF
     & "2 0 obj<</Type/Pages/Count 2/Kids[3 0 R 5 0 R]>>endobj" & ASCII.LF
     & "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R"
     & "/Resources<</Font<</F1 7 0 R>>>>>>endobj" & ASCII.LF
     & "4 0 obj<</Length 63>>stream" & ASCII.LF
     & "BT /F1 56 Tf 40 600 Td (Bonxies nest on moorland) Tj ET" & ASCII.LF
     & "endstream endobj" & ASCII.LF
     & "5 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 6 0 R"
     & "/Resources<</Font<</F1 7 0 R>>>>>>endobj" & ASCII.LF
     & "6 0 obj<</Length 55>>stream" & ASCII.LF
     & "BT /F1 56 Tf 40 600 Td (Skuas winter at sea) Tj ET" & ASCII.LF
     & "endstream endobj" & ASCII.LF
     & "7 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj" & ASCII.LF
     & "trailer<</Root 1 0 R/Size 8>>" & ASCII.LF & "%%EOF" & ASCII.LF;
   --  A PDF of two pages, with no table of where its objects are: it is
   --  found by reading it through.

end Item_Tests;
