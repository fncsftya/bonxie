with Items.Links;
with Items.Marks;
with Items.Records;
with Items.Sources;
with Items.Windows.Callbacks;
with Items.Words;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Downloads;
with Ebook;
with SDL3.Dialogs;
with SDL3.Windows;
with Preferences;
with Pomarine.Widgets;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Pictures;
with Speech.Jobs;
with Speech.Models;
with Viewer.Gestures;
with Viewer.Links;
with Viewer.Section_Links;
with Viewer.Style;
with Viewer.Writing;
with Vision.Jobs;
with Webshot;
with Pomarine.Widgets.Layouts;

package body Viewer.Canvas_Items is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;
   package Window_Events is new Items.Windows.Callbacks (Session);

   use type Items.States;
   use type Preferences.Speech_Models;
   use type Pomarine.Widgets.Pictures.Tools;
   use type Items.Id;
   use type Projects.Id;
   use type Items.Kinds;
   use type Webshot.States;
   use type Downloads.States;
   use type Items.Origins;
   use type SDL3.Dialogs.States;
   use type Items.Extensions.Bounded_String;
   use type Vision.Jobs.States;
   use type Speech.Jobs.States;
   use type Windows.Dictations;

   Cascade_Step  : constant Float := 24.0;
   Cascade_Count : constant := 6;
   --  Each new item is put this far down and right of the last, for so
   --  many, so that they are not all on top of each other.

   pragma Assert (Webshot.Slot_Count = Items.Capacity);
   pragma Assert (Vision.Jobs.Slot_Count = Items.Capacity);
   pragma Assert (Speech.Jobs.Slot_Count = Items.Capacity);
   --  A source's picture is taken, and its text found, and a note is
   --  dictated into, in the slot of its window.

   function Epoch_Now (Item : Session) return Projects.Seconds is
     (if Item.Nav.Pinned_Time > 0
      then Item.Nav.Pinned_Time else Projects.Seconds
        (Ada.Calendar."-"
           (Ada.Calendar.Clock,
            Ada.Calendar.Formatting.Time_Of
              (1970, 1, 1, Time_Zone => 0))));
   --  As SQLite's unixepoch.

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Source);

   function Busy (Item : Session) return Boolean is
     (Capturing (Item)
      or else (for some Which in Items.Slot =>
                 Is_Source (Item, Which)
                 and then Vision.Jobs.State (Which) = Vision.Jobs.Working));

   function Capturing (Item : Session) return Boolean is
   begin
      if Item.Nav.Fetch_Slot /= 0 then
         return True;
      end if;
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Speech.Jobs.State (Which)
                    in Speech.Jobs.Starting | Speech.Jobs.Listening
                       | Speech.Jobs.Finishing
         then
            return True;
         end if;
         if Is_Source (Item, Which)
           and then Webshot.State (Which) = Webshot.Working
         then
            return True;
         end if;
      end loop;
      return False;
   end Capturing;

   procedure Toggle_Dictation (Item : in out Session; Which : Items.Slot) is
   begin
      case Speech.Jobs.State (Which) is
         when Speech.Jobs.Idle | Speech.Jobs.Done | Speech.Jobs.Failed =>
            Speech.Jobs.Reset (Which);
            declare
               Model_Directory : constant String :=
                 Preferences.Speech_Model_Directory
                   (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
            begin
               if Item.Prefs.Speech_Choice = Preferences.Parakeet then
                  if Speech.Models.Present (Model_Directory) then
                     Speech.Jobs.Start
                       (Which, Speech.Jobs.Model, Model_Directory);
                     Windows.Set_Dictation
                       (Item.Windows (Which), Windows.Preparing);
                  else
                     Windows.Set_Dictation
                       (Item.Windows (Which), Windows.Failed,
                        "The Parakeet model is not downloaded (Settings)");
                  end if;
               else
                  Speech.Jobs.Start (Which);
                  Windows.Set_Dictation
                    (Item.Windows (Which), Windows.Preparing);
               end if;
            end;
         when Speech.Jobs.Starting | Speech.Jobs.Listening =>
            Speech.Jobs.Stop (Which);
            Windows.Set_Dictation
              (Item.Windows (Which), Windows.Transcribing);
         when Speech.Jobs.Finishing =>
            null;
      end case;
   end Toggle_Dictation;

   procedure Poll_Dictation (Item : in out Session);
   --  Show how dictating stands, and put in a note what has been heard.

   procedure Poll_Dictation (Item : in out Session) is
      Heard : Speech.Transcript;
   begin
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Windows.Details (Item.Windows (Which)).Kind = Items.Note
         then
            declare
               Each : Windows.Window renames Item.Windows (Which);
               procedure Show (To : Windows.Dictations) is
               begin
                  if Windows.Dictation (Each) /= To then
                     Windows.Set_Dictation (Each, To);
                  end if;
               end Show;
            begin
               case Speech.Jobs.State (Which) is
                  when Speech.Jobs.Idle =>
                     null;
                  when Speech.Jobs.Starting =>
                     Show (Windows.Preparing);
                  when Speech.Jobs.Listening =>
                     Show (Windows.Listening);
                     Windows.Set_Level (Each, Speech.Jobs.Loudness (Which));
                     Speech.Jobs.Heard_So_Far (Which, Heard);
                     Windows.Set_Live_Dictation
                       (Each, Speech.Image (Heard), Heard.Settled);
                  when Speech.Jobs.Finishing =>
                     Show (Windows.Transcribing);
                  when Speech.Jobs.Done =>
                     Speech.Jobs.Take (Which, Heard);
                     Windows.Set_Dictation (Each, Windows.Silent);
                     Windows.Add_Dictation (Each, Speech.Image (Heard));
                  when Speech.Jobs.Failed =>
                     Windows.Set_Dictation
                       (Each, Windows.Failed, Speech.Jobs.Message (Which));
                     Speech.Jobs.Reset (Which);
               end case;
            end;
         end if;
      end loop;
   end Poll_Dictation;

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

   procedure Start_Recognition (Item : in out Session; Which : Items.Slot);
   --  Begin to find the words in the source's picture, in the background,
   --  at the full size it was taken: they are what its window lets be
   --  selected.

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

   procedure Start_Capture (Item : in out Session; Which : Items.Slot);
   --  Begin to take the picture of the page the source's text links to, or
   --  show the file its text is the path of.

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

   procedure Keep_Recognition (Item : in out Session; Which : Items.Slot);
   --  Take the words that have been found: write them to the database,
   --  and give them to the window.

   procedure Keep_Recognition (Item : in out Session; Which : Items.Slot) is
      Found : Vision.Result;
      Key   : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      Vision.Jobs.Take (Which, Found);
      Items.Words.Save_Words (Item.Nav.Store, Key, Found, Epoch_Now (Item));
      Windows.Set_Recognized (Item.Windows (Which), Found);
      Writing.Words_Found (Item, Which, Found);
   end Keep_Recognition;

   procedure Name_From_Page
     (Item : in out Session; Which : Items.Slot; Heading : String);
   --  Give a source still called Untitled_Source the title of its page,
   --  or of its document.

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
         Last := Natural'Min (Page'Length, Projects.Title_Capacity);
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
      Heading : String := "");
   --  Draw the page of the window's source's document, as its picture,
   --  and find the words in it.

   procedure Show_Page
     (Item  : in out Session;
      Which : Items.Slot;
      Page  : Positive;
      Heading : String := "")
   is
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
      Ending  : constant String := Items.Extensions.To_String (Details.Document);
      Time    : constant Projects.Seconds := Epoch_Now (Item);
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

   procedure Turn_Page (Item : in out Session; Which : Items.Slot; By : Integer);
   --  Show the page of the source's document By pages on, or back, if
   --  there is one.

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
      Show_Page
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
      Time : constant Projects.Seconds := Epoch_Now (Item);
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
      Name_From_Page (Item, Which, Name_Of (Windows.Text (Item.Windows (Which))));
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

   procedure Start_Local (Item : in out Session; Which : Items.Slot; Path : String) is
      Ending : constant String := Ebook.File_Extension (Path);
      Key    : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
   begin
      if not Ebook.Is_Supported ("." & Ending) then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => "not a PDF, e-book or text file");
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

   procedure Poll_Download (Item : in out Session);
   --  Take the file that has been fetched, or say that it was not.

   procedure Poll_Download (Item : in out Session) is
      Which : constant Natural := Item.Nav.Fetch_Slot;
   begin
      if Which = 0 then
         return;
      end if;
      declare
         Ours : constant Boolean :=
           Is_Source (Item, Which)
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

   procedure Choose_Origin
     (Item : in out Session; Which : Items.Slot; To : Items.Origins) is
   begin
      Items.Sources.Set_Origin
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key, To);
      Windows.Set_Origin (Item.Windows (Which), To);
      if To = Items.Remote then
         Windows.Focus_Text (Item.Windows (Which));
      end if;
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Choose_Origin;

   procedure File_Picked (Item : in out Session; Which : Items.Slot; Path : String) is
   begin
      if Windows.Details (Item.Windows (Which)).Origin /= Items.Local then
         Choose_Origin (Item, Which, Items.Local);
      end if;
      Windows.Set_Link (Item.Windows (Which), Path);
      Start_Capture (Item, Which);
   end File_Picked;

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
      SDL3.Dialogs.Open_File (Item.Host.Win, "PDFs, e-books and text", Ebook.Extensions);
   end Pick_File;

   procedure Poll_Pick (Item : in out Session);
   --  Take the file that has been chosen, in the dialog.

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
               if Is_Source (Item, Which)
                 and then Windows.Details (Item.Windows (Which)).Key = Item.Nav.Pick_Key
               then
                  File_Picked (Item, Which, Path);
               end if;
            end;
      end case;
   end Poll_Pick;

   procedure Poll_Captures (Item : in out Session);
   --  Take the pictures that have been taken, and say what failed.

   procedure Poll_Captures (Item : in out Session) is
   begin
      Poll_Pick (Item);
      Poll_Download (Item);
      for Which in Items.Slot loop
         if Is_Source (Item, Which) and then Windows.Is_Paged (Item.Windows (Which)) then
            --  Which page is being read, of a document one page under
            --  another, as the window is scrolled.
            declare
               Now     : constant Natural := Windows.Document_Page (Item.Windows (Which));
               Details : constant Items.Info := Windows.Details (Item.Windows (Which));
            begin
               if Now > 0 and then Now /= Details.Page then
                  Windows.Set_Pages
                    (Item.Windows (Which), Items.Extensions.To_String (Details.Document),
                     Now, Details.Page_Count);
                  Items.Sources.Set_Page (Item.Nav.Store, Details.Key, Now);
                  Writing.Page_Turned (Item, Which);
               end if;
            end;
         end if;
         if Is_Source (Item, Which) then
            case Webshot.State (Which) is
               when Webshot.Done =>
                  declare
                     Key  : constant Items.Id :=
                       Windows.Details (Item.Windows (Which)).Key;
                     Time : constant Projects.Seconds := Epoch_Now (Item);
                  begin
                     Name_From_Page (Item, Which, Webshot.Page_Title (Which));
                     if Windows.Details (Item.Windows (Which)).Document
                        /= Items.Extensions.Null_Bounded_String
                     then
                        Items.Sources.Set_Document (Item.Nav.Store, Key, "", 0);
                        Windows.Set_Pages (Item.Windows (Which), "", 0, 0);
                     end if;
                     Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
                     Windows.Set_Capture
                       (Item.Windows (Which), Windows.Ready,
                        Items.Sources.Image_File
                          (Item.Nav.Store, Item.Opened.Current, Key),
                        At_Time => Time);
                     Writing.Picture_Taken (Item, Which);
                     Projects.Touch (Item.Nav.Store, Item.Opened.Current);
                  end;
                  Webshot.Reset (Which);
                  Start_Recognition (Item, Which);
               when Webshot.Failed =>
                  Windows.Set_Capture
                    (Item.Windows (Which), Windows.Failed,
                     Detail => Webshot.Message (Which));
                  Webshot.Reset (Which);
               when Webshot.Working =>
                  Windows.Set_Progress
                    (Item.Windows (Which), Webshot.Progress (Which));
               when Webshot.Idle =>
                  null;
            end case;
            case Vision.Jobs.State (Which) is
               when Vision.Jobs.Done =>
                  Keep_Recognition (Item, Which);
               when Vision.Jobs.Failed =>
                  --  The picture still shows, just not as text.
                  Vision.Jobs.Reset (Which);
               when Vision.Jobs.Idle | Vision.Jobs.Working =>
                  null;
            end case;
         end if;
      end loop;
   end Poll_Captures;

   function Count (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Count;

   procedure Order
     (Item : Session; Slots : out Slot_List; Found : out Natural) is
   begin
      Found := 0;
      Slots := [others => Items.Slot'First];
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            --  Inserted among those before it by when they were made,
            --  which the ids give.
            declare
               Key : constant Items.Id :=
                 Windows.Details (Item.Windows (Which)).Key;
               At_Index : Natural := Found;
            begin
               while At_Index >= 1
                 and then Windows.Details
                            (Item.Windows
                               (Slots (Slots'First + At_Index - 1))).Key > Key
               loop
                  Slots (Slots'First + At_Index) :=
                    Slots (Slots'First + At_Index - 1);
                  At_Index := At_Index - 1;
               end loop;
               Slots (Slots'First + At_Index) := Which;
               Found := Found + 1;
            end;
         end if;
      end loop;
   end Order;

   function Nth (Item : Session; Row : Positive) return Items.Slot is
      Slots : Slot_List (1 .. Items.Capacity);
      Found : Natural;
   begin
      Order (Item, Slots, Found);
      return Slots (Row);
   end Nth;

   procedure Show_Dock (Item : in out Session) is
      Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Minimized
           and then Item.Toolbar.Mode = Canvas
         then
            Any := True;
         end if;
      end loop;
      if Any /= Widgets.Is_Visible (Item.Dock.Dock_Panel) then
         Widgets.Set_Visible (Item.Dock.Dock_Panel, Any);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Show_Dock;

   procedure Place_All (Item : in out Session);
   --  Put every window where the canvas has them.

   procedure Place_All (Item : in out Session) is
   begin
      Item.Nav.Shown_Zoom := Canvases.Zoom (Item.Canvas_View);
      Item.Nav.Shown_X := Canvases.Origin_X (Item.Canvas_View);
      Item.Nav.Shown_Y := Canvases.Origin_Y (Item.Canvas_View);
      for Each of Item.Windows loop
         Windows.Place (Each, Item.Nav.Shown_Zoom, Item.Nav.Shown_X,
                        Item.Nav.Shown_Y);
      end loop;
   end Place_All;

   procedure Touch (Item : in out Session);
   --  Say the project has been changed, so that it is listed first.

   procedure Touch (Item : in out Session) is
   begin
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Touch;

   procedure Centre_On (Item : in out Session; X, Y : Float);
   --  Pan so that the canvas point X, Y is in the middle of the view.

   procedure Centre_On (Item : in out Session; X, Y : Float) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom   : constant Float := Canvases.Zoom (View);
   begin
      Canvases.Pan_By
        (View,
         Widgets.Width_Of (View) / Pixels / 2.0
           - (Canvases.Origin_X (View) + X * Zoom),
         Widgets.Height_Of (View) / Pixels / 2.0
           - (Canvases.Origin_Y (View) + Y * Zoom));
   end Centre_On;

   procedure Centre_On_Visible (Item : in out Session);
   --  Centre the view on the middle of the bounding box of the windows
   --  that are open, if there are any.

   procedure Centre_On_Visible (Item : in out Session) is
      Any : Boolean := False;
      Left, Top, Right, Bottom : Float := 0.0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Open
         then
            declare
               Where : constant Items.Frame := Windows.Details (Each).Where;
            begin
               if Any then
                  Left   := Float'Min (Left, Where.Left);
                  Top    := Float'Min (Top, Where.Top);
                  Right  := Float'Max (Right, Where.Left + Where.Width);
                  Bottom := Float'Max (Bottom, Where.Top + Where.Height);
               else
                  Any    := True;
                  Left   := Where.Left;
                  Top    := Where.Top;
                  Right  := Where.Left + Where.Width;
                  Bottom := Where.Top + Where.Height;
               end if;
            end;
         end if;
      end loop;
      if Any then
         pragma Assert (Right >= Left and then Bottom >= Top);
         Centre_On (Item, (Left + Right) / 2.0, (Top + Bottom) / 2.0);
      end if;
   end Centre_On_Visible;

   procedure Recognize_Kept (Item : in out Session; Which : Items.Slot);
   --  Of a source with a picture: show the words kept for it, or, if
   --  there are none (it was made before they were kept, or the program
   --  stopped before they were found), find them.

   procedure Recognize_Kept (Item : in out Session; Which : Items.Slot) is
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      if not Is_Source (Item, Which)
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

   procedure Save_View (Item : in out Session);
   --  Keep how the canvas is seen, for the project to open at again.

   procedure Save_View (Item : in out Session) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Item.Opened.Current /= 0 and then Widgets.Width_Of (View) > 0.0 then
         Projects.Set_View
           (Item.Nav.Store, Item.Opened.Current, Canvases.Zoom (View),
            Canvases.To_Canvas_X
              (View, Widgets.Width_Of (View) / Pixels / 2.0),
            Canvases.To_Canvas_Y
              (View, Widgets.Height_Of (View) / Pixels / 2.0));
      end if;
   end Save_View;

   procedure Restore_View
     (Item : in out Session; Found : out Boolean);
   --  Put the canvas as it was kept, if it was.

   procedure Restore_View
     (Item : in out Session; Found : out Boolean)
   is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom, X, Y : Float;
   begin
      Projects.Get_View (Item.Nav.Store, Item.Opened.Current, Found, Zoom, X,
                         Y);
      if Found then
         Canvases.Zoom_By
           (View,
            Float'Min (Canvases.Max_Zoom, Float'Max (Canvases.Min_Zoom, Zoom))
              / Canvases.Zoom (View),
            Widgets.Width_Of (View) / Pixels / 2.0,
            Widgets.Height_Of (View) / Pixels / 2.0);
         Centre_On (Item, X, Y);
      end if;
   end Restore_View;

   procedure Enter (Item : in out Session) is
      Found    : Items.Info_List;
      Restored : Boolean;
   begin
      Items.Records.Load (Item.Nav.Store, Item.Opened.Current, Found);
      for I in 1 .. Found.Count loop
         Windows.Assign
           (Item.Windows (I), Found.Items (I),
            Items.Records.Content (Item.Nav.Store, Found.Items (I).Key),
            Items.Sources.Shown_File
              (Item.Nav.Store, Item.Opened.Current, Found.Items (I)));
         Recognize_Kept (Item, I);
         if Found.Items (I).Kind = Items.Source then
            declare
               Kept : Items.Marks.Mark_List;
            begin
               Items.Marks.Load_Marks
                 (Item.Nav.Store, Found.Items (I).Key, Kept);
               Windows.Set_Marks (Item.Windows (I), Kept);
            end;
         end if;
      end loop;
      --  The pictures of those shown first, then the others.
      for Shown in reverse Boolean loop
         for I in 1 .. Found.Count loop
            if (Found.Items (I).State = Items.Open) = Shown then
               Windows.Warm (Item.Windows (I));
            end if;
         end loop;
      end loop;
      Restore_View (Item, Restored);
      if not Restored then
         Centre_On_Visible (Item);
      end if;
      Place_All (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      --  The tray, in the middle of the canvas as it is laid out now.
      Sync (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Links.Enter (Item);
      Links.Update (Item);
   end Enter;

   procedure Save_All (Item : in out Session) is
      Wrote, Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Nav.Store, 0, Force => True, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Item);
      end if;
      Save_View (Item);
   end Save_All;

   procedure Leave (Item : in out Session) is
   begin
      Save_All (Item);
      Links.Leave (Item);
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            Windows.Release (Item.Windows (Which));
            Webshot.Reset (Which);
            Vision.Jobs.Reset (Which);
            Speech.Jobs.Reset (Which);
            if Item.Nav.Fetch_Slot = Which then
               Downloads.Cancel;
            end if;
         end if;
      end loop;
      Widgets.Set_Visible (Item.Dock.Dock_Panel, False);
   end Leave;

   procedure Make
     (Item : in out Session;
      Name : String;
      Kind : Items.Kinds;
      Made : out Natural);
   --  Add, saying which window it is in: 0 if none was free.

   procedure Add
     (Item : in out Session;
      Name : String := Untitled;
      Kind : Items.Kinds := Items.Note)
   is
      Made : Natural;
   begin
      Make (Item, Name, Kind, Made);
   end Add;

   procedure Add_Linked_Source (Item : in out Session; To : Items.Slot) is
      Made  : Natural;
      Added : Boolean;
   begin
      Make (Item, Untitled_Source, Items.Source, Made);
      if Made /= 0 then
         Items.Links.Add_Link
           (Item.Nav.Store,
            (From      => Windows.Details (Item.Windows (To)).Key,
             To        => Windows.Details (Item.Windows (Made)).Key,
             From_Side => Items.Links.Right,
             To_Side   => Items.Links.Left,
             others    => <>),
            Added);
         if Added then
            Links.Reload (Item);
         end if;
      end if;
   end Add_Linked_Source;

   procedure Make
     (Item : in out Session;
      Name : String;
      Kind : Items.Kinds;
      Made : out Natural)
   is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Before : constant Natural := Count (Item);
      Step   : constant Float :=
        Float (Before mod Cascade_Count) * Cascade_Step;
      Middle_X : constant Float :=
        Canvases.To_Canvas_X (View, Widgets.Width_Of (View) / Pixels / 2.0);
      Middle_Y : constant Float :=
        Canvases.To_Canvas_Y (View, Widgets.Height_Of (View) / Pixels / 2.0);
      Wide   : constant Float :=
        (if Kind = Items.Source then Items.Source_Width
         else Items.Default_Width);
      Where  : constant Items.Frame :=
        (Left   => Middle_X - Wide / 2.0 + Step,
         Top    => Middle_Y - Items.Default_Height / 2.0 + Step,
         Width  => Wide,
         Height => Items.Default_Height);
      Free   : Natural := 0;
   begin
      for Which in Items.Slot loop
         if Free = 0 and then not Windows.Is_Assigned (Item.Windows (Which))
         then
            Free := Which;
         end if;
      end loop;
      Made := Free;
      if Free = 0 then
         return;
      end if;
      declare
         Key : constant Items.Id :=
           Items.Records.Create
             (Item.Nav.Store, Item.Opened.Current, Name, Where, Kind => Kind);
      begin
         Windows.Assign
           (Item.Windows (Free),
            (Key   => Key,
             Title => Projects.Titles.To_Bounded_String (Name),
             Where => Where,
             State => Items.Open,
             Kind  => Kind,
             Captured_At => 0,
             Zoom  => 1.0,
             Scroll => 0.0,
             Scroll_Across => 0.0,
             Recognized_At => 0,
             Origin => (if Kind = Items.Source then Items.Unchosen else Items.Remote),
             Page => 0, Page_Count => 0,
             Document => Items.Extensions.Null_Bounded_String),
            "");
         Windows.Place
           (Item.Windows (Free),
            Canvases.Zoom (View), Canvases.Origin_X (View),
            Canvases.Origin_Y (View));
         Touch (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         if Item.Toolbar.Mode = Canvas then
            Windows.Focus_Text (Item.Windows (Free));
         end if;
         Writing.Added (Item, Free);
      end;
   end Make;

   procedure Set_State
     (Item : in out Session; Which : Items.Slot; To : Items.States) is
   begin
      Windows.Set_State (Item.Windows (Which), To);
      Windows.Warm (Item.Windows (Which));
      Items.Records.Set_State
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key, To);
      Windows.Place
        (Item.Windows (Which),
         Item.Nav.Shown_Zoom, Item.Nav.Shown_X, Item.Nav.Shown_Y);
      Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_State;

   procedure Reveal (Item : in out Session; Which : Items.Slot) is
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
   begin
      if Windows.Details (Item.Windows (Which)).State /= Items.Open then
         Set_State (Item, Which, Items.Open);
      end if;
      Centre_On (Item, Where.Left + Where.Width / 2.0,
                 Where.Top + Where.Height / 2.0);
      Windows.Bring_To_Front (Item.Windows (Which));
      Sync (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Reveal;

   procedure Remove (Item : in out Session; Which : Items.Slot) is
   begin
      Writing.Removed (Item, Which);
      if Item.Nav.Fetch_Slot = Which then
         Downloads.Cancel;
      end if;
      Webshot.Reset (Which);
      Vision.Jobs.Reset (Which);
      Speech.Jobs.Reset (Which);
      Items.Records.Delete
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key);
      Windows.Release (Item.Windows (Which));
      Links.Reload (Item);
      Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Remove;

   procedure Window_Asked
     (Item   : in out Session;
      Which  : Items.Slot;
      Action : Windows.Actions);
   --  What a window's buttons asked for.

   procedure Window_Asked
     (Item   : in out Session;
      Which  : Items.Slot;
      Action : Windows.Actions) is
   begin
      if not Gestures.Active (Item) then
         return;
      end if;
      case Action is
         when Windows.None =>
            null;
         when Windows.Minimize =>
            Set_State (Item, Which, Items.Minimized);
         when Windows.Restore =>
            Set_State (Item, Which, Items.Open);
         when Windows.Close =>
            Set_State (Item, Which, Items.Closed);
         when Windows.Capture =>
            Start_Capture (Item, Which);
         when Windows.Speak =>
            Toggle_Dictation (Item, Which);
         when Windows.Link_To_Outline =>
            Section_Links.Open (Item, Which);
         when Windows.Choose_Link =>
            Choose_Origin (Item, Which, Items.Remote);
         when Windows.Choose_File =>
            Pick_File (Item, Which);
         when Windows.Previous_Page =>
            Turn_Page (Item, Which, -1);
         when Windows.Next_Page =>
            Turn_Page (Item, Which, 1);
      end case;
   end Window_Asked;

   procedure Listen (Item : in out Session) is
   begin
      for Which in Items.Slot loop
         Window_Events.On (Item.Windows (Which), Which, Item'Unchecked_Access, Window_Asked'Access);
      end loop;
   end Listen;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Tool (Each) /= Pomarine.Widgets.Pictures.Pointer
         then
            declare
               Box : constant Items.Frame := Windows.Box (Each);
            begin
               if X * Pixels not in Box.Left .. Box.Left + Box.Width
                 or else Y * Pixels not in Box.Top .. Box.Top + Box.Height
               then
                  Windows.Select_Tool (Each, Pomarine.Widgets.Pictures.Pointer);
               end if;
            end;
         end if;
      end loop;
   end Pressed;

   procedure Sync (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Middle : constant Float :=
        Float'Rounding
          ((Widgets.Width_Of (Item.Toolbar.Content_Panel)
            - Style.Tray_Width * Pixels) / 2.0);
   begin
      --  The tray of tools, in the middle of the foot.
      if Middle /= Item.Dock.Tray_Left then
         Item.Dock.Tray_Left := Middle;
         Pomarine.Widgets.Layouts.Set_Layout
           (Item.Dock.Tools, Position => (Left => Middle, others => <>),
            Unit => Pomarine.Widgets.Layouts.Device_Pixels);
      end if;
      if Canvases.Zoom (Item.Canvas_View) /= Item.Nav.Shown_Zoom
        or else Canvases.Origin_X (Item.Canvas_View) /= Item.Nav.Shown_X
        or else Canvases.Origin_Y (Item.Canvas_View) /= Item.Nav.Shown_Y
      then
         Place_All (Item);
      end if;
   end Sync;

   function Source_Ink
     (Item : Session; Which : Items.Slot) return Pomarine.Themes.Slot
   is
      Key  : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
      Rank : Natural := 0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).Kind = Items.Source
           and then Windows.Details (Each).Key <= Key
         then
            Rank := Rank + 1;
         end if;
      end loop;
      return Style.Source_Ink (Rank);
   end Source_Ink;

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Wrote, Any : Boolean := False;
   begin
      Sync (Item);
      if Gestures.Active (Item) then
         for Each of Item.Windows loop
            if Windows.Is_Assigned (Each) then
               Windows.Update (Each);
            end if;
         end loop;
      end if;
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Windows.Details (Item.Windows (Which)).Kind = Items.Source
         then
            Windows.Set_Tag (Item.Windows (Which), Source_Ink (Item, Which));
         end if;
      end loop;
      Poll_Captures (Item);
      Poll_Dictation (Item);
      Writing.Update (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Nav.Store, Now, Force => False, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Item);
      end if;
      Links.Update (Item);
   end Update;

end Viewer.Canvas_Items;
