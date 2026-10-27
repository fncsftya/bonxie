with Ada.Text_IO;
with Goldens;
with Items.Marks;
with Items.Models;
with Items.Records;
with Items.Schema;
with Pomarine.Events;
with Pomarine.Marks;
with Pomarine.View_Models;
with Projects;
with Texts.Documents;
with Vision;

package body Item_Model_Tests is

   package Models renames Items.Models;
   package Parts renames Pomarine.View_Models;
   package Docs renames Texts.Documents;

   use type Parts.Version_Number;
   use type Items.Id;
   use type Pomarine.Events.Milliseconds;
   use all type Items.Models.Dictations;
   use all type Items.Models.Captures;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   function Number (Value : Integer) return String
   is (Value'Image (2 .. Value'Image'Last));

   --  A fraction as a whole number of hundredths.
   function Percent (Value : Float) return String
   is (Number (Integer (Float'Rounding (Value * 100.0))));

   function Place_Of (Text : String) return String
   is (Text (Text'First .. Text'First + 4));
   --  The first part of a Wide: "15,17".

   function Size_Of (Text : String) return String
   is (Text (Text'First + 6 .. Text'Last));
   --  And the rest: "280x200".

   function Wide (Where : Items.Frame) return String
   is (Number (Integer (Where.Left))
       & ","
       & Number (Integer (Where.Top))
       & " "
       & Number (Integer (Where.Width))
       & "x"
       & Number (Integer (Where.Height)));

   --  A database in memory, a project in it, and an item of the kind, as it was kept.
   procedure Make (Store : in out Projects.Store; Kind : Items.Kinds; Result : out Items.Info) is
      Project : Projects.Id;
      Found   : Items.Info_List;
      Key     : Items.Id;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Project := Projects.Create (Store, "Test");
      Key :=
        Items.Records.Create
          (Store, Project, "An item", (Left => 10.0, Top => 20.0, Width => 280.0, Height => 200.0), Kind => Kind);
      Items.Records.Load (Store, Project, Found);
      Result := Found (1);
      pragma Assert (Result.Key = Key);
   end Make;

   --  What is kept of the item now.
   function Kept (Store : Projects.Store; Key : Items.Id) return Items.Info is
      Found : Items.Info_List;
   begin
      Items.Records.Load (Store, 1, Found);
      for Each of Found.Slice loop
         if Each.Key = Key then
            return Each;
         end if;
      end loop;
      raise Program_Error with "not kept";
   end Kept;

   procedure Type_In (Item : in out Models.Item; Words : String) is
      Doc : constant Docs.Document_Access := Models.Content_Document (Item);
   begin
      Docs.Replace (Doc.all, (Paragraph => 1, Index => 1), Docs.Text_End (Doc.all), Words);
   end Type_In;

   procedure Notes is
      Store : Projects.Store;
      Info  : Items.Info;
      Item  : Models.Item;
   begin
      Make (Store, Items.Note, Info);
      Check ("item-model-unassigned", "FALSE", Image (Models.Is_Assigned (Item)));
      Models.Assign (Item, Info, "one two  three");
      Check
        ("item-model-note",
         "TRUE An item 'one two  three' 3 ''",
         Image (Models.Is_Assigned (Item))
         & " "
         & Projects.Titles.To_String (Models.Details (Item).Title)
         & " '"
         & Models.Text (Item)
         & "' "
         & Number (Models.Words (Item))
         & " '"
         & Models.Status (Item)
         & "'");
      Check ("item-model-note-where", "10,20 280x200", Wide (Models.Details (Item).Where));

      --  What is typed is the text, and counted.
      Type_In (Item, "alpha beta");
      Models.Refresh (Item);
      Check ("item-model-typed", "alpha beta 2", Models.Text (Item) & " " & Number (Models.Words (Item)));
      Models.Set_Title_Text (Item, "Renamed");
      Check ("item-model-title", "Renamed", Projects.Titles.To_String (Models.Details (Item).Title));

      --  A failure to dictate is told until the text is changed.
      Models.Set_Dictation (Item, Failed, "no microphone");
      Check ("item-model-dictation-failed", "Could not dictate: no microphone", Models.Status (Item));
      Models.Refresh (Item);
      Check ("item-model-dictation-kept", "Could not dictate: no microphone", Models.Status (Item));
      Type_In (Item, "gamma");
      Models.Refresh (Item);
      Check
        ("item-model-dictation-cleared",
         "SILENT ''",
         Models.Dictation (Item)'Image & " '" & Models.Status (Item) & "'");

      --  What is going on is told while it is, whatever is typed.
      Models.Set_Dictation (Item, Preparing);
      Check
        ("item-model-dictation-preparing",
         "Getting ready... FALSE",
         Models.Status (Item) & " " & Image (Models.Shows_Progress (Item)));
      Models.Set_Dictation (Item, Listening);
      Models.Set_Level (Item, 0.53);
      Check
        ("item-model-dictation-listening",
         "Listening... TRUE 55",
         Models.Status (Item) & " " & Image (Models.Shows_Progress (Item)) & " " & Percent (Models.Progress (Item)));
      Type_In (Item, "delta");
      Models.Refresh (Item);
      Check ("item-model-dictation-typing", "LISTENING", Models.Dictation (Item)'Image);
      Models.Set_Dictation (Item, Transcribing);
      Check
        ("item-model-dictation-transcribing",
         "Transcribing... FALSE",
         Models.Status (Item) & " " & Image (Models.Shows_Progress (Item)));
      Models.Set_Dictation (Item, Silent);
      Check ("item-model-dictation-done", "''", "'" & Models.Status (Item) & "'");

      --  The level only counts while listening.
      Models.Set_Level (Item, 0.9);
      Check ("item-model-level-silent", "0", Percent (Models.Progress (Item)));

      Models.Release (Item);
      Check ("item-model-released", "FALSE", Image (Models.Is_Assigned (Item)));
   end Notes;

   procedure Placing is
      Store : Projects.Store;
      Info  : Items.Info;
      Item  : Models.Item;
      Wrote : Boolean;
      Seen  : Parts.Version_Number;
   begin
      Make (Store, Items.Note, Info);
      Models.Assign (Item, Info, "");
      Seen := Models.Where_Version (Item);
      Models.Move (Item, 5.0, -3.0);
      Check
        ("item-model-moved",
         "15,17 280x200 TRUE",
         Wide (Models.Details (Item).Where) & " " & Image (Models.Where_Version (Item) /= Seen));

      --  Written once it is let go.
      Models.Report (Item, (Dragging => True, others => <>));
      Models.Flush (Item, Store, 100, Force => False, Wrote => Wrote);
      Check ("item-model-moving", "FALSE 10,20", Image (Wrote) & " " & Place_Of (Wide (Kept (Store, Info.Key).Where)));
      Models.Report (Item, (others => <>));
      Models.Flush (Item, Store, 200, Force => False, Wrote => Wrote);
      Check
        ("item-model-moved-kept", "TRUE 15,17", Image (Wrote) & " " & Place_Of (Wide (Kept (Store, Info.Key).Where)));
      Models.Flush (Item, Store, 300, Force => False, Wrote => Wrote);
      Check ("item-model-moved-once", "FALSE", Image (Wrote));

      --  Not under the least; and what the corner asks for is remembered while it is held.
      Models.Resize (Item, -500.0, -500.0, Still => True);
      Check
        ("item-model-least",
         "15,17 160x100 TRUE",
         Wide (Models.Details (Item).Where) & " " & Image (Models.Is_Resizing (Item)));
      Models.Resize (Item, 300.0, 300.0, Still => True);
      Check ("item-model-still-least", "160x100", Size_Of (Wide (Models.Details (Item).Where)));
      Models.Resize (Item, 150.0, 150.0, Still => True);
      Check ("item-model-back", "230x150", Size_Of (Wide (Models.Details (Item).Where)));

      --  Let go, it is as it is.
      Models.Resize (Item, 0.0, 0.0, Still => False);
      Models.Report (Item, (others => <>));
      Models.Resize (Item, 10.0, 10.0, Still => False);
      Check
        ("item-model-let-go",
         "FALSE 240x160",
         Image (Models.Is_Resizing (Item)) & " " & Size_Of (Wide (Models.Details (Item).Where)));
   end Placing;

   procedure Sources is
      Store : Projects.Store;
      Info  : Items.Info;
      Item  : Models.Item;
      Seen  : Parts.Version_Number;
      Found : Vision.Result;
      Path  : constant String := "/tmp/bonxie-model-test.txt";
      File  : Ada.Text_IO.File_Type;
   begin
      Make (Store, Items.Source, Info);
      Models.Assign (Item, Info, "");
      Models.Set_Origin (Item, Items.Unchosen);
      Check
        ("item-model-unchosen",
         "TRUE Choose where it comes from",
         Image (Models.Is_Unchosen (Item)) & " " & Models.Status (Item));
      Models.Set_Origin (Item, Items.Remote);
      Check
        ("item-model-remote",
         "FALSE Press Return to capture",
         Image (Models.Is_Unchosen (Item)) & " " & Models.Status (Item));
      Models.Set_Origin (Item, Items.Local);
      Check ("item-model-local", "Choose a file", Models.Status (Item));

      --  A picture is taken.
      Models.Set_Capture (Item, Busy);
      Models.Set_Progress (Item, 0.5);
      Check
        ("item-model-busy",
         "Capturing... TRUE 50",
         Models.Status (Item) & " " & Image (Models.Shows_Progress (Item)) & " " & Percent (Models.Progress (Item)));
      Seen := Models.Picture_Version (Item);
      Found.Count := 3;
      Models.Set_Recognized (Item, Found);
      Check ("item-model-words", "3", Number (Models.Recognized (Item).Count));
      Models.Set_Capture (Item, Ready, "/tmp/taken.png", At_Time => 1_760_000_000);
      Check
        ("item-model-ready",
         "Captured 9 Oct 2025 /tmp/taken.png TRUE FALSE TRUE 0",
         Models.Status (Item)
         & " "
         & Models.Picture_File (Item)
         & " "
         & Image (Models.Shows_Picture (Item))
         & " "
         & Image (Models.Shows_Progress (Item))
         & " "
         & Image (Models.Picture_Version (Item) /= Seen)
         & " "
         & Number (Models.Recognized (Item).Count));
      Check ("item-model-captured", "1760000000", Number (Integer (Models.Details (Item).Captured_At)));
      Models.Set_Capture (Item, Failed, Detail => "no network");
      Check ("item-model-failed", "Failed: no network", Models.Status (Item));

      --  A document of pages.
      Models.Set_Pages (Item, "pdf", 2, 5);
      Models.Set_Capture (Item, Ready, "/tmp/book.pdf", At_Time => 1_760_000_000);
      Check
        ("item-model-pages",
         "Page 2 of 5 TRUE FALSE",
         Models.Status (Item) & " " & Image (Models.Wants_Pages (Item)) & " " & Image (Models.Is_Paged (Item)));
      Models.Pages_Opened (Item, True);
      Check ("item-model-paged", "TRUE", Image (Models.Is_Paged (Item)));
      Models.Pages_Opened (Item, False, "not a PDF");
      Check
        ("item-model-unopened",
         "Failed: not a PDF FALSE",
         Models.Status (Item) & " " & Image (Models.Shows_Picture (Item)));

      --  How it is zoomed, and what the person has in hand.
      Seen := Models.Zoom_Version (Item);
      Models.Set_Zoom (Item, 2.0);
      Check
        ("item-model-zoom",
         "200 TRUE",
         Percent (Models.Details (Item).Zoom) & " " & Image (Models.Zoom_Version (Item) /= Seen));
      Seen := Models.Zoom_Version (Item);
      Models.Set_Zoom (Item, 2.0);
      Check ("item-model-zoom-again", "FALSE", Image (Models.Zoom_Version (Item) /= Seen));
      Seen := Models.Tool_Version (Item);
      Models.Select_Tool (Item, Models.Highlighter);
      Check
        ("item-model-tool",
         "HIGHLIGHTER TRUE",
         Models.Tool (Item)'Image & " " & Image (Models.Tool_Version (Item) /= Seen));
      Models.Set_State (Item, Items.Minimized);
      Check
        ("item-model-tool-put-away",
         "POINTER MINIMIZED",
         Models.Tool (Item)'Image & " " & Models.Details (Item).State'Image);

      --  A text file is shown as text.
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, "hello text");
      Ada.Text_IO.Close (File);
      Models.Set_Pages (Item, "txt", 0, 0);
      Models.Show_Text (Item, Path, 1_760_000_000);
      Check
        ("item-model-text",
         "TRUE 'hello text" & ASCII.LF & "' '' Captured 9 Oct 2025",
         Image (Models.Is_Text_Source (Item))
         & " '"
         & Models.Shown_Text (Item)
         & "' '"
         & Models.Picture_File (Item)
         & "' "
         & Models.Status (Item));
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      Ada.Text_IO.Delete (File);
   end Sources;

   procedure Writing is
      Store : Projects.Store;
      Info  : Items.Info;
      Item  : Models.Item;
      Wrote : Boolean;
   begin
      Make (Store, Items.Note, Info);
      Models.Assign (Item, Info, "");

      --  Not while it is being typed in, until it has been left alone for a moment.
      Type_In (Item, "first");
      Models.Report (Item, (Typing => True, others => <>));
      Models.Flush (Item, Store, 1_000, Force => False, Wrote => Wrote);
      Check ("item-model-typing", "FALSE ''", Image (Wrote) & " '" & Items.Records.Content (Store, Info.Key) & "'");
      Models.Flush (Item, Store, 1_000 + Models.Idle_Delay - 1, Force => False, Wrote => Wrote);
      Check ("item-model-typing-waits", "FALSE", Image (Wrote));
      Models.Flush (Item, Store, 1_000 + Models.Idle_Delay, Force => False, Wrote => Wrote);
      Check ("item-model-typing-left", "TRUE first", Image (Wrote) & " " & Items.Records.Content (Store, Info.Key));

      --  At once, if it is not being typed in; and whenever it is asked.
      Type_In (Item, "second");
      Models.Report (Item, (others => <>));
      Models.Flush (Item, Store, 5_000, Force => False, Wrote => Wrote);
      Check ("item-model-written", "TRUE second", Image (Wrote) & " " & Items.Records.Content (Store, Info.Key));
      Models.Hold_Typing (Item, True);
      Type_In (Item, "third");
      Models.Flush (Item, Store, 6_000, Force => False, Wrote => Wrote);
      Check ("item-model-held", "FALSE second", Image (Wrote) & " " & Items.Records.Content (Store, Info.Key));
      Models.Flush (Item, Store, 6_001, Force => True, Wrote => Wrote);
      Check ("item-model-forced", "TRUE third", Image (Wrote) & " " & Items.Records.Content (Store, Info.Key));
      Models.Hold_Typing (Item, False);

      --  How far it is scrolled is written once it has stayed.
      Models.Report (Item, (Scroll => 12.0, others => <>));
      Models.Flush (Item, Store, 10_000, Force => False, Wrote => Wrote);
      Check ("item-model-scrolling", "FALSE 0", Image (Wrote) & " " & Number (Integer (Kept (Store, Info.Key).Scroll)));
      Models.Flush (Item, Store, 10_000 + Models.Idle_Delay, Force => False, Wrote => Wrote);
      Check ("item-model-scrolled", "TRUE 12", Image (Wrote) & " " & Number (Integer (Kept (Store, Info.Key).Scroll)));
      --  Not before the text has been scrolled to where it was.
      Models.Report (Item, (Scroll => 30.0, others => <>));
      Models.Flush (Item, Store, 20_000, Force => True, Wrote => Wrote);
      Check
        ("item-model-scrolled-forced",
         "TRUE 30",
         Image (Wrote) & " " & Number (Integer (Kept (Store, Info.Key).Scroll)));
      Models.Release (Item);

      --  A source: its zoom, once the slider is let go, and its marks, once the highlighter is.
      declare
         Source : Models.Item;
         Made   : Items.Marks.Mark_List;
         Loaded : Items.Marks.Mark_List;
         Origin : Items.Info_List;
         Seen   : Items.Info;
      begin
         Items.Records.Load (Store, 1, Origin);
         Seen := Origin (1);
         Seen.Kind := Items.Source;
         Models.Assign (Source, Seen, "");
         Models.Set_Zoom (Source, 2.0);
         Models.Report (Source, (Zooming => True, others => <>));
         Models.Flush (Source, Store, 100, Force => False, Wrote => Wrote);
         Check ("item-model-zooming", "FALSE", Image (Wrote));
         Models.Report (Source, (others => <>));
         Models.Flush (Source, Store, 200, Force => False, Wrote => Wrote);
         Check ("item-model-zoom-kept", "TRUE", Image (Wrote));

         Pomarine.Marks.Reserve (Made.Marks, 1);
         Made.Count := 1;
         Made.Marks.Data (1) := (Left => 0.1, Right => 0.4, Y => 0.5, Page => 1, others => <>);
         Models.Report (Source, (Marking => True, others => <>));
         Models.Report_Marks (Source, Made, Version => 1);
         Models.Flush (Source, Store, 300, Force => False, Wrote => Wrote);
         Items.Marks.Load_Marks (Store, Seen.Key, Loaded);
         Check ("item-model-marking", "FALSE 0", Image (Wrote) & " " & Number (Loaded.Count));
         Models.Report (Source, (others => <>));
         Models.Flush (Source, Store, 400, Force => False, Wrote => Wrote);
         Items.Marks.Load_Marks (Store, Seen.Key, Loaded);
         Check ("item-model-marked", "TRUE 1", Image (Wrote) & " " & Number (Loaded.Count));

         --  The marks the window was given are not the person's.
         Models.Marks_Shown_As (Source, 7);
         Models.Flush (Source, Store, 500, Force => False, Wrote => Wrote);
         Check ("item-model-marks-given", "FALSE", Image (Wrote));
         Models.Release (Source);
      end;
   end Writing;

end Item_Model_Tests;
