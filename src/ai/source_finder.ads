with MLX;
with Webshot;

--  Finding sources for a text, on the web, in the background: the model
--  writes a few web searches from the text (see Source_Finding), which are
--  run through Websearch, spaced out as it needs; what they find is taken in
--  several at once until Max_Pages have come; the model judges each as a source
--  of the text, one after another; and those that score Pass_Percent or more
--  are kept, best first, with their files, in the folder given to Start.
--
--  A PDF is preferred to a page about it: a link to a PDF is fetched (the
--  downloader's one at a time) and its own text is read, and so is the PDF that
--  a page says it is the page of (see Source_Links), when it is not known
--  already. A page is photographed by Webshot, which first takes the top of it:
--  the model, which cannot see, is told the words read from that picture and
--  says if something covers the page (a cookie banner) and which button
--  closes it, which Webshot presses before it takes the whole of the page; the
--  words of that, read by Vision, are what the model judges.
--
--  One piece of work at a time. It goes on only as Poll is called, which is
--  of the main thread, as the event loop runs (Webshot and Websearch need
--  it). Nothing here waits.
package Source_Finder is

   Max_Pages : constant := 5;
   --  Pages taken in, and judged, at the most.

   Max_Candidates : constant := 15;
   --  Links kept from the searches, to take pages from.

   Max_Directory : constant := 900;

   First_Slot : constant := 1 - Webshot.Lane_Count;
   Last_Slot  : constant := First_Slot + Max_Pages - 1;
   --  The slots of Webshot and Vision.Jobs that the pages use: the lanes
   --  before those of a project's items.

   Max_Wait : constant Duration := 30.0;
   --  The longest a search is waited for its turn (see Websearch.Retry_After),
   --  before the work is given up, or goes on with the pages it has.

   type States is (Idle, Running, Done, Failed);
   --  Idle: nothing was started, or it was stopped or reset. Running: the work
   --  is under way (Status says how far). Done: the sources are there. Failed:
   --  Message says why.

   function State return States;

   procedure Start (Model_Folder, Text, Directory : String)
     with Pre  => State /= Running
                  and then Model_Folder'Length in 1 .. MLX.Max_Path
                  and then Text'Length > 0
                  and then Directory'Length in 1 .. Max_Directory,
          Post => State = Running;
   --  Begin to find sources for Text with the model in Model_Folder. The
   --  pictures are made in Directory, which is made if need be. What was kept
   --  by the last time is forgotten, as Reset does.

   procedure Poll;
   --  Move the work on, if there is any: look at the jobs, and start what is
   --  to follow. Do it often (see Wanted_Within).

   function Wanted_Within return Duration;
   --  How long the caller may leave it before it calls Poll again, while the
   --  work is under way.

   function Status return String
     with Pre => State = Running;
   --  What the work is at, in few words, as "Searching (2 of 3)".

   function Message return String
     with Pre => State = Failed;

   function Pressed_Count return Natural;
   --  How many buttons were pressed to clear what covered pages, in the last run.

   function Last_Pressed return String;
   --  The words of the last of them: for finding out what the model chose.

   function Documents_Taken return Natural;
   --  How many of the pages looked at were PDFs, in the last run.

   function Last_Reply return String;
   --  What the model last said that could not be used (cut to a few thousand
   --  bytes), "" if none: for finding out why a run failed.

   procedure Cancel;
   --  Stop the work, if it is under way. It does not wait: the state is
   --  Running, with the status Stopping, until Poll has seen the jobs stop,
   --  and then Idle.

   procedure Reset
     with Pre  => State /= Running,
          Post => State = Idle and then Count = 0;
   --  Forget how it ended and the sources kept, and throw their pictures away.

   --  The sources kept, best first

   function Count return Natural
     with Post => Count'Result <= Max_Pages;

   function Title (Item : Positive) return String
     with Pre => Item <= Count;
   --  Of the page.

   function Address (Item : Positive) return String
     with Pre => Item <= Count;

   function Reason (Item : Positive) return String
     with Pre => Item <= Count;
   --  Why the model scored it as it did; empty if it did not say.

   function Percent (Item : Positive) return Natural
     with Pre => Item <= Count, Post => Percent'Result <= 100;

   function File (Item : Positive) return String
     with Pre => Item <= Count;
   --  The picture of the page, a PNG file, or the PDF, if it is one.

   function Is_Document (Item : Positive) return Boolean
     with Pre => Item <= Count;
   --  Whether the source is a PDF (File is it), not a page.

   function Pages (Item : Positive) return Natural
     with Pre => Item <= Count;
   --  Of a PDF, how many pages it has; 0 for a page.

   --  The pages looked at in the last run, whether they passed or not, as they
   --  were judged: for saying how many there were, and for finding out why none
   --  were good enough.

   function Examined_Count return Natural
     with Post => Examined_Count'Result <= Max_Pages;

   function Examined_Title (Item : Positive) return String
     with Pre => Item <= Examined_Count;

   function Examined_Percent (Item : Positive) return Natural
     with Pre => Item <= Examined_Count, Post => Examined_Percent'Result <= 100;

   function Examined_Reason (Item : Positive) return String
     with Pre => Item <= Examined_Count;
   --  What the model said, or that it could not judge the page.

   procedure Take (Item : Positive)
     with Pre => Item <= Count;
   --  Forget the source: its picture is the caller's now, to move or keep.

   procedure Drop (Item : Positive)
     with Pre => Item <= Count;
   --  Forget the source, and throw its picture away.

   procedure Hold (To : Boolean);
   --  For tests: while held, Poll leaves a run as it is, except to stop it when it
   --  has been cancelled, so that a run stays under way for as long as a test
   --  wants it to (with no model, nothing it does would be seen).

   procedure Offer
     (Page_Title, Page_Address, Picture_File, Said : String;
      Score    : Natural;
      Document : Boolean := False;
      Count_Of_Pages : Natural := 0)
     with Pre => State /= Running and then Count < Max_Pages and then Score <= 100;
   --  For tests: keep a source as if it had been found (a PDF, if Document, of
   --  that many pages, whose file is Picture_File), and make the state Done.

end Source_Finder;
