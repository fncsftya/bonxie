--  The speech model fetched in the background (it is a folder of some
--  hundreds of megabytes, which the library downloads itself), one fetch at
--  a time. The caller polls (State, Fraction) and starts the next when it
--  is no longer Running. Where the model is kept is a folder of the
--  caller's choosing: the model is Present when all of it has come.
package Speech.Models is

   type States is (Idle, Running, Done, Failed);
   --  Idle: nothing was started, or it was forgotten (Reset). Done: the
   --  model is in place. Failed: it is not, and Message says why.

   Max_Path    : constant := 1024;
   Max_Message : constant := 120;

   function Present (Directory : String) return Boolean;
   --  Whether the model is all in Directory.

   procedure Start (Directory : String)
     with Pre  => State /= Running
                  and then Directory'Length in 1 .. Max_Path,
          Post => State = Running;
   --  Begin to fetch the model into Directory, making it if need be.

   function State return States;

   function Fraction return Float
     with Post => Fraction'Result in 0.0 .. 1.0;
   --  How much has come: 0.0 while Idle, 1.0 when Done.

   function Total_Bytes return Long_Long_Integer
     with Post => Total_Bytes'Result >= 0;
   --  How many bytes the fetch comes to in all: 0 until that is known (or
   --  if it cannot be found out).

   function Size_On_Disk (Directory : String) return Long_Long_Integer
     with Post => Size_On_Disk'Result >= 0;
   --  The bytes of the files in Directory and below it, 0 if there is none.

   procedure Delete (Directory : String)
     with Pre  => State /= Running and then Directory'Length in 1 .. Max_Path,
          Post => not Present (Directory);
   --  Remove the model, all of Directory, and let the program forget it.

   function Message return String
     with Pre  => State = Failed,
          Post => Message'Result'Length <= Max_Message;

   procedure Reset
     with Pre  => State /= Running,
          Post => State = Idle;
   --  Forget how the last one ended.

   procedure Cancel;
   --  Stop the fetch, if there is one. It does not wait: the state is
   --  Failed when the library has seen to it. For when the program is
   --  ending.

end Speech.Models;
