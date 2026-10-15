--  Local language models on MLX, which runs them on the Mac's GPU, by
--  mlx-swift-lm (libBonxieMLX, see swift/Sources). A model is a folder of
--  files, a Hugging Face snapshot; only a model converted for MLX will run,
--  and Problem says whether this one is.
--
--  Nothing here waits for long: the test runs in the background, one at a
--  time, and the caller polls State, as for Speech.Models.
package MLX is

   Max_Path    : constant := 1024;
   Max_Message : constant := 4096;
   --  Bytes of a model's folder, and of what is said about it.
   Max_Reply   : constant := 65536;
   --  Bytes of a model's reply: more is left out.

   function Problem (Directory : String) return String
     with Pre  => Directory'Length in 1 .. Max_Path,
          Post => Problem'Result'Length <= Max_Message;
   --  Why the model in Directory will not run here, or "" if it will:
   --  it is not converted for MLX, it is of a kind not supported, or its
   --  files are not all there.

   type States is (Idle, Running, Done, Failed);
   --  Idle: no test was begun, or it was forgotten (Reset). Done: the
   --  model replied, and Text is what it said. Failed: it did not, and Text
   --  says why.

   procedure Start_Test (Directory : String)
     with Pre  => State /= Running
                  and then Directory'Length in 1 .. Max_Path,
          Post => State = Running;
   --  Begin to load the model in Directory and ask it to reply, in a
   --  sentence, if it works.

   function State return States;

   function Text return String
     with Pre  => State in Done | Failed,
          Post => Text'Result'Length <= Max_Reply;

   procedure Reset
     with Post => State = Idle;
   --  Forget how the last test ended (and let go of one that is running).

end MLX;
