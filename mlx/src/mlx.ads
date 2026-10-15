--  Local language models on MLX, which runs them on the Mac's GPU, by
--  mlx-swift-lm (libBonxieMLX, see swift/Sources, which is only a thin
--  binding). A model is a folder of files, a Hugging Face snapshot (see
--  MLX.Hub); only a model converted for MLX will run, and Problem says
--  whether this one is.
--
--  What is asked of a model, and how it is tasked, is here: a Job (see
--  MLX.Jobs) asks a model in the background, with a prompt, a system prompt
--  and the parameters that tune it.
package MLX is

   Max_Path    : constant := 1024;
   Max_Message : constant := 400;
   --  Bytes of a model's folder, and of what is said of it.
   Max_Reply   : constant := 32_000;
   --  Bytes of a model's reply: more is left out.

   function Problem (Directory : String) return String
     with Pre  => Directory'Length in 1 .. Max_Path,
          Post => Problem'Result'Length <= Max_Message;
   --  Why the model in Directory will not run here, or "" if it will:
   --  it is not converted for MLX, it is of a kind not supported, or its
   --  files are not all there.

   procedure Unload;
   --  Let go of the model kept in memory (it is a few gigabytes), if there
   --  is one. A model is loaded by the first job that asks it and kept
   --  for the next, until another is asked for or this.

   function Is_Loaded return Boolean;
   --  Whether a model is in memory.

   procedure Cancel_All;
   --  Stop every job that is running, without waiting. For when the
   --  program is ending: a job that is not stopped is waited for.

   --  Tuning

   Unset_Integer : constant := -1;
   Unset_Float   : constant := -1.0;
   --  What a parameter is left at to leave it to the model's own.

   type Thinking_Modes is (Model_Default, Off, On);
   --  Whether a model that can think (and says so aloud, as
   --  <think>...</think>) is asked to, or not to.

   type Parameters is record
      Max_Tokens         : Integer range Unset_Integer .. 1_000_000 := 512;
      --  The most tokens to make; Unset_Integer for no limit.
      Temperature        : Float range Unset_Float .. 10.0 := Unset_Float;
      --  0.0 always takes the likeliest; more is more varied.
      Top_P              : Float range Unset_Float .. 1.0 := Unset_Float;
      --  Only the likeliest tokens that add up to this much are taken.
      Top_K              : Integer range Unset_Integer .. 1_000_000 := Unset_Integer;
      --  Only this many of the likeliest tokens are taken; 0 for all.
      Min_P              : Float range Unset_Float .. 1.0 := Unset_Float;
      --  Tokens less likely than this, of the likeliest's, are not taken.
      Repetition_Penalty : Float range Unset_Float .. 10.0 := Unset_Float;
      --  Over 1.0 makes what was said lately less likely.
      Repetition_Context : Integer range Unset_Integer .. 100_000 := Unset_Integer;
      --  How many of the last tokens that is of.
      Seed               : Long_Long_Integer range Unset_Integer .. Long_Long_Integer'Last := Unset_Integer;
      --  Given, with a Temperature over 0.0, the same prompt has the same
      --  reply again.
      Thinking           : Thinking_Modes := Model_Default;
   end record;

   function Without_Thinking (Raw : String) return String
     with Post => Without_Thinking'Result'Length <= Raw'Length;
   --  What a model replied, less what it thought aloud (anything in
   --  <think>...</think>, or all before a </think>, or after a <think>
   --  that is not closed), with the space about it taken off; Raw, so,
   --  if that leaves nothing.

end MLX;
