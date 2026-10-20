with Ada.Directories;
with Ada.Real_Time;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Bounded;
with Downloads;
with Ebook;
with MLX.Jobs;
with Model_Replies;
with Source_Finding;
with Source_Links;
with Vision.Jobs;
with Webshot;
with Websearch;

package body Source_Finder is

   use type MLX.Jobs.States;
   use type Vision.Jobs.States;
   use type Webshot.States;
   use type Websearch.States;
   use type Downloads.States;

   package Addresses is new Ada.Strings.Bounded.Generic_Bounded_Length (Websearch.Max_URL);
   package Titles is new Ada.Strings.Bounded.Generic_Bounded_Length (Websearch.Max_Title);
   package Page_Texts is new Ada.Strings.Bounded.Generic_Bounded_Length (Source_Finding.Max_Text);
   package Files is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Directory + 32);

   use type Titles.Bounded_String;
   use type Addresses.Bounded_String;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Ada.Directories.File_Size;

   pragma Assert (Last_Slot <= Webshot.Slot_Count and then Last_Slot <= Vision.Jobs.Slot_Count);

   Search_Slot : constant Websearch.Slot := 1;

   Max_Judges : constant := 3;
   --  Asks of the model at once, of what covers a page and of how good it is:
   --  the model takes one at a time whatever the number, and the jobs it has are
   --  few (see MLX.Jobs.Max_Jobs).

   Document_Pages : constant := 10;
   --  How many pages of a PDF are read, at the most, for the model to judge it by: as many as
   --  it takes to have Document_Text bytes of words (the first pages of a long work are its
   --  title and its contents, with next to nothing to judge it by).

   Document_Text : constant := 4_000;

   Fetch_Limit : constant Duration := 60.0;
   --  Seconds a PDF may take to come, by the plain fetch: a slow server would hold the one
   --  download there is (and so every other PDF) for as long as it liked.

   Max_Document : constant := 100 * 1024 * 1024;
   --  Bytes of a PDF that is taken: a larger is no paper, and takes too long.

   --  The work

   type Stages is (Asking, Searching, Reading, Stopping);

   Public     : States := Idle;
   Stage      : Stages := Asking;
   Problem    : Source_Finding.Reason_Texts.Bounded_String;
   --  Why it Failed.

   Model      : String (1 .. MLX.Max_Path);
   Model_Last : Natural := 0;
   Folder     : String (1 .. Max_Directory);
   Folder_Last : Natural := 0;
   Writing    : Page_Texts.Bounded_String;
   --  The text sources are for, as far as the model is given it.

   --  Asking for the queries

   Query_Job   : MLX.Jobs.Job;
   Bad_Reply   : Page_Texts.Bounded_String;
   --  The last reply that was not read, of any ask.
   Query_Tries : Natural := 0;
   Queries     : Source_Finding.Query_List;

   --  Searching

   Query_Next   : Positive := 1;
   Search_Going : Boolean := False;
   Blocked_Seen : Boolean := False;
   Last_Problem : Titles.Bounded_String;

   type Candidate is record
      Address  : Addresses.Bounded_String;
      Document : Boolean := False;
      --  Whether it is of a PDF.
      Fallback : Addresses.Bounded_String;
      --  Of a PDF that was had by the address of the page it is the front of: that page,
      --  to be taken if the PDF cannot be had.
   end record;

   type Candidate_Array is array (1 .. Max_Candidates) of Candidate;

   Candidates      : Candidate_Array;
   Candidate_Count : Natural range 0 .. Max_Candidates := 0;
   Candidate_Next  : Positive := 1;
   --  The next to take.

   --  The pages

   type Lane_States is
     (Free, Loading, Glimpsed, Glancing, To_Ask, Asking, Queued, Fetching, Browsing, Pictured, Recognizing,
      Waiting, Judging, Judged);
   --  Free: nothing, or what it had could not be had. Loading: Webshot has the page
   --  (the first look at it, a button being pressed, or the whole of it). Glimpsed:
   --  the top of the page is photographed, and waits its turn to be read: Vision is
   --  given one picture at a time (read at once, some come back with no words).
   --  Glancing: Vision is reading it. To_Ask: its words wait for the model to be
   --  asked what covers the page. Asking: a job has them. Queued: a PDF waits its
   --  turn to be fetched (one at a time). Fetching: it is on its way. Browsing: the plain fetch
   --  was turned away (some sites will not give a file but to a browser), and the browser has it.
   --  Pictured: the
   --  whole of a page is photographed, and waits to be read. Recognizing: Vision
   --  is reading it. Waiting: its text is to be judged. Judging: a job has it.
   --  Judged: it has its marks.

   type Lane is record
      State    : Lane_States := Free;
      Document : Boolean := False;
      Address  : Addresses.Bounded_String;
      Fallback : Addresses.Bounded_String;
      --  Of a PDF, the page it is the front of, to be taken if it cannot be had.
      Fetch_Began : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  When the plain fetch of a PDF began.
      Tried_Browser : Boolean := False;
      --  Of a PDF, whether the browser has been asked for it, after the plain fetch failed.
      No_Redirect : Boolean := False;
      --  Whether the page is not to be taken for the front of a PDF (it was, and the PDF
      --  could not be had).
      Title    : Titles.Bounded_String;
      Text     : Page_Texts.Bounded_String;
      --  The words of the page, or the pages of the PDF, for judging.
      Top      : Page_Texts.Bounded_String;
      --  The words of the top of the page, for what covers it.
      Tries    : Natural := 0;
      Presses  : Natural := 0;
      --  Buttons pressed on the page.
      Arrived  : Natural := 0;
      Marks    : Source_Finding.Evaluation;
      Count_Of_Pages : Natural := 0;
      --  Of a PDF.
      Asked_For : Source_Finding.Button_Texts.Bounded_String;
      --  The words of the button last said to be pressed, and, if it could not be, of the
      --  one the model is to be told of when it is asked again.
      Refused   : Source_Finding.Button_Texts.Bounded_String;
      Tiles    : Natural := 0;
      Tile     : Natural := 0;
      --  How many screens of the top of the page were written, and which is being read.
   end record;

   Lanes   : array (1 .. Max_Pages) of Lane;
   Arrivals : Natural := 0;
   Words   : Vision.Result;
   --  What Vision found in a page, while its text is taken out.
   Presses_Made : Natural := 0;
   Last_Button  : Source_Finding.Button_Texts.Bounded_String;
   Documents_Read : Natural := 0;
   --  What the model had pressed, for telling how it did.
   Download_Lane : Natural := 0;
   --  The lane whose PDF is being fetched, 0 if none.

   type Tasks is (Banner, Mark);
   --  What a job is asked: what covers a page, or how good it is.

   Judges     : array (1 .. Max_Judges) of MLX.Jobs.Job;
   Judge_Lane : array (1 .. Max_Judges) of Natural := [others => 0];
   Judge_Task : array (1 .. Max_Judges) of Tasks := [others => Mark];
   --  The page each is asked of, 0 if none, and what it is asked.
   Judge_Problem : Source_Finding.Reason_Texts.Bounded_String;

   --  The sources kept

   type Source is record
      Title    : Titles.Bounded_String;
      Address  : Addresses.Bounded_String;
      File     : Files.Bounded_String;
      Reason   : Source_Finding.Reason_Texts.Bounded_String;
      Percent  : Natural range 0 .. 100 := 0;
      Document : Boolean := False;
      Count_Of_Pages : Natural := 0;
   end record;

   Kept       : array (1 .. Max_Pages) of Source;
   Kept_Count : Natural range 0 .. Max_Pages := 0;

   Examined       : array (1 .. Max_Pages) of Source;
   Examined_Total : Natural range 0 .. Max_Pages := 0;
   --  Every page that was judged, in the order of the lanes.

   --  Helpers

   function Slot_Of (Which : Positive) return Positive is (First_Slot + Which - 1);

   function Image (Number : Natural) return String is
     (Model_Replies.Tidy (Natural'Image (Number), 10));

   function Picture (Which : Positive) return String is
     (Folder (1 .. Folder_Last) & "/found-" & Image (Which) & ".png");

   function Document_File (Which : Positive) return String is
     (Folder (1 .. Folder_Last) & "/found-" & Image (Which) & ".pdf");

   function Look_Picture (Which : Positive) return String is
     (Folder (1 .. Folder_Last) & "/look-" & Image (Which) & ".png");

   --  The screens of the top of a page are tile-1-1.png and on, for the page of the
   --  lane 1: the whole page is shrunk to fit a picture, and its words are too small
   --  to read, where those of a screen are not.
   function Tile_Prefix (Which : Positive) return String is
     (Folder (1 .. Folder_Last) & "/tile-" & Image (Which));

   function Tile_Picture (Which, Tile : Positive) return String is
     (Tile_Prefix (Which) & "-" & Image (Tile) & ".png");

   function File_Of (Which : Positive) return String is
     (if Lanes (Which).Document then Document_File (Which) else Picture (Which));

   procedure Remove_File (Name : String) is
   begin
      if Name /= "" and then Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_File (Name);
      end if;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         null;
   end Remove_File;

   function Count_Lanes (In_State : Lane_States) return Natural is
      Found : Natural := 0;
   begin
      for Each of Lanes loop
         if Each.State = In_State then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Count_Lanes;

   function Is_Reading (Of_State : Lane_States) return Boolean is
     (Of_State in Loading | Glimpsed | Glancing | To_Ask | Asking | Queued | Fetching | Browsing | Pictured
                  | Recognizing);
   --  Whether the page, or the PDF, is still being had and read.

   function Busy_Reading return Boolean is
     (for some Each of Lanes => Is_Reading (Each.State));

   function Has_Pages_To_Take return Boolean is
     (Candidate_Next <= Candidate_Count and then Count_Lanes (Free) > 0);

   function Vision_Busy return Boolean is
     (Count_Lanes (Glancing) + Count_Lanes (Recognizing) > 0);

   --  Whether the address is of a lane, or one of the candidates, already.
   function Known (Link : String) return Boolean is
   begin
      for Each in 1 .. Candidate_Count loop
         if Addresses.To_String (Candidates (Each).Address) = Link then
            return True;
         end if;
      end loop;
      for Each of Lanes loop
         if Each.State /= Free and then Addresses.To_String (Each.Address) = Link then
            return True;
         end if;
      end loop;
      return False;
   end Known;

   procedure Remove_Files_Of (Which : Positive) is
   begin
      Remove_File (Picture (Which));
      Remove_File (Document_File (Which));
      Remove_File (Document_File (Which) & ".part");
      Remove_File (Look_Picture (Which));
      for Tile in 1 .. Webshot.Max_Tiles loop
         Remove_File (Tile_Picture (Which, Tile));
      end loop;
   end Remove_Files_Of;

   procedure Forget_Work is
   begin
      for Which in Lanes'Range loop
         Webshot.Reset (Slot_Of (Which));
         Vision.Jobs.Reset (Slot_Of (Which));
         Lanes (Which) := (others => <>);
      end loop;
      Websearch.Reset (Search_Slot);
      Search_Going := False;
      Download_Lane := 0;
      Candidate_Count := 0;
      Candidate_Next := 1;
      Arrivals := 0;
      Blocked_Seen := False;
      Last_Problem := Titles.Null_Bounded_String;
      Judge_Problem := Source_Finding.Reason_Texts.Null_Bounded_String;
      Query_Next := 1;
      Query_Tries := 0;
      Queries.Count := 0;
   end Forget_Work;

   procedure Drop_Kept is
   begin
      for Each in 1 .. Kept_Count loop
         Remove_File (Files.To_String (Kept (Each).File));
      end loop;
      Kept_Count := 0;
   end Drop_Kept;

   procedure Remove_Pictures is
   begin
      for Which in Lanes'Range loop
         Remove_Files_Of (Which);
      end loop;
   end Remove_Pictures;

   procedure Fail (Words_Of_Why : String) is
   begin
      Problem :=
        Source_Finding.Reason_Texts.To_Bounded_String
          (Model_Replies.Cut (Words_Of_Why, Source_Finding.Max_Reason));
      Forget_Work;
      Remove_Pictures;
      Public := Failed;
   end Fail;

   --  The state

   function State return States is (Public);

   function Count return Natural is (Kept_Count);
   function Title (Item : Positive) return String is (Titles.To_String (Kept (Item).Title));
   function Address (Item : Positive) return String is (Addresses.To_String (Kept (Item).Address));
   function Reason (Item : Positive) return String is
     (Source_Finding.Reason_Texts.To_String (Kept (Item).Reason));
   function Percent (Item : Positive) return Natural is (Kept (Item).Percent);
   function Is_Document (Item : Positive) return Boolean is (Kept (Item).Document);
   function Pages (Item : Positive) return Natural is (Kept (Item).Count_Of_Pages);

   function Examined_Count return Natural is (Examined_Total);
   function Examined_Title (Item : Positive) return String is (Titles.To_String (Examined (Item).Title));
   function Examined_Percent (Item : Positive) return Natural is (Examined (Item).Percent);
   function Examined_Reason (Item : Positive) return String is
     (Source_Finding.Reason_Texts.To_String (Examined (Item).Reason));
   function File (Item : Positive) return String is (Files.To_String (Kept (Item).File));

   function Last_Reply return String is (Page_Texts.To_String (Bad_Reply));
   function Pressed_Count return Natural is (Presses_Made);
   function Last_Pressed return String is (Source_Finding.Button_Texts.To_String (Last_Button));
   function Documents_Taken return Natural is (Documents_Read);

   function Message return String is (Source_Finding.Reason_Texts.To_String (Problem));

   function Wanted_Within return Duration is (0.1);

   function Status return String is
     (case Stage is
         when Asking => "Writing searches",
         when Searching =>
           (if Search_Going or else Websearch.Retry_After = 0.0
            then "Searching (" & Image (Query_Next) & " of " & Image (Queries.Count) & ")"
            else "Waiting to search"),
         when Reading =>
           (if Busy_Reading or else Has_Pages_To_Take
            then "Reading pages (" & Image (Count_Lanes (Waiting) + Count_Lanes (Judging) + Count_Lanes (Judged))
                 & " of" & Max_Pages'Image & ")"
            else "Judging pages (" & Image (Count_Lanes (Judged)) & " of "
                 & Image (Count_Lanes (Waiting) + Count_Lanes (Judging) + Count_Lanes (Judged)) & ")"),
         when Stopping => "Stopping");

   --  Starting

   procedure Ask_For_Queries is
   begin
      MLX.Jobs.Start
        (Query_Job, Model (1 .. Model_Last),
         Source_Finding.Query_Prompt (Page_Texts.To_String (Writing)),
         Source_Finding.Query_System_Prompt,
         Tuning => (Max_Tokens => Source_Finding.Query_Tokens, Temperature => 0.3, Thinking => MLX.Off,
                    others => <>));
   exception
      when MLX.Jobs.Capacity_Error =>
         Fail ("The AI is busy, try again");
   end Ask_For_Queries;

   procedure Start (Model_Folder, Text, Directory : String) is
   begin
      Reset;
      Presses_Made := 0;
      Last_Button := Source_Finding.Button_Texts.Null_Bounded_String;
      Documents_Read := 0;
      Model_Last := Model_Folder'Length;
      Model (1 .. Model_Last) := Model_Folder;
      Folder_Last := Directory'Length;
      Folder (1 .. Folder_Last) := Directory;
      Writing := Page_Texts.To_Bounded_String (Model_Replies.Cut (Text, Source_Finding.Max_Text));
      Ada.Directories.Create_Path (Directory);
      --  What an earlier run left (the program was ended with sources found, say) is not wanted.
      Remove_Pictures;
      Public := Running;
      Stage := Asking;
      Query_Tries := 1;
      Ask_For_Queries;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         Fail ("The folder for the pages could not be made");
   end Start;

   --  Asking

   procedure Poll_Asking is
   begin
      case MLX.Jobs.State (Query_Job) is
         when MLX.Jobs.Done =>
            declare
               Valid : Boolean;
            begin
               Source_Finding.Parse_Queries (MLX.Jobs.Text (Query_Job), Queries, Valid);
               if not Valid then
                  Bad_Reply := Page_Texts.To_Bounded_String (Model_Replies.Cut (MLX.Jobs.Text (Query_Job), 3_000));
               end if;
               MLX.Jobs.Reset (Query_Job);
               if Valid then
                  Stage := Searching;
                  Query_Next := 1;
               elsif Query_Tries < Source_Finding.Max_Tries then
                  Query_Tries := Query_Tries + 1;
                  Ask_For_Queries;
               else
                  Fail ("The AI could not make searches from the text");
               end if;
            end;
         when MLX.Jobs.Failed =>
            declare
               Said : constant String := MLX.Jobs.Text (Query_Job);
            begin
               MLX.Jobs.Reset (Query_Job);
               Fail (if Said = "" then "The AI could not make searches from the text" else Said);
            end;
         when MLX.Jobs.Cancelled =>
            MLX.Jobs.Reset (Query_Job);
            Fail ("Stopped");
         when MLX.Jobs.Idle | MLX.Jobs.Running =>
            null;
      end case;
   end Poll_Asking;

   --  Searching

   --  The candidates, PDFs first: they are shown well in a project, and a page of
   --  the front of one is no better than the PDF.
   procedure Put_Documents_First is
      Sorted : Candidate_Array;
      Total  : Natural := 0;
   begin
      for Each in 1 .. Candidate_Count loop
         if Candidates (Each).Document then
            Total := Total + 1;
            Sorted (Total) := Candidates (Each);
         end if;
      end loop;
      for Each in 1 .. Candidate_Count loop
         if not Candidates (Each).Document then
            Total := Total + 1;
            Sorted (Total) := Candidates (Each);
         end if;
      end loop;
      Candidates := Sorted;
   end Put_Documents_First;

   procedure Add_Links is
      Room : constant Positive := Positive'Max (1, Max_Candidates / Positive'Max (1, Queries.Count));
      --  Each query gets a share, for the pages not to be all of the first.
      Taken : Natural := 0;
   begin
      for Item in 1 .. Websearch.Count (Search_Slot) loop
         exit when Taken = Room or else Candidate_Count = Max_Candidates;
         declare
            Link   : constant String := Websearch.URL (Search_Slot, Item);
            --  A page that is the front of a paper at a site that is known is taken as its PDF.
            Direct : constant String := Source_Links.Direct_Document (Link);
            Where  : constant String := (if Direct /= "" and then Direct'Length <= Websearch.Max_URL
                                         then Direct else Link);
            Document : constant Boolean := Source_Links.Is_Document (Where);
         begin
            --  Text and e-books are of kinds the project takes in another way.
            if not Known (Where) and then (Document or else not Ebook.Is_Supported (Where)) then
               Candidate_Count := Candidate_Count + 1;
               Candidates (Candidate_Count) :=
                 (Address  => Addresses.To_Bounded_String (Where), Document => Document,
                  Fallback => (if Where /= Link and then Link'Length <= Websearch.Max_URL
                               then Addresses.To_Bounded_String (Link) else Addresses.Null_Bounded_String));
               Taken := Taken + 1;
            end if;
         end;
      end loop;
   end Add_Links;

   procedure Finish_Searching is
   begin
      if Candidate_Count > 0 then
         Put_Documents_First;
         Stage := Reading;
      elsif Blocked_Seen then
         Fail ("DuckDuckGo asked for proof of a person: try again later");
      elsif Last_Problem /= Titles.Null_Bounded_String then
         Fail ("Searching failed: " & Titles.To_String (Last_Problem));
      else
         Fail ("No pages were found");
      end if;
   end Finish_Searching;

   procedure Poll_Searching is
      Accepted : Boolean;
   begin
      if Search_Going then
         case Websearch.State (Search_Slot) is
            when Websearch.Done =>
               Add_Links;
               Websearch.Reset (Search_Slot);
               Search_Going := False;
               Query_Next := Query_Next + 1;
            when Websearch.Failed =>
               Last_Problem :=
                 Titles.To_Bounded_String (Model_Replies.Cut (Websearch.Message (Search_Slot), Websearch.Max_Title));
               if Websearch.Blocked (Search_Slot) then
                  Blocked_Seen := True;
                  Query_Next := Queries.Count + 1;
               else
                  Query_Next := Query_Next + 1;
               end if;
               Websearch.Reset (Search_Slot);
               Search_Going := False;
            when Websearch.Idle =>
               Search_Going := False;
            when Websearch.Working =>
               null;
         end case;
      elsif Query_Next > Queries.Count then
         Finish_Searching;
      else
         --  A query kept from lately is answered at once, whatever the wait.
         Websearch.Start
           (Search_Slot, Source_Finding.Query_Texts.To_String (Queries.Items (Query_Next)), Accepted);
         Search_Going := Accepted;
         if not Accepted and then Websearch.Retry_After > Max_Wait then
            --  Searches are held back for longer than is worth waiting for.
            if Candidate_Count = 0 then
               Fail ("Searching is paused, try again in"
                     & Natural'Image (Natural (Websearch.Retry_After) / 60 + 1) & " min");
            else
               Query_Next := Queries.Count + 1;
            end if;
         end if;
      end if;
   end Poll_Searching;

   --  Reading and judging

   function Text_Of (Found : Vision.Result) return String;
   --  The words of the page: those of a line with a space between, a line
   --  break between lines, up to what the model is given (Result.Text has the
   --  words end to end, with nothing between).

   function Text_Of (Found : Vision.Result) return String is
      Text : Page_Texts.Bounded_String;
      Line : Natural := 0;
   begin
      for Each in 1 .. Found.Count loop
         exit when Page_Texts.Length (Text) = Source_Finding.Max_Text;
         if Page_Texts.Length (Text) > 0 then
            Page_Texts.Append (Text, (if Found.Words (Each).Line /= Line then [ASCII.LF] else " "), Ada.Strings.Right);
         end if;
         Line := Found.Words (Each).Line;
         Page_Texts.Append (Text, Vision.Image (Found.Words (Each), Found), Ada.Strings.Right);
      end loop;
      return Model_Replies.Cut (Page_Texts.To_String (Text), Source_Finding.Max_Text);
   end Text_Of;

   procedure Lose_Lane (Which : Positive) is
   begin
      Remove_Files_Of (Which);
      Lanes (Which) := (others => <>);
   end Lose_Lane;

   --  The lane's page is begun: the top of it is looked at first, for what covers it: the
   --  model, not the page's own script, says which button to press.
   procedure Begin_Page (Which : Positive) is
   begin
      Webshot.Reset (Slot_Of (Which));
      Vision.Jobs.Reset (Slot_Of (Which));
      Webshot.Start
        (Slot_Of (Which), Addresses.To_String (Lanes (Which).Address), Picture (Which),
         Look_File => Look_Picture (Which), Dismiss_Banners => False, Tile_Prefix => Tile_Prefix (Which));
   end Begin_Page;

   procedure Start_Lane (Which : Positive) is
      Next : Candidate renames Candidates (Candidate_Next);
   begin
      Lanes (Which) :=
        (State => (if Next.Document then Queued else Loading), Document => Next.Document,
         Address => Next.Address, Fallback => Next.Fallback, others => <>);
      Candidate_Next := Candidate_Next + 1;
      Webshot.Reset (Slot_Of (Which));
      Vision.Jobs.Reset (Slot_Of (Which));
      if not Lanes (Which).Document then
         Begin_Page (Which);
      end if;
   end Start_Lane;

   --  The PDF could not be had (the address gave a page that asks for something, or nothing): the
   --  page it is the front of is taken in its place, if there is one that is not had already.
   procedure Retry_As_Page (Which : Positive) is
      Page : constant Addresses.Bounded_String := Lanes (Which).Fallback;
   begin
      Remove_Files_Of (Which);
      if Page = Addresses.Null_Bounded_String or else Known (Addresses.To_String (Page)) then
         Lanes (Which) := (others => <>);
      else
         Lanes (Which) := (State => Loading, Address => Page, No_Redirect => True, others => <>);
         Begin_Page (Which);
      end if;
   end Retry_As_Page;

   --  Whether the first bytes of the file are a PDF's.
   function Is_PDF (Name : String) return Boolean is
      Opened : Ada.Streams.Stream_IO.File_Type;
      Head   : String (1 .. 5) := [others => ' '];
   begin
      Ada.Streams.Stream_IO.Open (Opened, Ada.Streams.Stream_IO.In_File, Name);
      for Each in Head'Range loop
         exit when Ada.Streams.Stream_IO.End_Of_File (Opened);
         Character'Read (Ada.Streams.Stream_IO.Stream (Opened), Head (Each));
      end loop;
      Ada.Streams.Stream_IO.Close (Opened);
      return Source_Links.Is_PDF_File (Head);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (Opened) then
            Ada.Streams.Stream_IO.Close (Opened);
         end if;
         return False;
   end Is_PDF;

   --  The plain fetch of the PDF did not give one: the browser is asked, which has what the
   --  site may want of it (it has been to the site's pages, and been taken for a person), and
   --  if it was asked already, the page the PDF is the front of is taken in its place.
   procedure Fall_Back (Which : Positive) is
   begin
      if Lanes (Which).Tried_Browser then
         Retry_As_Page (Which);
      else
         Lanes (Which).Tried_Browser := True;
         Remove_File (Document_File (Which));
         Webshot.Reset (Slot_Of (Which));
         Webshot.Start_Download (Slot_Of (Which), Addresses.To_String (Lanes (Which).Address), Document_File (Which));
         Lanes (Which).State := Browsing;
      end if;
   end Fall_Back;

   --  Whether words have been read wrongly, as a scan's are: two or more have letters and digits
   --  among them (Pr09ramm1n9).
   function Garbled (Text : String) return Boolean is
      Mixed : Natural := 0;
      First : Positive := Text'First;
   begin
      for Each in Text'First .. Text'Last + 1 loop
         if Each > Text'Last or else Text (Each) = ' ' then
            declare
               Word : constant String := Text (First .. Each - 1);
            begin
               if (for some C of Word => C in 'A' .. 'Z' | 'a' .. 'z') and then (for some C of Word => C in '0' .. '9')
               then
                  Mixed := Mixed + 1;
               end if;
            end;
            First := Each + 1;
         end if;
      end loop;
      return Mixed >= 2;
   end Garbled;

   --  The first lines of a page's text as a heading: up to three that are not blank, put
   --  together till there is enough of a title.
   function Heading_Of (Raw : String) return String is
      Result : String (1 .. 160);
      Used   : Natural := 0;
      Lines  : Natural := 0;
      First  : Positive := Raw'First;
   begin
      for Each in Raw'First .. Raw'Last + 1 loop
         if Each > Raw'Last or else Raw (Each) in ASCII.LF | ASCII.CR then
            declare
               Line : constant String := Model_Replies.Tidy (Raw (First .. Each - 1), 100);
            begin
               if Line'Length > 1 and then Used + Line'Length + 1 <= Result'Length then
                  Result (Used + 1 .. Used + Line'Length) := Line;
                  Used := Used + Line'Length;
                  Result (Used + 1) := ' ';
                  Used := Used + 1;
                  Lines := Lines + 1;
               end if;
            end;
            First := Each + 1;
            exit when Lines = 3 or else Used >= 40;
         end if;
      end loop;
      return (if Used = 0 then "" else Result (1 .. Used - 1));
   end Heading_Of;

   --  The PDF is here: its title, and the words of its first pages, for judging. Only the text
   --  is had, not the pages drawn: a long work of scanned pages is a good many seconds to draw.
   procedure Read_Document (Which : Positive) is
      Where   : constant String := Document_File (Which);
      Info    : Ebook.Information;
      Said    : String (1 .. Ebook.Max_Message);
      Last    : Natural;
      Text    : Page_Texts.Bounded_String;
      Heading : String (1 .. 160) := [others => ' '];
      Heading_Last : Natural := 0;
   begin
      if not Is_PDF (Where) or else Ada.Directories.Size (Where) > Max_Document then
         Fall_Back (Which);   --  a page that asks for something, or is gone, or too large
         return;
      end if;
      Ebook.Open (Where, Info, Said, Last);
      if Info.Pages = 0 then
         Fall_Back (Which);
         return;
      end if;
      Lanes (Which).Count_Of_Pages := Info.Pages;
      Documents_Read := Documents_Read + 1;
      for Page in 1 .. Natural'Min (Document_Pages, Info.Pages) loop
         exit when Page_Texts.Length (Text) >= Document_Text;
         declare
            Raw   : constant String := Ebook.Page_Text (Where, Page, Source_Finding.Max_Text);
            Words_Here : constant String := Model_Replies.Tidy (Raw, Source_Finding.Max_Text);
         begin
            if Heading_Last = 0 and then Raw /= "" then
               declare
                  Top : constant String := Heading_Of (Raw);
               begin
                  Heading_Last := Top'Length;
                  Heading (1 .. Heading_Last) := Top;
               end;
            end if;
            if Words_Here /= "" then
               if Page_Texts.Length (Text) > 0 then
                  Page_Texts.Append (Text, " ", Ada.Strings.Right);
               end if;
               Page_Texts.Append (Text, Words_Here, Ada.Strings.Right);
            end if;
         end;
      end loop;
      --  The PDF's own title, unless it has none worth the name (a number, say): then the page
      --  it is the front of has its own, or its first page begins with one, or the address says.
      declare
         Own  : constant String := (if Info.Last > 0 then Info.Title (1 .. Info.Last) else "");
         Poor : constant Boolean :=
           Own'Length < 8 or else (for all C of Own => C in '0' .. '9' | '.' | '-' | ' ') or else Garbled (Own);
      begin
         if not Poor then
            Lanes (Which).Title := Titles.To_Bounded_String (Model_Replies.Cut (Own, Websearch.Max_Title));
         elsif Lanes (Which).Title = Titles.Null_Bounded_String then
            Lanes (Which).Title :=
              Titles.To_Bounded_String
                (Model_Replies.Cut
                   ((if Heading_Last > 4 and then not Garbled (Heading (1 .. Heading_Last))
                     then Heading (1 .. Heading_Last)
                     else Source_Links.Name_Of (Addresses.To_String (Lanes (Which).Address))),
                    Websearch.Max_Title));
         end if;
      end;
      Lanes (Which).Text := Page_Texts.To_Bounded_String (Page_Texts.To_String (Text));
      Arrivals := Arrivals + 1;
      Lanes (Which).Arrived := Arrivals;
      Lanes (Which).State := Waiting;
   end Read_Document;

   procedure Poll_Lane (Which : Positive) is
      Slot : constant Positive := Slot_Of (Which);
      Page : Lane renames Lanes (Which);
   begin
      case Page.State is
         when Loading =>
            case Webshot.State (Slot) is
               when Webshot.Looked =>
                  Page.Title :=
                    Titles.To_Bounded_String (Model_Replies.Tidy (Webshot.Page_Title (Slot), Websearch.Max_Title));
                  declare
                     Link : constant String := Webshot.Document_Link (Slot);
                  begin
                     if Page.Presses = 0 and then not Page.No_Redirect and then Link /= ""
                       and then Link'Length <= Websearch.Max_URL
                     then
                        --  The page is the front of a PDF, which is what is wanted: unless
                        --  it is of one that is had already, which makes the page no use.
                        Webshot.Reset (Slot);
                        if Known (Link) then
                           Lose_Lane (Which);
                        else
                           Remove_File (Look_Picture (Which));
                           Page := (State => Queued, Document => True, Address => Addresses.To_Bounded_String (Link),
                                    Fallback => Page.Address, Title => Page.Title, others => <>);
                        end if;
                     elsif Page.Presses > 0 and then Page.Presses < Source_Finding.Max_Presses
                       and then not Webshot.Pressed (Slot)
                     then
                        --  What the model named was not there, or must not be pressed: it is
                        --  asked again, and told so (the words of the top are the same).
                        Page.Refused := Page.Asked_For;
                        Page.Tries := 0;
                        Page.State := To_Ask;
                     elsif Page.Presses >= Source_Finding.Max_Presses
                       or else (Page.Presses > 0 and then not Webshot.Pressed (Slot))
                     then
                        --  Nothing more to press: go on to the whole of the page.
                        Webshot.Continue (Slot);
                     else
                        Page.State := Glimpsed;
                     end if;
                  end;
               when Webshot.Done =>
                  Page.Title :=
                    Titles.To_Bounded_String (Model_Replies.Tidy (Webshot.Page_Title (Slot), Websearch.Max_Title));
                  Page.Tiles := Webshot.Tile_Count (Slot);
                  Webshot.Reset (Slot);
                  Page.State := Pictured;
               when Webshot.Failed =>
                  Webshot.Reset (Slot);
                  Lose_Lane (Which);
               when Webshot.Idle =>
                  Lose_Lane (Which);
               when Webshot.Working =>
                  null;
            end case;
         when Glimpsed =>
            if not Vision_Busy then
               Vision.Jobs.Reset (Slot);
               Vision.Jobs.Start (Slot, Look_Picture (Which));
               Page.State := Glancing;
            end if;
         when Glancing =>
            case Vision.Jobs.State (Slot) is
               when Vision.Jobs.Done =>
                  Vision.Jobs.Take (Slot, Words);
                  Page.Top := Page_Texts.To_Bounded_String (Text_Of (Words));
                  Page.Tries := 0;
                  Page.State := To_Ask;
               when Vision.Jobs.Failed | Vision.Jobs.Idle =>
                  Vision.Jobs.Reset (Slot);
                  --  Not read: the page is taken as it is.
                  Page.State := Loading;
                  Webshot.Continue (Slot);
               when Vision.Jobs.Working =>
                  null;
            end case;
         when Queued =>
            if Download_Lane = 0 and then Downloads.State = Downloads.Idle then
               Remove_File (Document_File (Which));
               Downloads.Start (Addresses.To_String (Page.Address), Document_File (Which));
               Download_Lane := Which;
               Page.Fetch_Began := Ada.Real_Time.Clock;
               Page.State := Fetching;
            end if;
         when Fetching =>
            case Downloads.State is
               when Downloads.Done =>
                  Downloads.Reset;
                  Download_Lane := 0;
                  Read_Document (Which);
               when Downloads.Failed =>
                  Downloads.Reset;
                  Download_Lane := 0;
                  Fall_Back (Which);
               when Downloads.Idle =>
                  Download_Lane := 0;
                  Fall_Back (Which);
               when Downloads.Running =>
                  --  Too slow: stopped, which is said by a failure, and then the browser is tried.
                  if Ada.Real_Time.Clock - Page.Fetch_Began > Ada.Real_Time.To_Time_Span (Fetch_Limit) then
                     Downloads.Cancel;
                  end if;
            end case;
         when Browsing =>
            case Webshot.State (Slot) is
               when Webshot.Done =>
                  Webshot.Reset (Slot);
                  Read_Document (Which);
               when Webshot.Failed | Webshot.Idle =>
                  Webshot.Reset (Slot);
                  Retry_As_Page (Which);
               when Webshot.Working | Webshot.Looked =>
                  null;
            end case;
         when Recognizing =>
            case Vision.Jobs.State (Slot) is
               when Vision.Jobs.Done =>
                  Vision.Jobs.Take (Slot, Words);
                  declare
                     More : constant String := Text_Of (Words);
                  begin
                     if Page_Texts.Length (Page.Text) > 0 and then More /= "" then
                        Page_Texts.Append (Page.Text, [ASCII.LF], Ada.Strings.Right);
                     end if;
                     Page_Texts.Append (Page.Text, More, Ada.Strings.Right);
                  end;
                  if Page.Tile < Page.Tiles and then Page_Texts.Length (Page.Text) < Source_Finding.Max_Text then
                     --  The next screen, which the model is given as far as it has room.
                     Page.Tile := Page.Tile + 1;
                     Vision.Jobs.Reset (Slot);
                     Vision.Jobs.Start (Slot, Tile_Picture (Which, Page.Tile));
                  else
                     Arrivals := Arrivals + 1;
                     Page.Arrived := Arrivals;
                     Page.State := Waiting;
                  end if;
               when Vision.Jobs.Failed =>
                  Vision.Jobs.Reset (Slot);
                  Lose_Lane (Which);
               when Vision.Jobs.Idle =>
                  Lose_Lane (Which);
               when Vision.Jobs.Working =>
                  null;
            end case;
         when Pictured =>
            if not Vision_Busy then
               Vision.Jobs.Reset (Slot);
               --  The first screen, then the others: or all of it, if it was not tiled.
               Page.Tile := (if Page.Tiles > 0 then 1 else 0);
               Page.Text := Page_Texts.Null_Bounded_String;
               Vision.Jobs.Start (Slot, (if Page.Tiles > 0 then Tile_Picture (Which, 1) else Picture (Which)));
               Page.State := Recognizing;
            end if;
         when Free | To_Ask | Asking | Waiting | Judging | Judged =>
            null;
      end case;
   end Poll_Lane;

   --  The model is asked of the page: what covers it, or how good it is.
   procedure Ask (Which_Judge, Which_Lane : Positive; What : Tasks) is
      Page : Lane renames Lanes (Which_Lane);
   begin
      --  The page is the judge's from now, though a job may not be had yet:
      --  Poll_Judge tries again until one is.
      Page.State := (if What = Banner then Asking else Judging);
      Judge_Lane (Which_Judge) := Which_Lane;
      Judge_Task (Which_Judge) := What;
      if What = Banner then
         MLX.Jobs.Start
           (Judges (Which_Judge), Model (1 .. Model_Last),
            Source_Finding.Banner_Prompt
              (Page_Texts.To_String (Page.Top), Source_Finding.Button_Texts.To_String (Page.Refused)),
            Source_Finding.Banner_System_Prompt,
            Tuning => (Max_Tokens => Source_Finding.Banner_Tokens, Temperature => 0.1, Thinking => MLX.Off,
                       others => <>));
      else
         MLX.Jobs.Start
           (Judges (Which_Judge), Model (1 .. Model_Last),
            Source_Finding.Evaluation_Prompt
              (Page_Texts.To_String (Writing), Titles.To_String (Page.Title), Addresses.To_String (Page.Address),
               Page_Texts.To_String (Page.Text)),
            Source_Finding.Evaluation_System_Prompt,
            Tuning => (Max_Tokens => Source_Finding.Evaluation_Tokens, Temperature => 0.2, Thinking => MLX.Off,
                       others => <>));
      end if;
      Page.Tries := Page.Tries + 1;
   exception
      when MLX.Jobs.Capacity_Error =>
         null;
   end Ask;

   --  The page goes on to be taken whole, with nothing pressed, or after what was.
   procedure Go_On (Which : Positive) is
   begin
      Lanes (Which).State := Loading;
      Lanes (Which).Tries := 0;
      Webshot.Continue (Slot_Of (Which));
   end Go_On;

   procedure Finish_Banner (Which_Judge : Positive; Reply : String) is
      Which   : constant Positive := Judge_Lane (Which_Judge);
      Page    : Lane renames Lanes (Which);
      Covered : Boolean;
      Button  : Source_Finding.Button_Texts.Bounded_String;
      Valid   : Boolean;
   begin
      Source_Finding.Parse_Banner (Reply, Covered, Button, Valid);
      Judge_Lane (Which_Judge) := 0;
      if Valid then
         if Covered and then Page.Presses < Source_Finding.Max_Presses then
            --  What is to be pressed is what the model read in the words of the picture.
            Page.Presses := Page.Presses + 1;
            Presses_Made := Presses_Made + 1;
            Last_Button := Button;
            Page.Asked_For := Button;
            Page.Refused := Source_Finding.Button_Texts.Null_Bounded_String;
            Page.Tries := 0;
            Page.State := Loading;
            Webshot.Press (Slot_Of (Which), Source_Finding.Button_Texts.To_String (Button));
         else
            Go_On (Which);
         end if;
      elsif Page.Tries < Source_Finding.Max_Tries then
         Bad_Reply := Page_Texts.To_Bounded_String (Model_Replies.Cut (Reply, 3_000));
         Ask (Which_Judge, Which, Banner);
      else
         Bad_Reply := Page_Texts.To_Bounded_String (Model_Replies.Cut (Reply, 3_000));
         Go_On (Which);   --  not told: the page is taken as it is
      end if;
   end Finish_Banner;

   procedure Finish_Judging (Which_Judge : Positive; Marks : Source_Finding.Evaluation; Valid : Boolean) is
      Page : Lane renames Lanes (Judge_Lane (Which_Judge));
   begin
      if Valid then
         Page.Marks := Marks;
         Page.State := Judged;
      elsif Page.Tries < Source_Finding.Max_Tries then
         Ask (Which_Judge, Judge_Lane (Which_Judge), Mark);
         return;
      else
         Page.Marks := (Reason => Source_Finding.Reason_Texts.To_Bounded_String ("The AI could not judge this page"),
                        others => <>);
         Page.State := Judged;
      end if;
      Judge_Lane (Which_Judge) := 0;
   end Finish_Judging;

   procedure Poll_Judge (Which_Judge : Positive) is
   begin
      if Judge_Lane (Which_Judge) = 0 then
         return;
      end if;
      case MLX.Jobs.State (Judges (Which_Judge)) is
         when MLX.Jobs.Done =>
            declare
               Reply : constant String := MLX.Jobs.Text (Judges (Which_Judge));
               Marks : Source_Finding.Evaluation;
               Valid : Boolean;
            begin
               MLX.Jobs.Reset (Judges (Which_Judge));
               if Judge_Task (Which_Judge) = Banner then
                  Finish_Banner (Which_Judge, Reply);
               else
                  Source_Finding.Parse_Evaluation (Reply, Marks, Valid);
                  if not Valid then
                     Bad_Reply := Page_Texts.To_Bounded_String (Model_Replies.Cut (Reply, 3_000));
                  end if;
                  Finish_Judging (Which_Judge, Marks, Valid);
               end if;
            end;
         when MLX.Jobs.Failed =>
            Judge_Problem :=
              Source_Finding.Reason_Texts.To_Bounded_String
                (Model_Replies.Cut (MLX.Jobs.Text (Judges (Which_Judge)), Source_Finding.Max_Reason));
            MLX.Jobs.Reset (Judges (Which_Judge));
            if Judge_Task (Which_Judge) = Banner then
               declare
                  Which : constant Positive := Judge_Lane (Which_Judge);
               begin
                  Judge_Lane (Which_Judge) := 0;
                  Go_On (Which);
               end;
            else
               Lanes (Judge_Lane (Which_Judge)).Marks :=
                 (Reason => Source_Finding.Reason_Texts.To_Bounded_String ("The AI could not judge this page"),
                  others => <>);
               Lanes (Judge_Lane (Which_Judge)).State := Judged;
               Judge_Lane (Which_Judge) := 0;
            end if;
         when MLX.Jobs.Cancelled =>
            MLX.Jobs.Reset (Judges (Which_Judge));
            Lose_Lane (Judge_Lane (Which_Judge));
            Judge_Lane (Which_Judge) := 0;
         when MLX.Jobs.Idle =>
            --  The job could not be had when the page was to be asked of.
            Ask (Which_Judge, Judge_Lane (Which_Judge), Judge_Task (Which_Judge));
         when MLX.Jobs.Running =>
            null;
      end case;
   end Poll_Judge;

   --  The page to ask of next: one whose top is to be asked of first, as it is
   --  being waited for; else the oldest whose words are to be judged. 0 if none.
   function Next_To_Ask return Natural is
      Found : Natural := 0;
   begin
      for Which in Lanes'Range loop
         if Lanes (Which).State = To_Ask then
            return Which;
         elsif Lanes (Which).State = Waiting
           and then (Found = 0 or else Lanes (Which).Arrived < Lanes (Found).Arrived)
         then
            Found := Which;
         end if;
      end loop;
      return Found;
   end Next_To_Ask;

   procedure Conclude is
      Order : array (1 .. Max_Pages) of Natural := [others => 0];
      Total : Natural := 0;
   begin
      --  The pages that pass, best first (the earlier of equals first).
      for Which in Lanes'Range loop
         if Lanes (Which).State = Judged and then Source_Finding.Passes (Lanes (Which).Marks) then
            declare
               Place : Positive := Total + 1;
            begin
               while Place > 1
                 and then Source_Finding.Percent (Lanes (Which).Marks)
                          > Source_Finding.Percent (Lanes (Order (Place - 1)).Marks)
               loop
                  Order (Place) := Order (Place - 1);
                  Place := Place - 1;
               end loop;
               Order (Place) := Which;
               Total := Total + 1;
            end;
         end if;
      end loop;
      for Each in 1 .. Total loop
         declare
            Page : Lane renames Lanes (Order (Each));
         begin
            Kept (Each) :=
              (Title => (if Page.Title = Titles.Null_Bounded_String
                         then Titles.To_Bounded_String
                                (Model_Replies.Cut (Addresses.To_String (Page.Address), Websearch.Max_Title))
                         else Page.Title),
               Address => Page.Address,
               File => Files.To_Bounded_String (File_Of (Order (Each))),
               Reason => Page.Marks.Reason,
               Percent => Source_Finding.Percent (Page.Marks),
               Document => Page.Document,
               Count_Of_Pages => Page.Count_Of_Pages);
         end;
      end loop;
      Kept_Count := Total;
      Examined_Total := 0;
      for Which in Lanes'Range loop
         if Lanes (Which).State = Judged then
            Examined_Total := Examined_Total + 1;
            Examined (Examined_Total) :=
              (Title => (if Lanes (Which).Title = Titles.Null_Bounded_String
                         then Titles.To_Bounded_String
                                (Model_Replies.Cut (Addresses.To_String (Lanes (Which).Address), Websearch.Max_Title))
                         else Lanes (Which).Title),
               Address => Lanes (Which).Address,
               File => Files.Null_Bounded_String,
               Reason => Lanes (Which).Marks.Reason,
               Percent => Source_Finding.Percent (Lanes (Which).Marks),
               Document => Lanes (Which).Document,
               Count_Of_Pages => Lanes (Which).Count_Of_Pages);
         end if;
      end loop;
      --  The files of the others are of no use, nor the looks at the tops of all, nor the screens
      --  that were read (the words are in the lanes): only the picture or the PDF of what is kept.
      for Which in Lanes'Range loop
         if (for all Each in 1 .. Total => Order (Each) /= Which) then
            Remove_Files_Of (Which);
         else
            Remove_File (Look_Picture (Which));
            for Tile in 1 .. Webshot.Max_Tiles loop
               Remove_File (Tile_Picture (Which, Tile));
            end loop;
         end if;
      end loop;
      declare
         Looked_At : constant Natural := Count_Lanes (Judged);
         Said  : constant String := Source_Finding.Reason_Texts.To_String (Judge_Problem);
      begin
         Forget_Work;
         if Looked_At = 0 then
            Fail ("None of the pages could be read");
         elsif Total = 0 and then Said /= "" then
            Fail (Said);
         else
            Public := Done;
         end if;
      end;
   end Conclude;

   procedure Poll_Reading is
   begin
      for Which in Lanes'Range loop
         Poll_Lane (Which);
      end loop;
      for Which in Judges'Range loop
         Poll_Judge (Which);
      end loop;
      --  Take in more, up to as many as are wanted, from the candidates in order.
      for Which in Lanes'Range loop
         if Lanes (Which).State = Free and then Has_Pages_To_Take then
            Start_Lane (Which);
         end if;
      end loop;
      for Which in Judges'Range loop
         if Judge_Lane (Which) = 0 and then Next_To_Ask /= 0 then
            declare
               Next : constant Positive := Next_To_Ask;
            begin
               Ask (Which, Next, (if Lanes (Next).State = To_Ask then Banner else Mark));
            end;
         end if;
      end loop;
      if not Has_Pages_To_Take
        and then not Busy_Reading
        and then Count_Lanes (Waiting) + Count_Lanes (Judging) = 0
      then
         Conclude;
      end if;
   end Poll_Reading;

   --  Stopping

   procedure Poll_Stopping is
      Still : Boolean := MLX.Jobs.State (Query_Job) = MLX.Jobs.Running;
   begin
      if MLX.Jobs.State (Query_Job) = MLX.Jobs.Running then
         MLX.Jobs.Cancel (Query_Job);
      end if;
      for Each in Judges'Range loop
         if MLX.Jobs.State (Judges (Each)) = MLX.Jobs.Running then
            MLX.Jobs.Cancel (Judges (Each));
            Still := True;
         end if;
      end loop;
      --  A file on its way is thrown away as it stops.
      if Download_Lane /= 0 and then Downloads.State = Downloads.Running then
         Downloads.Cancel;
         Still := True;
      end if;
      if not Still then
         if Download_Lane /= 0 and then Downloads.State /= Downloads.Idle then
            Downloads.Reset;
         end if;
         if MLX.Jobs.State (Query_Job) /= MLX.Jobs.Idle then
            MLX.Jobs.Reset (Query_Job);
         end if;
         for Each in Judges'Range loop
            if MLX.Jobs.State (Judges (Each)) /= MLX.Jobs.Idle then
               MLX.Jobs.Reset (Judges (Each));
            end if;
            Judge_Lane (Each) := 0;
         end loop;
         Forget_Work;
         Remove_Pictures;
         Public := Idle;
      end if;
   end Poll_Stopping;

   Held : Boolean := False;

   procedure Hold (To : Boolean) is
   begin
      Held := To;
   end Hold;

   procedure Poll is
   begin
      if Public = Running and then (not Held or else Stage = Stopping) then
         case Stage is
            when Asking   => Poll_Asking;
            when Searching => Poll_Searching;
            when Reading  => Poll_Reading;
            when Stopping => Poll_Stopping;
         end case;
      end if;
   end Poll;

   procedure Cancel is
   begin
      if Public = Running then
         Stage := Stopping;
      end if;
   end Cancel;

   procedure Reset is
   begin
      Examined_Total := 0;
      Drop_Kept;
      Forget_Work;
      Public := Idle;
   end Reset;

   procedure Take (Item : Positive) is
   begin
      Kept (Item .. Kept_Count - 1) := Kept (Item + 1 .. Kept_Count);
      Kept_Count := Kept_Count - 1;
   end Take;

   procedure Drop (Item : Positive) is
   begin
      Remove_File (Files.To_String (Kept (Item).File));
      Take (Item);
   end Drop;

   procedure Offer
     (Page_Title, Page_Address, Picture_File, Said : String;
      Score    : Natural;
      Document : Boolean := False;
      Count_Of_Pages : Natural := 0)
   is
   begin
      Kept_Count := Kept_Count + 1;
      Kept (Kept_Count) :=
        (Title => Titles.To_Bounded_String (Model_Replies.Cut (Page_Title, Websearch.Max_Title)),
         Address => Addresses.To_Bounded_String (Page_Address),
         File => Files.To_Bounded_String (Picture_File),
         Reason => Source_Finding.Reason_Texts.To_Bounded_String (Said),
         Percent => Score,
         Document => Document,
         Count_Of_Pages => Count_Of_Pages);
      Public := Done;
   end Offer;

end Source_Finder;
