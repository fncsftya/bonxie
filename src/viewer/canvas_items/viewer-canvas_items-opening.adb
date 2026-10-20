with Items.Sources;
with Ada.Directories;
with Ada.Strings.Fixed;
with Downloads;
with Ebook;
with SDL3.Dialogs;
with SDL3.Windows;
with Viewer.Writing;
with Vision.Jobs;
with Webshot;
with Viewer.Canvas_Items.Basics;
with Viewer.Canvas_Items.Recognition;

package body Viewer.Canvas_Items.Opening is

   package Windows renames Items.Windows;

   use type Items.Id;
   use type Webshot.States;
   use type Downloads.States;
   use type Items.Origins;
   use type SDL3.Dialogs.States;

   function Name_Of (Where : String) return String;
   --  The name of the file a link or path is of, without its ending: for a
   --  title.

   function Name_Of (Where : String) return String is
      Stop : Natural := Where'Last;
   begin
      for I in Where'Range loop
         if Where (I) in '?' | '#' then
            Stop := I - 1;
            exit;
         end if;
      end loop;
      declare
         First : Natural := Where'First;
         Dot   : Natural := Stop + 1;
      begin
         for I in Where'First .. Stop loop
            if Where (I) = '/' then
               First := I + 1;
               Dot := Stop + 1;
            elsif Where (I) = '.' then
               Dot := I;
            end if;
         end loop;
         return Where (First .. Dot - 1);
      end;
   end Name_Of;

   function Is_Image (Ending : String) return Boolean is
     (Ending = "png" or else Ending = "jpg" or else Ending = "jpeg"
      or else Ending = "gif" or else Ending = "tif" or else Ending = "tiff"
      or else Ending = "bmp" or else Ending = "heic" or else Ending = "heif"
      or else Ending = "webp" or else Ending = "jp2" or else Ending = "exr");

   function Link_Of (Typed : String) return String;
   --  What was typed, as a link: with https:// if it has no scheme.

   function Link_Of (Typed : String) return String is
      Trimmed : constant String :=
        Ada.Strings.Fixed.Trim (Typed, Ada.Strings.Both);
   begin
      return (if Trimmed = ""
                or else Ada.Strings.Fixed.Index (Trimmed, "://") > 0
              then Trimmed else "https://" & Trimmed);
   end Link_Of;

   procedure Open_Document
     (Item : in out Session; Which : Items.Slot; Ending : String; Local : Boolean);
   --  The file of the source's document has come: count its pages, and
   --  draw the first. A file from disk is titled by its name; one fetched,
   --  by its own title if it has one.

   procedure Open_Document
     (Item : in out Session; Which : Items.Slot; Ending : String; Local : Boolean)
   is
      Key     : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
      File    : constant String :=
        Items.Sources.Document_File (Item.Nav.Store, Item.Opened.Current, Key, Ending);
      Found   : Ebook.Information;
      Message : String (1 .. Ebook.Max_Message);
      Last    : Natural;
   begin
      Ebook.Open (File, Found, Message, Last);
      if Found.Pages = 0 then
         Ada.Directories.Delete_File (File);
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => Message (1 .. Last));
         return;
      end if;
      Items.Sources.Set_Document (Item.Nav.Store, Key, Ending, Found.Pages);
      Windows.Set_Pages (Item.Windows (Which), Ending, 1, Found.Pages);
      Recognition.Show_Page
        (Item, Which, 1,
         (if Found.Last > 0 and then not Local then Found.Title (1 .. Found.Last)
          else Name_Of (Windows.Text (Item.Windows (Which)))));
   end Open_Document;

   procedure Open_Text
     (Item : in out Session; Which : Items.Slot; Ending : String);
   --  The file of the source's text has come: show it.

   procedure Open_Text
     (Item : in out Session; Which : Items.Slot; Ending : String)
   is
      Key  : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
      File : constant String :=
        Items.Sources.Document_File (Item.Nav.Store, Item.Opened.Current, Key, Ending);
      Time : constant Projects.Seconds := Basics.Epoch_Now (Item);
      Picture : constant String :=
        Items.Sources.Image_File (Item.Nav.Store, Item.Opened.Current, Key);
   begin
      Vision.Jobs.Reset (Which);
      Items.Sources.Set_Document (Item.Nav.Store, Key, Ending, 0);
      Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
      if Ada.Directories.Exists (Picture) then
         Ada.Directories.Delete_File (Picture);
      end if;
      Windows.Set_Pages (Item.Windows (Which), Ending, 0, 0);
      Recognition.Name_From_Page (Item, Which, Name_Of (Windows.Text (Item.Windows (Which))));
      Windows.Show_Text (Item.Windows (Which), File, Time);
      Writing.Picture_Taken (Item, Which);
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Open_Text;

   procedure Finish_File
     (Item : in out Session; Which : Items.Slot; Ending : String; Local : Boolean := False);
   --  The file of the source has come, here: show it as text, or as the
   --  pages it is of.

   procedure Finish_File
     (Item : in out Session; Which : Items.Slot; Ending : String; Local : Boolean := False) is
   begin
      if Items.Sources.Is_Text (Ending) then
         Open_Text (Item, Which, Ending);
      else
         Open_Document (Item, Which, Ending, Local);
      end if;
   end Finish_File;

   procedure Start_Download
     (Item : in out Session; Which : Items.Slot; Link : String);
   --  Begin to fetch the PDF or e-book the source's text links to: it is
   --  drawn, a page at a time, when it has come (see Poll_Download).

   procedure Start_Download
     (Item : in out Session; Which : Items.Slot; Link : String)
   is
      Ending : constant String := Ebook.Extension_Of (Link);
      Key    : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      if Item.Nav.Fetch_Slot /= 0 or else Downloads.State = Downloads.Running
      then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed,
            Detail => "another file is being fetched");
         return;
      end if;
      if Link'Length > Downloads.Max_Path then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => "the link is too long");
         return;
      end if;
      Items.Sources.Make_Image_Folder (Item.Nav.Store, Item.Opened.Current);
      Vision.Jobs.Reset (Which);
      Webshot.Reset (Which);
      Downloads.Reset;
      Downloads.Start
        (Link,
         Items.Sources.Document_File
           (Item.Nav.Store, Item.Opened.Current, Key, Ending));
      Item.Nav.Fetch_Slot := Which;
      Item.Nav.Fetch_Key := Key;
      Item.Nav.Fetch_Document :=
        Items.Extensions.To_Bounded_String (Ending);
      Windows.Set_Capture (Item.Windows (Which), Windows.Busy);
   end Start_Download;

   procedure Start_Local (Item : in out Session; Which : Items.Slot; Path : String);
   --  Take a copy of the file the source's text is the path of, and show it.

   procedure Start_Local (Item : in out Session; Which : Items.Slot; Path : String) is
      Ending : constant String := Ebook.File_Extension (Path);
      Key    : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
   begin
      if Is_Image (Ending) then
         if not Ada.Directories.Exists (Path)
           or else Ada.Directories."="
             (Ada.Directories.Kind (Path), Ada.Directories.Directory)
         then
            Windows.Set_Capture
              (Item.Windows (Which), Windows.Failed, Detail => "the file is not there");
            return;
         end if;
         Items.Sources.Make_Image_Folder (Item.Nav.Store, Item.Opened.Current);
         Items.Sources.Convert_Image
           (Path, Items.Sources.Image_File (Item.Nav.Store, Item.Opened.Current, Key));
         Items.Sources.Set_Document (Item.Nav.Store, Key, "", 0);
         declare
            Time : constant Projects.Seconds := Basics.Epoch_Now (Item);
         begin
            Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
            Windows.Set_Pages (Item.Windows (Which), "", 0, 0);
            Windows.Set_Capture
              (Item.Windows (Which), Windows.Ready,
               Items.Sources.Image_File (Item.Nav.Store, Item.Opened.Current, Key),
               At_Time => Time);
            Writing.Picture_Taken (Item, Which);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end;
      elsif not Ebook.Is_Supported ("." & Ending) then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed,
            Detail => "not an image, PDF, e-book or text file");
      elsif not Ada.Directories.Exists (Path)
        or else Ada.Directories."=" (Ada.Directories.Kind (Path), Ada.Directories.Directory)
      then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => "the file is not there");
      else
         Items.Sources.Make_Image_Folder (Item.Nav.Store, Item.Opened.Current);
         Vision.Jobs.Reset (Which);
         Webshot.Reset (Which);
         Items.Sources.Copy_File
           (Path, Items.Sources.Document_File (Item.Nav.Store, Item.Opened.Current, Key, Ending));
         Finish_File (Item, Which, Ending, Local => True);
      end if;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => "the file could not be read");
   end Start_Local;

   procedure Start_Capture (Item : in out Session; Which : Items.Slot) is
      Origin : constant Items.Origins := Windows.Details (Item.Windows (Which)).Origin;
      Link : constant String :=
        Link_Of (Windows.Text (Item.Windows (Which)));
   begin
      if Webshot.State (Which) = Webshot.Working or else Origin = Items.Unchosen then
         return;
      end if;
      if Origin = Items.Local then
         Start_Local
           (Item, Which, Ada.Strings.Fixed.Trim (Windows.Text (Item.Windows (Which)), Ada.Strings.Both));
         return;
      end if;
      if Link = "" then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => "no link");
         return;
      end if;
      if Ebook.Is_Supported (Link) then
         Start_Download (Item, Which, Link);
         return;
      end if;
      Items.Sources.Make_Image_Folder (Item.Nav.Store, Item.Opened.Current);
      Vision.Jobs.Reset (Which);
      Webshot.Reset (Which);
      Webshot.Start
        (Which, Link,
         Items.Sources.Image_File
           (Item.Nav.Store, Item.Opened.Current,
            Windows.Details (Item.Windows (Which)).Key));
      Windows.Set_Capture (Item.Windows (Which), Windows.Busy);
   end Start_Capture;

   procedure Pick_File (Item : in out Session; Which : Items.Slot) is
   begin
      if Item.Nav.Pick_Slot /= 0 or else SDL3.Dialogs.State = SDL3.Dialogs.Waiting
        or else not SDL3.Windows.Is_Open (Item.Host.Win)
      then
         return;
      end if;
      SDL3.Dialogs.Reset;
      Item.Nav.Pick_Slot := Which;
      Item.Nav.Pick_Key := Windows.Details (Item.Windows (Which)).Key;
      SDL3.Dialogs.Open_File
        (Item.Host.Win, "Images, PDFs, e-books and text",
         Ebook.Extensions & ";png;jpg;jpeg;gif;tif;tiff;bmp;heic;heif;webp;jp2;exr");
   end Pick_File;

   procedure Poll_Download (Item : in out Session) is
      Which : constant Natural := Item.Nav.Fetch_Slot;
   begin
      if Which = 0 then
         return;
      end if;
      declare
         Ours : constant Boolean :=
           Basics.Is_Source (Item, Which)
           and then Windows.Details (Item.Windows (Which)).Key = Item.Nav.Fetch_Key;
      begin
         case Downloads.State is
            when Downloads.Idle =>
               Item.Nav.Fetch_Slot := 0;
            when Downloads.Running =>
               if Ours then
                  Windows.Set_Progress (Item.Windows (Which), Downloads.Fraction);
               end if;
            when Downloads.Done =>
               if Ours then
                  Finish_File (Item, Which, Items.Extensions.To_String (Item.Nav.Fetch_Document));
               end if;
               Downloads.Reset;
               Item.Nav.Fetch_Slot := 0;
            when Downloads.Failed =>
               if Ours then
                  Windows.Set_Capture
                    (Item.Windows (Which), Windows.Failed, Detail => Downloads.Message);
               end if;
               Downloads.Reset;
               Item.Nav.Fetch_Slot := 0;
         end case;
      end;
   end Poll_Download;

   procedure Poll_Pick (Item : in out Session) is
      Which : constant Natural := Item.Nav.Pick_Slot;
   begin
      if Which = 0 then
         return;
      end if;
      case SDL3.Dialogs.State is
         when SDL3.Dialogs.Waiting =>
            null;
         when SDL3.Dialogs.Idle | SDL3.Dialogs.Cancelled | SDL3.Dialogs.Failed =>
            SDL3.Dialogs.Reset;
            Item.Nav.Pick_Slot := 0;
         when SDL3.Dialogs.Chosen =>
            declare
               Path : constant String := SDL3.Dialogs.Path;
            begin
               SDL3.Dialogs.Reset;
               Item.Nav.Pick_Slot := 0;
               if Basics.Is_Source (Item, Which)
                 and then Windows.Details (Item.Windows (Which)).Key = Item.Nav.Pick_Key
               then
                  File_Picked (Item, Which, Path);
               end if;
            end;
      end case;
   end Poll_Pick;

end Viewer.Canvas_Items.Opening;
