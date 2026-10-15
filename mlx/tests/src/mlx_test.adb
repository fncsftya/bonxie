--  `mlx_test`: list the models in the Hugging Face cache.
--  `mlx_test <model folder>`: say whether the model will run, and, if it
--  will, what it replies to the test prompt.
with Ada.Command_Line;
with Ada.Text_IO;
with MLX;
with MLX.Hub;

procedure MLX_Test is
   use type MLX.States;
   Found : MLX.Hub.Models;
begin
   if Ada.Command_Line.Argument_Count = 0 then
      MLX.Hub.Scan (Found);
      Ada.Text_IO.Put_Line (MLX.Hub.Cache_Directory & " present:" & MLX.Hub.Is_Present'Image);
      for Which in 1 .. MLX.Hub.Count (Found) loop
         Ada.Text_IO.Put_Line (MLX.Hub.Model_At (Found, Which) & " -> " & MLX.Hub.Snapshot (MLX.Hub.Model_At (Found, Which)));
      end loop;
      return;
   end if;
   declare
   Directory : constant String := Ada.Command_Line.Argument (1);
   Why       : constant String := MLX.Problem (Directory);
begin
   if Why /= "" then
      Ada.Text_IO.Put_Line ("not usable: " & Why);
      return;
   end if;
   MLX.Start_Test (Directory);
   while MLX.State = MLX.Running loop
      delay 0.2;
   end loop;
   Ada.Text_IO.Put_Line (MLX.State'Image & ": " & MLX.Text);
   MLX.Reset;
   end;
end MLX_Test;
