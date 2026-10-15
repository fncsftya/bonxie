--  `mlx_test`                                   list the models in the Hugging Face cache.
--  `mlx_test --strip`                           check what is left of a reply less its thoughts.
--  `mlx_test <folder> [prompt [system [max tokens [off|on]]]]`
--                                               say whether the model will run and, if it will, what
--                                               it replies (twice: the second finds it loaded).
--  `mlx_test --cancel <folder>`                 start an ask and stop it.
--  `mlx_test --idle <folder>`                   ask, and see the model let go of when it is not asked for.
with Ada.Calendar;
with Ada.Command_Line;
with Ada.Text_IO;
with MLX.Hub;
with MLX.Jobs;

procedure MLX_Test is
   use type Ada.Calendar.Time;
   use type MLX.Jobs.States;
   package CL renames Ada.Command_Line;

   Test_Prompt : constant String := "This is a test, reply, in a single sentence, if it works";

   procedure List is
      Found : MLX.Hub.Models;
   begin
      MLX.Hub.Scan (Found);
      Ada.Text_IO.Put_Line (MLX.Hub.Cache_Directory & " present:" & MLX.Hub.Is_Present'Image);
      for Which in 1 .. MLX.Hub.Count (Found) loop
         Ada.Text_IO.Put_Line
           (MLX.Hub.Model_At (Found, Which) & " -> " & MLX.Hub.Snapshot (MLX.Hub.Model_At (Found, Which)));
      end loop;
   end List;

   procedure Strip is
      procedure Check (Raw, Expected : String) is
      begin
         if MLX.Without_Thinking (Raw) /= Expected then
            Ada.Text_IO.Put_Line ("FAIL: """ & Raw & """ gave """ & MLX.Without_Thinking (Raw) & """");
            CL.Set_Exit_Status (CL.Failure);
         end if;
      end Check;
   begin
      Check ("Yes.", "Yes.");
      Check ("  Yes." & ASCII.LF, "Yes.");
      Check ("<think>hm</think>Yes.", "Yes.");
      Check ("<think>hm" & ASCII.LF & "more</think>" & ASCII.LF & ASCII.LF & "Yes.", "Yes.");
      Check ("a<think>x</think>b<think>y</think>c", "abc");
      Check ("hm</think>Yes.", "Yes.");
      Check ("Yes.<think>and then", "Yes.");
      Check ("<think>only thought</think>", "<think>only thought</think>");
      Check ("", "");
      Ada.Text_IO.Put_Line ("strip checked");
   end Strip;

   procedure Ask (Folder, Prompt, Told : String; Most : Integer; Thinks : MLX.Thinking_Modes) is
      Why  : constant String := MLX.Problem (Folder);
      Task_Job : MLX.Jobs.Job;
   begin
      if Why /= "" then
         Ada.Text_IO.Put_Line ("not usable: " & Why);
         return;
      end if;
      for Round in 1 .. 2 loop
         declare
            Began : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         begin
            MLX.Jobs.Start
              (Task_Job, Folder, Prompt, Told, (Max_Tokens => Most, Thinking => Thinks, others => <>));
            while MLX.Jobs.State (Task_Job) = MLX.Jobs.Running loop
               delay 0.05;
            end loop;
            Ada.Text_IO.Put_Line
              (MLX.Jobs.State (Task_Job)'Image & " in" & Natural'Image (Natural (Float (Ada.Calendar.Clock - Began) * 10.0))
               & "/10 s: " & MLX.Jobs.Text (Task_Job));
            MLX.Jobs.Reset (Task_Job);
         end;
      end loop;
      MLX.Unload;
   end Ask;

   procedure Cancel (Folder : String) is
      Task_Job : MLX.Jobs.Job;
      Began    : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   begin
      MLX.Jobs.Start
        (Task_Job, Folder, "Count from 1 to 5000, one number to a line.",
         Tuning => (Max_Tokens => MLX.Unset_Integer, others => <>));
      delay 1.0;
      MLX.Jobs.Cancel (Task_Job);
      while MLX.Jobs.State (Task_Job) = MLX.Jobs.Running loop
         delay 0.05;
      end loop;
      Ada.Text_IO.Put_Line
        (MLX.Jobs.State (Task_Job)'Image & " after" & Natural'Image (Natural (Float (Ada.Calendar.Clock - Began) * 10.0))
         & "/10 s");
   end Cancel;
   procedure Idle (Folder : String) is
      Task_Job : MLX.Jobs.Job;
      Began    : Ada.Calendar.Time;
   begin
      MLX.Jobs.Set_Idle_Timeout (3.0);
      MLX.Jobs.Start (Task_Job, Folder, Test_Prompt, Tuning => (Max_Tokens => 20, others => <>));
      while MLX.Jobs.State (Task_Job) = MLX.Jobs.Running loop
         delay 0.05;
      end loop;
      Ada.Text_IO.Put_Line (MLX.Jobs.State (Task_Job)'Image & ", loaded: " & MLX.Is_Loaded'Image);
      Began := Ada.Calendar.Clock;
      while MLX.Is_Loaded and then Ada.Calendar.Clock - Began < 15.0 loop
         delay 0.1;
      end loop;
      Ada.Text_IO.Put_Line
        ("loaded: " & MLX.Is_Loaded'Image & " after"
         & Natural'Image (Natural (Float (Ada.Calendar.Clock - Began) * 10.0)) & "/10 s without a job");
      --  Asked again, it loads again, and is let go of again.
      MLX.Jobs.Start (Task_Job, Folder, Test_Prompt, Tuning => (Max_Tokens => 20, others => <>));
      while MLX.Jobs.State (Task_Job) = MLX.Jobs.Running loop
         delay 0.05;
      end loop;
      Ada.Text_IO.Put_Line (MLX.Jobs.State (Task_Job)'Image & ", loaded: " & MLX.Is_Loaded'Image);
      Began := Ada.Calendar.Clock;
      while MLX.Is_Loaded and then Ada.Calendar.Clock - Began < 15.0 loop
         delay 0.1;
      end loop;
      Ada.Text_IO.Put_Line ("loaded: " & MLX.Is_Loaded'Image);
   end Idle;
begin
   if CL.Argument_Count = 0 then
      List;
   elsif CL.Argument (1) = "--strip" then
      Strip;
   elsif CL.Argument (1) = "--idle" then
      Idle (CL.Argument (2));
   elsif CL.Argument (1) = "--cancel" then
      Cancel (CL.Argument (2));
   else
      Ask
        (CL.Argument (1),
         (if CL.Argument_Count >= 2 then CL.Argument (2) else Test_Prompt),
         (if CL.Argument_Count >= 3 then CL.Argument (3) else ""),
         (if CL.Argument_Count >= 4 then Integer'Value (CL.Argument (4)) else 512),
         (if CL.Argument_Count < 5 then MLX.Model_Default
          elsif CL.Argument (5) = "off" then MLX.Off else MLX.On));
   end if;
   MLX.Jobs.Shutdown;  --  or the watch that unloads the model is waited for
end MLX_Test;
