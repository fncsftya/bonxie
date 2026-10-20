with Items.Sources;
with Items.Words;
with Ada.Directories;
with Ada.Strings.Fixed;
with Viewer.Writing;
with Vision.Jobs;
with Viewer.Canvas_Items.Basics;

package body Viewer.Canvas_Items.Recognition is

   package Windows renames Items.Windows;

   use type Items.Kinds;

   Longest_Title : constant := 64;
   --  Of a title made from the words of a picture: what is more is left out.

   procedure Start_Recognition (Item : in out Session; Which : Items.Slot) is
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      Vision.Jobs.Reset (Which);
      Vision.Jobs.Start
        (Which,
         Items.Sources.Image_File
           (Item.Nav.Store, Item.Opened.Current, Key));
   end Start_Recognition;

   procedure Keep_Recognition (Item : in out Session; Which : Items.Slot) is
      Found : Vision.Result;
      Key   : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      Vision.Jobs.Take (Which, Found);
      Items.Words.Save_Words (Item.Nav.Store, Key, Found, Basics.Epoch_Now (Item));
      Windows.Set_Recognized (Item.Windows (Which), Found);
      Writing.Words_Found (Item, Which, Found);
   end Keep_Recognition;

   procedure Recognize_Kept (Item : in out Session; Which : Items.Slot) is
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      if not Basics.Is_Source (Item, Which)
        or else Windows.Details (Item.Windows (Which)).Captured_At = 0
      then
         return;
      end if;
      if Windows.Is_Paged (Item.Windows (Which)) then
         null;   --  The document's own text (see Show_Page).
      elsif Items.Words.Has_Words (Item.Nav.Store, Key) then
         declare
            Found : Vision.Result;
         begin
            Items.Words.Load_Words (Item.Nav.Store, Key, Found);
            Windows.Set_Recognized (Item.Windows (Which), Found);
         end;
      elsif Ada.Directories.Exists
              (Items.Sources.Image_File
                 (Item.Nav.Store, Item.Opened.Current, Key))
      then
         Start_Recognition (Item, Which);
      end if;
   end Recognize_Kept;

   procedure Name_From_Page
     (Item : in out Session; Which : Items.Slot; Heading : String)
   is
      Raw  : String := Heading;
      Last : Natural := 0;
   begin
      for C of Raw loop
         if C in ASCII.NUL .. ' ' then
            C := ' ';
         end if;
      end loop;
      declare
         Page : constant String :=
           Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
      begin
         Last := Natural'Min (Page'Length, Longest_Title);
         --  Not in the middle of a UTF-8 character.
         while Last > 0 and then Last < Page'Length
           and then Character'Pos (Page (Page'First + Last))
                    in 16#80# .. 16#BF#
         loop
            Last := Last - 1;
         end loop;
         if Last > 0
           and then Projects.Titles.To_String
                      (Windows.Details (Item.Windows (Which)).Title)
                    = Untitled_Source
         then
            Windows.Set_Title_Text
              (Item.Windows (Which),
               Page (Page'First .. Page'First + Last - 1));
         end if;
      end;
   end Name_From_Page;

   procedure Show_Page
     (Item  : in out Session;
      Which : Items.Slot;
      Page  : Positive;
      Heading : String := "")
   is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
      Ending  : constant String := Items.Extensions.To_String (Details.Document);
      Time    : constant Projects.Seconds := Basics.Epoch_Now (Item);
   begin
      --  The page is drawn from the document, as shapes and text.
      if Heading /= "" then
         Name_From_Page (Item, Which, Heading);
      end if;
      Windows.Set_Pages (Item.Windows (Which), Ending, Page, Details.Page_Count);
      Windows.Set_Capture
        (Item.Windows (Which), Windows.Ready,
         Items.Sources.Document_File
           (Item.Nav.Store, Item.Opened.Current, Details.Key, Ending),
         At_Time => Time);
      if not Windows.Shows_Picture (Item.Windows (Which)) then
         return;   --  and says why
      end if;
      Items.Sources.Set_Captured (Item.Nav.Store, Details.Key, Time);
      Items.Sources.Set_Page (Item.Nav.Store, Details.Key, Page);
      Writing.Picture_Taken (Item, Which);
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
      --  The words of pages one under another are the document's own text,
      --  found as the pages are made.
      if not Windows.Is_Paged (Item.Windows (Which)) then
         Start_Recognition (Item, Which);
      end if;
   end Show_Page;

   procedure Turn_Page (Item : in out Session; Which : Items.Slot; By : Integer) is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
      Page    : constant Integer := Details.Page + By;
   begin
      if Details.Kind = Items.Source and then Page in 1 .. Details.Page_Count then
         if Windows.Is_Paged (Item.Windows (Which)) then
            Windows.Go_To_Page (Item.Windows (Which), Page);
         else
            Show_Page (Item, Which, Page);
         end if;
      end if;
   end Turn_Page;

end Viewer.Canvas_Items.Recognition;
