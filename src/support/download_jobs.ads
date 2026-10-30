--  A file fetched in the background: one at a time, by a task of its own
--  (which runs curl, so that neither the wait for the server nor the
--  transfer holds up the caller). The caller polls (State, Fraction) and
--  starts the next when it is no longer Running. The file appears at its
--  name only once all of it has come, so that one there is whole.

generic
package Download_Jobs is

   type States is (Idle, Running, Done, Failed);
   --  Idle: nothing was started, or it was forgotten (Reset). Done: the
   --  file is in place. Failed: it is not, and Message says why.

   Max_Path    : constant := 1024;
   --  The canvas source reader's protocol limit; the download worker itself accepts longer paths.
   Max_Message : constant := 120;

   procedure Start (URL, File_Name : String)
   with Pre => State /= Running and then File_Name /= "", Post => State = Running;
   --  Begin to fetch the URL (redirects are followed) into File_Name,
   --  making the folder it is in if need be.

   function State return States;

   function Fraction return Float
   with Post => Fraction'Result in 0.0 .. 1.0;
   --  How much of the file has come, as the server said how long it is:
   --  0.0 until it has, and while Idle or Failed; 1.0 when Done.

   function Message return String
   with Pre => State = Failed, Post => Message'Result'Length <= Max_Message;

   procedure Reset
   with Pre => State /= Running, Post => State = Idle;
   --  Forget how the last one ended.

   procedure Cancel;
   --  Stop the transfer, if there is one, and throw away what has come.
   --  It does not wait: the state is Failed when the task has seen to it.
   --  For when the program is ending.

end Download_Jobs;
