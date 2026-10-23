--  Finding sources through the backend (`POST /api/v1/find_sources`): given the titles of the
--  project, section and document and the project's description, it replies with up to five
--  pages, the most useful first, or says why it found none. One request at a time, by a task of
--  its own (which runs curl, so that the wait, which is 5 to 30 seconds, holds nothing up); the
--  caller polls State. The addresses are from a web search, so they are untrusted links.
package Premium.Sources is

   Max_Results : constant := 5;
   Max_Address : constant := 2_048;
   Max_Title   : constant := 300;
   Max_Guidance : constant := 600;
   Max_Message : constant := 120;

   Timeout : constant := 70;
   --  Seconds the request may take: the backend's own limit is 60.

   type States is (Idle, Running, Done, Failed);
   --  Idle: nothing was started, or it was forgotten (Reset). Running: the request is out. Done:
   --  there are Count results, or none and some Guidance. Failed: Message says so, in words for
   --  the person.

   function Request_Body
     (Project_Title, Project_Description, Section_Title, Document_Title : String) return String
     with Pre => Project_Title /= "" and then Section_Title /= "" and then Document_Title /= "";
   --  The JSON of the request. The description is left out if it is empty.

   procedure Start
     (Project_Title, Project_Description, Section_Title, Document_Title, Work_Directory : String)
     with Pre  => State /= Running
                  and then Project_Title /= "" and then Section_Title /= "" and then Document_Title /= ""
                  and then Work_Directory /= "",
          Post => State = Running;
   --  Send the request; the files it needs are made in Work_Directory, and taken away.

   function State return States;

   procedure Cancel;
   --  Stop the request, if it is out. It does not wait: the state is Failed, with the message
   --  Stopped, when the task has seen to it.

   procedure Reset
     with Pre => State /= Running, Post => State = Idle and then Count = 0;
   --  Forget how the last one ended, and its results.

   function Count return Natural
     with Post => Count'Result <= Max_Results;

   function Address (Item : Positive) return String
     with Pre => Item <= Count;
   --  An absolute http or https address.

   function Title (Item : Positive) return String
     with Pre => Item <= Count;
   --  The backend's label for the page; "" if it gave none.

   function Guidance return String;
   --  Said when there are no results, to tell the person why and how to ask better; "" if not.

   function Message return String
     with Pre => State = Failed, Post => Message'Result'Length in 1 .. Max_Message;

   Stopped : constant String := "Stopped";

   procedure Read_Reply (Status : Natural; Reply : String)
     with Pre => State = Idle;
   --  For tests: take Reply, as the backend's reply with that HTTP status, as the task does, and
   --  make the state Done or Failed.

end Premium.Sources;
