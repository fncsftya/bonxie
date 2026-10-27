with Ada.Containers.Vectors;
with System;
with Pomarine.Application;

package body Vision.Jobs is

   Max_Path : constant := 1_024;

   subtype Message_Text is String (1 .. Max_Message);

   type Result_Pointer is access Result;

   type Slot_Data is record
      Current   : Natural := 0;
      Stated    : States := Idle;
      Said      : Message_Text := [others => ' '];
      Said_Last : Natural := 0;
      Found     : Result_Pointer;
      --  What the slot's task writes, while the slot is Working (and no
      --  one else reads), and the caller reads once it is Done. Made when
      --  the slot is first started.
   end record;

   package Slot_Vectors is new Ada.Containers.Vectors (Positive, Slot_Data);

   function Place (Which : Slot) return Positive
   is (Which + Lane_Count);
   --  Where the slot is kept.

   protected Board is
      procedure Begin_Job (Which : Slot; Job : out Natural; Into : out Result_Pointer);
      --  Say it is Working: Job tells this one from an earlier, reset one.
      procedure End_Job (Which : Slot; Job : Natural; Ok : Boolean; Why : String);
      --  Ignored if the slot was reset since.
      procedure Forget (Which : Slot);
      function Stand (Which : Slot) return States;
      function Said_Why (Which : Slot) return String;
      function Result_Of (Which : Slot) return Result_Pointer;
   private
      Slots   : Slot_Vectors.Vector;
      Counter : Natural := 0;
   end Board;

   protected body Board is

      procedure Begin_Job (Which : Slot; Job : out Natural; Into : out Result_Pointer) is
      begin
         while Natural (Slots.Length) < Place (Which) loop
            Slots.Append (Slot_Data'(others => <>));
         end loop;
         Counter := Counter + 1;
         declare
            Mine : Slot_Data := Slots (Place (Which));
         begin
            if Mine.Found = null then
               Mine.Found := new Result;
            end if;
            Mine.Current := Counter;
            Mine.Stated := Working;
            Mine.Said_Last := 0;
            Slots.Replace_Element (Place (Which), Mine);
            Into := Mine.Found;
         end;
         Job := Counter;
      end Begin_Job;

      procedure End_Job (Which : Slot; Job : Natural; Ok : Boolean; Why : String) is
         Mine : Slot_Data := Slots (Place (Which));
      begin
         if Mine.Current /= Job then
            return;
         end if;
         if Ok then
            Mine.Stated := Done;
         else
            Mine.Stated := Failed;
            Mine.Said_Last := Natural'Min (Why'Length, Max_Message);
            Mine.Said (1 .. Mine.Said_Last) := Why (Why'First .. Why'First + Mine.Said_Last - 1);
         end if;
         Slots.Replace_Element (Place (Which), Mine);
      end End_Job;

      procedure Forget (Which : Slot) is
      begin
         if Natural (Slots.Length) >= Place (Which) then
            declare
               Mine : Slot_Data := Slots (Place (Which));
            begin
               Mine.Current := 0;
               Mine.Stated := Idle;
               Mine.Said_Last := 0;
               Slots.Replace_Element (Place (Which), Mine);
            end;
         end if;
      end Forget;

      function Stand (Which : Slot) return States
      is (if Natural (Slots.Length) >= Place (Which) then Slots (Place (Which)).Stated else Idle);

      function Said_Why (Which : Slot) return String
      is (if Natural (Slots.Length) >= Place (Which)
          then Slots (Place (Which)).Said (1 .. Slots (Place (Which)).Said_Last)
          else "");

      function Result_Of (Which : Slot) return Result_Pointer
      is (Slots (Place (Which)).Found);

   end Board;

   procedure Nothing (Data : System.Address) is null;
   --  What the application runs when told a job has ended: the waking up
   --  is all that is wanted, to look at the states.

   task type Worker with Storage_Size => 4 * 1024 * 1024 is
      entry Run (Which : Slot; Job : Natural; To : Result_Pointer; File : String);
   end Worker;

   task body Worker is
      Mine : Slot := 1;
      Wher : Natural := 0;
      Into : Result_Pointer;
      Name : String (1 .. Max_Path);
      Long : Natural := 0;
   begin
      loop
         select
            --  Take what to do, and let the caller go on.
            accept Run (Which : Slot; Job : Natural; To : Result_Pointer; File : String) do
               Mine := Which;
               Wher := Job;
               Into := To;
               Long := File'Length;
               Name (1 .. Long) := File;
            end Run;
            declare
               Ok   : Boolean;
               Why  : String (1 .. Max_Message);
               Last : Natural;
            begin
               Recognize (Name (1 .. Long), Into.all, Ok, Why, Last);
               Board.End_Job (Mine, Wher, Ok, Why (1 .. Last));
               --  Wake the application's loop, which is waiting for an
               --  event, to see it: it need not look until then.
               declare
                  Posted : constant Boolean := Pomarine.Application.Post (Nothing'Access);
                  pragma Unreferenced (Posted);
                  --  If the queue is full the loop is busy, and will look.
               begin
                  null;
               end;
            end;
         or
            terminate;
         end select;
      end loop;
   end Worker;

   type Worker_Access is access Worker;

   package Worker_Vectors is new Ada.Containers.Vectors (Positive, Worker_Access);

   Workers : Worker_Vectors.Vector;
   --  One to a slot, so that starting a job never waits for another's.
   --  Made when the slot is first started: a task costs its stack, and
   --  most slots are never used.

   procedure Start (Which : Slot; File_Name : String) is
      Job  : Natural;
      Into : Result_Pointer;
   begin
      Board.Begin_Job (Which, Job, Into);
      while Natural (Workers.Length) < Place (Which) loop
         Workers.Append (null);
      end loop;
      if Workers (Place (Which)) = null then
         Workers.Replace_Element (Place (Which), new Worker);
      end if;
      Workers (Place (Which)).Run (Which, Job, Into, File_Name);
   end Start;

   function State (Which : Slot) return States
   is (Board.Stand (Which));

   function Message (Which : Slot) return String
   is (Board.Said_Why (Which));

   procedure Take (Which : Slot; Into : in out Result) is
   begin
      Into := Board.Result_Of (Which).all;
      Board.Forget (Which);
   end Take;

   procedure Reset (Which : Slot) is
   begin
      Board.Forget (Which);
   end Reset;

end Vision.Jobs;
