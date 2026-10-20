with Ada.Directories;
with Ada.Strings.Fixed;
with Pomarine.Page_Builds;
with SDL3.Events;
with SDL3.Pictures.Jobs;
with Goldens;
with Ada.Text_IO;
with Item_Tests;
with Items;
with Source_Finder;
with Source_Finding;
with Source_Links;
with Viewer;
with Viewer.Canvas_Links;
with Viewer.Canvas_Windows;
with Viewer.Documents;
with Viewer.Found_Sources;
with Viewer.Home_Screen;
with Viewer.Project_Screen;
with Viewer.Settings;

package body Finding_Tests is

   package Finding renames Source_Finding;
   package Events renames SDL3.Events;
   package Windows renames Viewer.Canvas_Windows;
   package Links renames Viewer.Canvas_Links;
   package Docs renames Viewer.Documents;
   package Screen renames Viewer.Found_Sources;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Prefs renames Viewer.Settings;
   package Pictures renames Goldens.Images;

   use type SDL3.Events.Milliseconds;
   use type Items.Kinds;
   use type Source_Finder.States;
   use type Items.Origins;

   procedure Check (Name : String; Expected, Actual : String)
     renames Goldens.Check_Text;

   LF : constant Character := Character'Val (10);

   function Joined (Found : Finding.Query_List) return String is
      Text : String (1 .. 4 * Finding.Max_Query) := [others => ' '];
      Last : Natural := 0;
   begin
      for Each in 1 .. Found.Count loop
         declare
            One : constant String := Finding.Query_Texts.To_String (Found.Items (Each)) & "|";
         begin
            Text (Last + 1 .. Last + One'Length) := One;
            Last := Last + One'Length;
         end;
      end loop;
      return Text (1 .. Last);
   end Joined;

   procedure Reading_Queries is
      Found : Finding.Query_List;
      Valid : Boolean;

      procedure Read (Name, Reply, Expected : String) is
      begin
         Finding.Parse_Queries (Reply, Found, Valid);
         Check (Name & "-valid", Boolean'Image (Expected /= ""), Boolean'Image (Valid));
         Check (Name, Expected, Joined (Found));
      end Read;
   begin
      --  What cannot be used.
      Read ("queries-prose", "I could not think of any.", "");
      Read ("queries-empty", "{""queries"": []}", "");
      Read ("queries-blank", "{""queries"": [""   "", ""x""]}", "");
      Read ("queries-wrong-key", "{""query"": [""mars rover""]}", "");
      Read ("queries-not-strings", "{""queries"": [1, 2]}", "");
      Read ("queries-unclosed", "{""queries"": [""mars rover"", ""ice", "");
      Read ("queries-list", "[""mars rover""]", "");

      --  What can: fences and words round the object, tidied queries, the
      --  same one twice (in another case) once, no more than three.
      Read ("queries-fenced",
            "Here:" & LF & "```json" & LF & "{""queries"": [""  mars rover \n" & "landing  site "", "
            & """Mars Rover Landing Site"", ""perseverance sample tubes"", ""jezero crater delta"", ""a fourth one""]}"
            & LF & "```",
            "mars rover landing site|perseverance sample tubes|jezero crater delta|");

      --  A model that thinks aloud: braces in what it says first, one never
      --  closed, and an object that is not the reply, are passed over.
      Read ("queries-thought",
            "Let me think {about} the {passage: whales" & LF & "Maybe {""topic"": ""whales""} is it." & LF
            & "{""queries"": [""whale song research""]}",
            "whale song research|");
      Read ("queries-unclosed-first", "I will { try" & LF & "{""queries"": [""whale song research""]}",
            "whale song research|");

      --  A query is cut to its limit, whole characters only.
      declare
         Long : constant String :=
           [1 .. Finding.Max_Query - 1 => 'a'] & Character'Val (16#C3#) & Character'Val (16#A9#);
      begin
         Finding.Parse_Queries ("{""queries"": [""" & Long & """]}", Found, Valid);
         Check ("queries-cut-valid", "TRUE", Boolean'Image (Valid));
         Check ("queries-cut", Integer'Image (Finding.Max_Query - 1),
               Integer'Image (Finding.Query_Texts.Length (Found.Items (1))));
      end;

      --  The prompts: the text is cut, the schema is in the system prompt.
      declare
         Big : constant String := [1 .. 3 * Finding.Max_Text => 'x'];
      begin
         Check ("queries-prompt-cut", "TRUE",
                Boolean'Image (Finding.Query_Prompt (Big)'Length < Finding.Max_Text + 300));
      end;
      Check ("queries-system-schema", "TRUE",
             Boolean'Image (Finding.Query_System_Prompt'Length > 0
                            and then Ada.Strings.Fixed.Index (Finding.Query_System_Prompt, """queries""") > 0));
   end Reading_Queries;

   procedure Reading_Banners is
      Covered : Boolean;
      Pressed : Finding.Button_Texts.Bounded_String;
      Valid   : Boolean;

      procedure Read (Name, Reply : String; Expect_Valid, Expect_Covered : Boolean; Expected : String := "") is
      begin
         Finding.Parse_Banner (Reply, Covered, Pressed, Valid);
         Check (Name & "-valid", Boolean'Image (Expect_Valid), Boolean'Image (Valid));
         Check (Name & "-covered", Boolean'Image (Expect_Covered), Boolean'Image (Covered));
         Check (Name & "-button", Expected, Finding.Button_Texts.To_String (Pressed));
      end Read;
   begin
      Read ("banner-prose", "There is a cookie banner.", False, False);
      Read ("banner-missing", "{""button"": ""Accept""}", False, False);
      Read ("banner-not-boolean", "{""covered"": ""yes"", ""button"": ""Accept""}", False, False);
      Read ("banner-covered", "{""covered"": true, ""button"": ""Reject all""}", True, True, "Reject all");
      Read ("banner-clear", "{""covered"": false, ""button"": """"}", True, False);
      --  Covered by what has no button to press is no use: not covered.
      Read ("banner-no-button", "{""covered"": true, ""button"": ""   ""}", True, False);
      Read ("banner-no-key", "{""covered"": true}", True, False);
      Read ("banner-button-ignored", "{""covered"": false, ""button"": ""Accept""}", True, False);
      --  Tidied, fenced, after thoughts with braces in them.
      Read ("banner-thought",
            "The page has {a banner} on it." & LF & "```json" & LF
            & "{""covered"": true, ""button"": ""  Only" & "\n" & "  necessary  ""}" & LF & "```",
            True, True, "Only necessary");
      Check ("banner-prompt-has-words", "TRUE",
             Boolean'Image (Ada.Strings.Fixed.Index (Finding.Banner_Prompt ("We use cookies"), "We use cookies") > 0));
      Check ("banner-system-schema", "TRUE",
             Boolean'Image (Ada.Strings.Fixed.Index (Finding.Banner_System_Prompt, """covered""") > 0));
   end Reading_Banners;

   procedure Choosing_Links is
      procedure Direct (Name, URL, Expected : String) is
      begin
         Check (Name, Expected, Source_Links.Direct_Document (URL));
      end Direct;

      procedure Document (Name, URL : String; Expected : Boolean) is
      begin
         Check (Name, Boolean'Image (Expected), Boolean'Image (Source_Links.Is_Document (URL)));
      end Document;
   begin
      --  arXiv: the abstract, the HTML and the PDF are all the PDF, with the ending the project knows it by.
      Direct ("link-arxiv-abs", "https://arxiv.org/abs/2501.17078", "https://arxiv.org/pdf/2501.17078.pdf");
      Direct ("link-arxiv-version", "https://arxiv.org/abs/2501.17078v2?context=astro-ph.GA#x",
              "https://arxiv.org/pdf/2501.17078v2.pdf");
      Direct ("link-arxiv-old", "http://www.arxiv.org/abs/astro-ph/0601001",
              "https://arxiv.org/pdf/astro-ph/0601001.pdf");
      Direct ("link-arxiv-html", "https://arxiv.org/html/2501.17078v1", "https://arxiv.org/pdf/2501.17078v1.pdf");
      Direct ("link-arxiv-viewer", "https://arxiv.org/pdf/2610.18960v1", "https://arxiv.org/pdf/2610.18960v1.pdf");
      Direct ("link-arxiv-already", "https://arxiv.org/pdf/2610.18960v1.pdf", "https://arxiv.org/pdf/2610.18960v1.pdf");
      Direct ("link-arxiv-listing", "https://arxiv.org/list/astro-ph.GA/recent", "");
      Direct ("link-arxiv-home", "https://arxiv.org/", "");
      Direct ("link-other-host", "https://notarxiv.org/abs/2501.17078", "");

      --  Taylor & Francis: the preview pages of an article are its PDF.
      Direct ("link-tandf-abs", "https://www.tandfonline.com/doi/abs/10.1080/00107514.2020.1234567",
              "https://www.tandfonline.com/doi/pdf/10.1080/00107514.2020.1234567");
      Direct ("link-tandf-full", "https://tandfonline.com/doi/full/10.1080/00107514.2020.1234567?scroll=top",
              "https://www.tandfonline.com/doi/pdf/10.1080/00107514.2020.1234567");
      Direct ("link-tandf-epdf", "https://www.tandfonline.com/doi/epdf/10.1080/x.y",
              "https://www.tandfonline.com/doi/pdf/10.1080/x.y");
      Direct ("link-tandf-toc", "https://www.tandfonline.com/toc/tcph20/current", "");
      Direct ("link-not-a-link", "", "");

      Document ("link-ends-pdf", "https://example.org/files/paper.pdf", True);
      Document ("link-ends-pdf-case", "https://example.org/files/Paper.PDF", True);
      Document ("link-ends-pdf-query", "https://example.org/files/paper.pdf?download=1#page=2", True);
      Document ("link-pdf-segment", "https://example.org/pdf/12345", True);
      Document ("link-epdf-segment", "https://example.org/doi/epdf/10.1/xy", True);
      Document ("link-pdf-last", "https://example.org/files/pdf", False);
      Document ("link-pdf-in-name", "https://example.org/pdfs-are-fun/page", False);
      Document ("link-html", "https://example.org/files/paper.html", False);
      Document ("link-pdf-in-query", "https://example.org/read?file=paper.pdf", False);
      Document ("link-empty", "", False);

      Check ("link-file-pdf", "TRUE", Boolean'Image (Source_Links.Is_PDF_File ("%PDF-1.7")));
      Check ("link-file-html", "FALSE", Boolean'Image (Source_Links.Is_PDF_File ("<!doc")));
      Check ("link-file-short", "FALSE", Boolean'Image (Source_Links.Is_PDF_File ("%PD")));
      Check ("link-name", "paper-final", Source_Links.Name_Of ("https://example.org/files/paper-final.pdf?x=1#y"));
      Check ("link-name-folder", "files", Source_Links.Name_Of ("https://example.org/files/"));
      Check ("link-name-none", "", Source_Links.Name_Of ("https://example.org"));
   end Choosing_Links;

   procedure Reading_Evaluations is
      Result : Finding.Evaluation;
      Valid  : Boolean;

      procedure Read (Name, Reply : String; Expected_Valid : Boolean; Percent : Natural := 0) is
      begin
         Finding.Parse_Evaluation (Reply, Result, Valid);
         Check (Name & "-valid", Boolean'Image (Expected_Valid), Boolean'Image (Valid));
         Check (Name & "-percent", Natural'Image (Percent), Natural'Image (Finding.Percent (Result)));
      end Read;
   begin
      Read ("evaluation-prose", "Good page.", False);
      Read ("evaluation-missing", "{""relevance"": 9, ""support"": 9, ""reason"": ""x""}", False);
      Read ("evaluation-too-high", "{""relevance"": 11, ""support"": 9, ""quality"": 9, ""reason"": ""x""}", False);
      Read ("evaluation-negative", "{""relevance"": -1, ""support"": 9, ""quality"": 9, ""reason"": ""x""}", False);
      Read ("evaluation-fraction", "{""relevance"": 8.5, ""support"": 9, ""quality"": 9, ""reason"": ""x""}", False);
      Read ("evaluation-string", "{""relevance"": ""9"", ""support"": 9, ""quality"": 9, ""reason"": ""x""}", False);

      --  The marks are a fraction of the most there can be, rounded.
      Read ("evaluation-full", "{""relevance"": 10, ""support"": 10, ""quality"": 10, ""reason"": """"}", True, 100);
      Read ("evaluation-none", "{""relevance"": 0, ""support"": 0, ""quality"": 0, ""reason"": """"}", True, 0);
      Read ("evaluation-mixed", "{""relevance"": 9, ""support"": 8, ""quality"": 7, ""reason"": ""r""}", True, 80);
      Check ("evaluation-80-passes", "TRUE", Boolean'Image (Finding.Passes (Result)));
      Read ("evaluation-eight", "{""relevance"": 8, ""support"": 8, ""quality"": 8, ""reason"": ""r""}", True, 80);
      Read ("evaluation-under", "{""relevance"": 8, ""support"": 8, ""quality"": 7, ""reason"": ""r""}", True, 77);
      Check ("evaluation-77-fails", "FALSE", Boolean'Image (Finding.Passes (Result)));

      --  Words about the object, fences, a reason tidied and one left out.
      Read ("evaluation-fenced",
            "```json" & LF & "{""relevance"": 10, ""support"": 9, ""quality"": 9, ""reason"": ""  Good\n"
            & "  review. ""}" & LF & "```", True, 93);
      Check ("evaluation-reason", "Good review.", Finding.Reason_Texts.To_String (Result.Reason));
      Read ("evaluation-thought",
            "Relevance seems {high}. {""relevance"": 11} no." & LF
            & "{""relevance"": 9, ""support"": 8, ""quality"": 8, ""reason"": ""ok""}", True, 83);
      Read ("evaluation-no-reason", "{""relevance"": 10, ""support"": 10, ""quality"": 10}", True, 100);
      Check ("evaluation-reason-empty", "", Finding.Reason_Texts.To_String (Result.Reason));
   end Reading_Evaluations;

   Width  : constant := 720;
   Height : constant := 480;
   --  Of the window, in points; the toolbar is 44 high at the top.

   Picture_A : constant String := "/tmp/bonxie-finding/found-1.png";
   Picture_B : constant String := "/tmp/bonxie-finding/found-2.png";
   --  Pictures of pages, as the finder keeps them.

   procedure Move_To (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>));
   end Move_To;

   procedure Click_At (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Move_To (Session, X, Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Click_At;

   procedure Type_In (Session : in out Viewer.Session; Text : String) is
   begin
      Viewer.Handle (Session, Events.Text_Event (Text));
   end Type_In;

   Now : SDL3.Events.Milliseconds := 100;

   procedure Settle (Session : in out Viewer.Session) is
      Drawn : Pictures.Image;
   begin
      Now := Now + 100;
      Viewer.Tick (Session, Now);
      Viewer.Render (Session, Drawn);
      SDL3.Pictures.Jobs.Wait_Until_Idle;
      Pomarine.Page_Builds.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
      Viewer.Tick (Session, Now);
   end Settle;

   procedure Snap (Session : in out Viewer.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   function Flag (Value : Boolean) return String is (Boolean'Image (Value));

   procedure Start (Session : in out Viewer.Session; AI : Boolean) is
   begin
      --  The same time every test begins at, for the caret to blink alike.
      Now := 100;
      Viewer.Open (Session, "", Width, Height, 2.0);
      if AI then
         Prefs.Open_Settings (Session);
         Prefs.Choose_AI_Enabled (Session, True);
         Prefs.Close_Settings (Session);
      end if;
      Home.New_Project (Session);
      Proj.Set_Mode (Session, Viewer.Canvas);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Source_Finder.Reset;
      Ada.Directories.Create_Path ("/tmp/bonxie-finding");
      Ada.Directories.Copy_File ("golden/canvas-1x.png", Picture_A, "mode=overwrite");
      Ada.Directories.Copy_File ("golden/canvas-panned.png", Picture_B, "mode=overwrite");
   end Start;

   procedure Click_Find (Session : in out Viewer.Session; Row : Positive) is
      Shown : Boolean;
      X, Y  : Float;
   begin
      Windows.Find_Sources_Point (Session, Row, Shown, X, Y);
      Check ("finding-button-shown", "TRUE", Flag (Shown));
      Click_At (Session, X, Y);
      Settle (Session);
   end Click_Find;

   procedure Click_Toast (Session : in out Viewer.Session) is
      X, Y : Float;
   begin
      Screen.Toast_Action_Point (Session, X, Y);
      Click_At (Session, X, Y);
      Settle (Session);
   end Click_Toast;

   procedure Click_Review_Row (Session : in out Viewer.Session; Row : Positive) is
      X, Y : Float;
   begin
      Screen.Review_Row_Point (Session, Row, X, Y);
      Click_At (Session, X, Y);
      Settle (Session);
   end Click_Review_Row;

   procedure Button is
      Session : Viewer.Session;
   begin
      --  With the AI off the button is there and off, whatever the text.
      Start (Session, AI => False);
      Windows.Add_Item (Session, "Note");
      Check ("finding-off-empty", "FALSE", Flag (Windows.Find_Sources_Enabled (Session, 1)));
      Type_In (Session, "Whales sing");
      Settle (Session);
      Check ("finding-off-text", "FALSE", Flag (Windows.Find_Sources_Enabled (Session, 1)));
      Snap (Session, "finding-button-ai-off");
      Proj.Close_Project (Session);

      --  With it on, it is off until there is text, and spaces are not.
      Prefs.Open_Settings (Session);
      Prefs.Choose_AI_Enabled (Session, True);
      Prefs.Close_Settings (Session);
      Home.New_Project (Session);
      Proj.Set_Mode (Session, Viewer.Canvas);
      Windows.Add_Item (Session, "Note");
      Settle (Session);
      Check ("finding-on-empty", "FALSE", Flag (Windows.Find_Sources_Enabled (Session, 1)));
      Snap (Session, "finding-button-empty");
      Type_In (Session, "   ");
      Settle (Session);
      Check ("finding-on-spaces", "FALSE", Flag (Windows.Find_Sources_Enabled (Session, 1)));
      Type_In (Session, "Whales sing");
      Settle (Session);
      Check ("finding-on-text", "TRUE", Flag (Windows.Find_Sources_Enabled (Session, 1)));
      Snap (Session, "finding-button-ready");

      --  Off, it takes no click.
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Check ("finding-write-on", "TRUE", Flag (Docs.Find_Sources_Enabled (Session, 1)));
      Snap (Session, "finding-write-button");
      declare
         Shown : Boolean;
         X, Y  : Float;
      begin
         Docs.Find_Sources_Point (Session, 1, Shown, X, Y);
         Check ("finding-write-shown", "TRUE", Flag (Shown));
      end;
      Proj.Set_Mode (Session, Viewer.Canvas);

      --  No model chosen: a click says so, and the toast is put away by its button.
      Click_Find (Session, 1);
      Check ("finding-no-model-toast", "TRUE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-no-model-message", "Choose an AI model in Settings", Screen.Toast_Message (Session));
      Check ("finding-no-model-action", "Dismiss", Screen.Toast_Action (Session));
      Check ("finding-no-model-idle", "IDLE", Source_Finder.States'Image (Source_Finder.State));
      Snap (Session, "finding-toast-no-model");
      Click_Toast (Session);
      Check ("finding-no-model-dismissed", "FALSE", Flag (Screen.Toast_Shown (Session)));
   end Button;

   procedure Review is
      Session : Viewer.Session;
      X_First, Y_First : Float;
   begin
      Start (Session, AI => True);
      Windows.Add_Item (Session, "Note");
      Type_In (Session, "Whales sing");
      Settle (Session);
      Source_Finder.Offer ("Whales of the world", "https://example.org/whales", Picture_A,
                           "Covers whale species and their songs", 92);
      Source_Finder.Offer ("Song of the sea", "https://example.net/song", Picture_B, "", 85);
      Screen.Adopt (Session, 1);
      Settle (Session);
      Check ("finding-found-toast", "TRUE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-found-message", "2 sources found", Screen.Toast_Message (Session));
      Check ("finding-found-action", "Review", Screen.Toast_Action (Session));
      Snap (Session, "finding-toast-found");

      --  Its button shows the list: the best first, then adding all, or none.
      Click_Toast (Session);
      Check ("finding-review-shown", "TRUE", Flag (Screen.Review_Shown (Session)));
      Check ("finding-review-rows", " 6", Natural'Image (Screen.Review_Row_Count (Session)));
      Check ("finding-review-first", "92%  Whales of the world", Screen.Review_Row (Session, 2));
      Check ("finding-review-second", "85%  Song of the sea", Screen.Review_Row (Session, 3));
      Check ("finding-review-all", "Add all", Screen.Review_Row (Session, 5));
      Check ("finding-review-dismiss", "Dismiss", Screen.Review_Row (Session, 6));

      --  What is chosen is shown beside it, as a source is in the writing view: the
      --  best at first, then the one the pointer is over.
      Check ("finding-preview-shown", "TRUE", Flag (Screen.Preview_Shown (Session)));
      Check ("finding-preview-first", " 1", Natural'Image (Screen.Preview_Index (Session)));
      Check ("finding-preview-title", "Whales of the world", Screen.Preview_Title (Session));
      Snap (Session, "finding-review");
      declare
         X, Y : Float;
      begin
         Screen.Review_Row_Point (Session, 3, X, Y);
         Move_To (Session, X, Y);
         Settle (Session);
         Check ("finding-preview-second", " 2", Natural'Image (Screen.Preview_Index (Session)));
         Check ("finding-preview-second-title", "Song of the sea", Screen.Preview_Title (Session));
         Snap (Session, "finding-review-second");

         --  Over the line between the rows, or the heading, it stays; pressed, the list stays.
         Screen.Review_Row_Point (Session, 1, X, Y);
         Move_To (Session, X, Y);
         Settle (Session);
         Check ("finding-preview-stays", " 2", Natural'Image (Screen.Preview_Index (Session)));
         Screen.Preview_Point (Session, X, Y);
         Click_At (Session, X, Y);
         Settle (Session);
         Check ("finding-preview-pressed", "TRUE", Flag (Screen.Review_Shown (Session)));
      end;
      Screen.Review_Row_Point (Session, 2, X_First, Y_First);
      Move_To (Session, X_First, Y_First);
      Settle (Session);

      --  The same button puts the list away, and brings it back.
      Click_Toast (Session);
      Check ("finding-review-away", "FALSE", Flag (Screen.Review_Shown (Session)));
      Click_Toast (Session);

      --  A source is added: the page's title and link, its picture, a line from the note.
      Click_Review_Row (Session, 2);
      Check ("finding-added-count", " 2", Natural'Image (Windows.Item_Count (Session)));
      Check ("finding-added-kind", "TRUE", Flag (Windows.Item_Kind (Session, 2) = Items.Source));
      Check ("finding-added-title", "Whales of the world", Windows.Item_Title (Session, 2));
      Check ("finding-added-link", "https://example.org/whales", Windows.Item_Text (Session, 2));
      Check ("finding-added-origin", "TRUE", Flag (Windows.Item_Origin (Session, 2) = Items.Remote));
      Check ("finding-added-linked", " 1", Natural'Image (Links.Link_Count (Session)));
      Check ("finding-added-moved", "FALSE", Flag (Ada.Directories.Exists (Picture_A)));
      Check ("finding-added-left", " 1", Natural'Image (Source_Finder.Count));
      Check ("finding-added-still-listed", "TRUE", Flag (Screen.Review_Shown (Session)));
      Check ("finding-added-rows", " 5", Natural'Image (Screen.Review_Row_Count (Session)));
      Check ("finding-added-toast", "1 source found", Screen.Toast_Message (Session));
      Check ("finding-added-preview", "Song of the sea", Screen.Preview_Title (Session));
      Snap (Session, "finding-added-one");

      --  The last of them: the toast and the list go.
      Click_Review_Row (Session, 4);
      Check ("finding-all-count", " 3", Natural'Image (Windows.Item_Count (Session)));
      Check ("finding-all-title", "Song of the sea", Windows.Item_Title (Session, 3));
      Check ("finding-all-linked", " 2", Natural'Image (Links.Link_Count (Session)));
      Check ("finding-all-toast", "FALSE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-all-preview", "FALSE", Flag (Screen.Preview_Shown (Session)));
      Check ("finding-all-idle", "IDLE", Source_Finder.States'Image (Source_Finder.State));
      Check ("finding-all-moved", "FALSE", Flag (Ada.Directories.Exists (Picture_B)));

      --  Added all at once, from two, and put away.
      Ada.Directories.Copy_File ("golden/canvas-1x.png", Picture_A, "mode=overwrite");
      Ada.Directories.Copy_File ("golden/canvas-panned.png", Picture_B, "mode=overwrite");
      Source_Finder.Offer ("First", "https://example.org/1", Picture_A, "", 90);
      Source_Finder.Offer ("Second", "https://example.org/2", Picture_B, "", 81);
      Screen.Adopt (Session, 1);
      Settle (Session);
      Click_Toast (Session);
      Click_Review_Row (Session, 5);
      Check ("finding-add-all-count", " 5", Natural'Image (Windows.Item_Count (Session)));
      Check ("finding-add-all-linked", " 4", Natural'Image (Links.Link_Count (Session)));
      Check ("finding-add-all-toast", "FALSE", Flag (Screen.Toast_Shown (Session)));

      --  Dismissed, the pictures are thrown away and nothing is added.
      Ada.Directories.Copy_File ("golden/canvas-1x.png", Picture_A, "mode=overwrite");
      Source_Finder.Offer ("Third", "https://example.org/3", Picture_A, "", 88);
      Screen.Adopt (Session, 1);
      Settle (Session);
      Click_Toast (Session);
      Click_Review_Row (Session, Screen.Review_Row_Count (Session));
      Check ("finding-dismissed-count", " 5", Natural'Image (Windows.Item_Count (Session)));
      Check ("finding-dismissed-file", "FALSE", Flag (Ada.Directories.Exists (Picture_A)));
      Check ("finding-dismissed-toast", "FALSE", Flag (Screen.Toast_Shown (Session)));

      --  Left, the work and its pictures are given up.
      Ada.Directories.Copy_File ("golden/canvas-1x.png", Picture_A, "mode=overwrite");
      Source_Finder.Offer ("Fourth", "https://example.org/4", Picture_A, "", 88);
      Screen.Adopt (Session, 1);
      Settle (Session);
      Proj.Close_Project (Session);
      Check ("finding-left-idle", "IDLE", Source_Finder.States'Image (Source_Finder.State));
      Check ("finding-left-file", "FALSE", Flag (Ada.Directories.Exists (Picture_A)));
   end Review;

   procedure Documents is
      Session : Viewer.Session;
      Paper   : constant String := "/tmp/bonxie-finding/found-3.pdf";
      File    : Ada.Text_IO.File_Type;
   begin
      Start (Session, AI => True);
      Windows.Add_Item (Session, "Note");
      Type_In (Session, "Skuas nest on moorland");
      Settle (Session);
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Paper);
      Ada.Text_IO.Put (File, Item_Tests.Two_Pages);
      Ada.Text_IO.Close (File);
      Source_Finder.Offer ("Bonxies and skuas: a review", "https://example.org/skuas.pdf", Paper,
                           "A review of how the great skua breeds", 95, Document => True, Count_Of_Pages => 2);
      Source_Finder.Offer ("A news piece", "https://example.org/news", Picture_B, "", 85);
      Check ("finding-doc-is-document", "TRUE", Flag (Source_Finder.Is_Document (1)));
      Check ("finding-doc-pages", " 2", Natural'Image (Source_Finder.Pages (1)));
      Check ("finding-doc-page-not", "FALSE", Flag (Source_Finder.Is_Document (2)));
      Screen.Adopt (Session, 1);
      Settle (Session);
      Click_Toast (Session);

      --  The PDF is the best: shown in the preview as its pages are in the writing view.
      Check ("finding-doc-preview", "Bonxies and skuas: a review", Screen.Preview_Title (Session));
      Check ("finding-doc-preview-paged", "TRUE", Flag (Screen.Preview_Is_Paged (Session)));
      Snap (Session, "finding-review-document");

      --  Added, it is a document: its link, its pages, and the file where a source's is kept.
      Click_Review_Row (Session, 2);
      Settle (Session);
      Check ("finding-doc-added", " 2", Natural'Image (Windows.Item_Count (Session)));
      Check ("finding-doc-title", "Bonxies and skuas: a review", Windows.Item_Title (Session, 2));
      Check ("finding-doc-link", "https://example.org/skuas.pdf", Windows.Item_Text (Session, 2));
      Check ("finding-doc-origin", "TRUE", Flag (Windows.Item_Origin (Session, 2) = Items.Remote));
      Check ("finding-doc-shown-as-pages", "TRUE", Flag (Windows.Item_Is_Paged (Session, 2)));
      Check ("finding-doc-moved", "FALSE", Flag (Ada.Directories.Exists (Paper)));
      Check ("finding-doc-linked", " 1", Natural'Image (Links.Link_Count (Session)));
      Snap (Session, "finding-added-document");

      --  The page after it is a picture, as before.
      Click_Review_Row (Session, 2);
      Check ("finding-doc-page-added", " 3", Natural'Image (Windows.Item_Count (Session)));
      Check ("finding-doc-page-not-paged", "FALSE", Flag (Windows.Item_Is_Paged (Session, 3)));
   end Documents;

   procedure Cancelling is
      Session : Viewer.Session;
      Waited  : Natural := 0;

      procedure Wait_Until_Stopped is
      begin
         --  The model may take a moment to see that it was told to stop.
         while Source_Finder.State = Source_Finder.Running and then Waited < 200 loop
            Settle (Session);
            delay 0.05;
            Waited := Waited + 1;
         end loop;
      end Wait_Until_Stopped;
   begin
      Start (Session, AI => True);
      Windows.Add_Item (Session, "Note");
      Type_In (Session, "Whales sing");
      Settle (Session);

      --  A run that is under way (held there: there is no model to do the work).
      Source_Finder.Hold (True);
      Source_Finder.Start ("/tmp/bonxie-no-such-model", "Whales sing", "/tmp/bonxie-finding");
      Ada.Directories.Copy_File ("golden/canvas-1x.png", Picture_A, "mode=overwrite");
      Screen.Adopt (Session, 1);
      Settle (Session);
      Check ("finding-cancel-running", "RUNNING", Source_Finder.States'Image (Source_Finder.State));
      Check ("finding-cancel-toast", "TRUE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-cancel-message", "Finding sources: Writing searches", Screen.Toast_Message (Session));
      Check ("finding-cancel-action", "Cancel", Screen.Toast_Action (Session));
      Snap (Session, "finding-toast-working");

      --  Cancel is said at once, and the work is stopped as the loop goes on.
      Click_Toast (Session);
      if Source_Finder.State = Source_Finder.Running then
         Check ("finding-cancel-stopping", "Finding sources: Stopping", Screen.Toast_Message (Session));
      end if;
      Wait_Until_Stopped;
      Check ("finding-cancel-stopped", "IDLE", Source_Finder.States'Image (Source_Finder.State));
      Settle (Session);
      Check ("finding-cancel-toast-away", "FALSE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-cancel-nothing-kept", " 0", Natural'Image (Source_Finder.Count));

      --  It can be begun again, and stopped at once, with no one to see it, as the
      --  program does when it ends.
      Source_Finder.Start ("/tmp/bonxie-no-such-model", "Whales sing", "/tmp/bonxie-finding");
      Check ("finding-cancel-again", "RUNNING", Source_Finder.States'Image (Source_Finder.State));
      Source_Finder.Cancel;
      Check ("finding-cancel-stopping-state", "Stopping",
             (if Source_Finder.State = Source_Finder.Running then Source_Finder.Status else "Stopping"));
      for Try in 1 .. 200 loop
         Source_Finder.Poll;
         exit when Source_Finder.State /= Source_Finder.Running;
         delay 0.05;
      end loop;
      Check ("finding-cancel-again-stopped", "IDLE", Source_Finder.States'Image (Source_Finder.State));
      Source_Finder.Hold (False);

      --  Left half way: the work stops, and the toast does not stay in the next project.
      Source_Finder.Hold (True);
      Source_Finder.Start ("/tmp/bonxie-no-such-model", "Whales sing", "/tmp/bonxie-finding");
      Screen.Adopt (Session, 1);
      Settle (Session);
      Proj.Close_Project (Session);
      Waited := 0;
      Wait_Until_Stopped;
      Source_Finder.Hold (False);
      Check ("finding-cancel-left-stopped", "IDLE", Source_Finder.States'Image (Source_Finder.State));
   end Cancelling;

   procedure Messages is
      Session : Viewer.Session;
   begin
      Start (Session, AI => True);
      Windows.Add_Item (Session, "Note");
      Type_In (Session, "Whales sing");
      Settle (Session);

      --  Nothing passed: said, and put away of itself.
      Source_Finder.Offer ("Whales", "https://example.org/w", Picture_A, "", 90);
      Source_Finder.Drop (1);
      Screen.Adopt (Session, 1);
      Settle (Session);
      Check ("finding-none-toast", "TRUE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-none-message", "No good sources found", Screen.Toast_Message (Session));
      Check ("finding-none-action", "Dismiss", Screen.Toast_Action (Session));
      Snap (Session, "finding-toast-none");
      Viewer.Tick (Session, Now + 10_000);
      Check ("finding-none-away", "FALSE", Flag (Screen.Toast_Shown (Session)));
      Check ("finding-none-reset", "IDLE", Source_Finder.States'Image (Source_Finder.State));

      --  Turned off in the settings, the buttons are too.
      Proj.Close_Project (Session);
      Prefs.Open_Settings (Session);
      Prefs.Choose_AI_Enabled (Session, False);
      Prefs.Close_Settings (Session);
      Home.New_Project (Session);
      Proj.Set_Mode (Session, Viewer.Canvas);
      Windows.Add_Item (Session, "Note");
      Type_In (Session, "Whales sing");
      Settle (Session);
      Check ("finding-turned-off", "FALSE", Flag (Windows.Find_Sources_Enabled (Session, 1)));
   end Messages;

end Finding_Tests;
