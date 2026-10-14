package body SDL3.Pictures.Jobs is

   Worker_Count : constant := 2;
   subtype Worker_Id is Positive range 1 .. Worker_Count;
   --  Fewer than the cores: the one that is drawing needs one.

   type Job_States is (Free, Waiting, Running, Ready, Broken, Abandoned,
                       Discarding);
   --  Abandoned: cancelled while running. Discarding: it has ended, and
   --  its task is letting go of what it read.

   subtype Name_Text is String (1 .. Max_Path);

   type Job_Record is record
      State  : Job_States := Free;
      Urgent : Boolean := False;
      Order  : Natural := 0;
      Dark   : Boolean := False;
      Length : Natural := 0;
      Name   : Name_Text := [others => ' '];
   end record;

   type Job_Array is array (Ticket) of Job_Record;
   type Idle_Array is array (Worker_Id) of Boolean;

   Results : array (Ticket) of Decoded;
   --  A job's picture: written by its task while it is Running, and
   --  otherwise by no one but the caller, once it is Ready.

   protected Board is
      procedure Add
        (File : String; Urgent : Boolean; Job : out Ticket;
         Wake : out Natural);
      --  Wake: a task that was idle and is now to look for work, or 0.
      procedure Bump (Job : Ticket);
      --  Make it Urgent.
      procedure Cancel (Job : Ticket; Release : out Boolean);
      --  Release: the caller is to let go of Results (Job).
      procedure Take (Job : Ticket; Dark : out Boolean);
      procedure Claim
        (Worker : Worker_Id; Job : out Natural;
         File : in out Name_Text; Length : out Natural);
      --  The next job to read, or 0, when the task is idle.
      procedure Finish
        (Job : Ticket; Ok : Boolean; Dark : Boolean; Release : out Boolean);
      --  Release: the task is to let go of Results (Job), and then say so
      --  (Freed).
      procedure Freed (Job : Ticket);
      function Standing (Job : Ticket) return States;
      function Busy return Boolean;
   private
      Jobs    : Job_Array;
      Counter : Natural := 0;
      Idle    : Idle_Array := [others => True];
   end Board;

   protected body Board is

      procedure Add
        (File : String; Urgent : Boolean; Job : out Ticket;
         Wake : out Natural) is
      begin
         Job := 1;
         while Jobs (Job).State /= Free loop
            if Job = Ticket'Last then
               raise Program_Error with "too many pictures being read";
            end if;
            Job := Job + 1;
         end loop;
         Counter := Counter + 1;
         Jobs (Job) :=
           (State  => Waiting, Urgent => Urgent, Order => Counter,
            Dark   => False, Length => File'Length,
            Name   => [others => ' ']);
         Jobs (Job).Name (1 .. File'Length) := File;
         Wake := 0;
         for Each in Worker_Id loop
            if Idle (Each) then
               Idle (Each) := False;
               Wake := Each;
               exit;
            end if;
         end loop;
      end Add;

      procedure Bump (Job : Ticket) is
      begin
         Jobs (Job).Urgent := True;
      end Bump;

      procedure Cancel (Job : Ticket; Release : out Boolean) is
      begin
         Release := False;
         case Jobs (Job).State is
            when Waiting | Broken =>
               Jobs (Job).State := Free;
            when Ready =>
               Jobs (Job).State := Free;
               Release := True;
            when Running =>
               Jobs (Job).State := Abandoned;
            when Free | Abandoned | Discarding =>
               null;
         end case;
      end Cancel;

      procedure Take (Job : Ticket; Dark : out Boolean) is
      begin
         Dark := Jobs (Job).Dark;
         Jobs (Job).State := Free;
      end Take;

      procedure Claim
        (Worker : Worker_Id; Job : out Natural;
         File : in out Name_Text; Length : out Natural)
      is
         Best : Natural := 0;
      begin
         for Each in Ticket loop
            if Jobs (Each).State = Waiting
              and then (Best = 0
                        or else (Jobs (Each).Urgent
                                 and then not Jobs (Best).Urgent)
                        or else (Jobs (Each).Urgent = Jobs (Best).Urgent
                                 and then Jobs (Each).Order
                                          < Jobs (Best).Order))
            then
               Best := Each;
            end if;
         end loop;
         Job := Best;
         Length := 0;
         if Best = 0 then
            Idle (Worker) := True;
         else
            Jobs (Best).State := Running;
            Length := Jobs (Best).Length;
            File := Jobs (Best).Name;
         end if;
      end Claim;

      procedure Finish
        (Job : Ticket; Ok : Boolean; Dark : Boolean; Release : out Boolean) is
      begin
         Release := False;
         if Jobs (Job).State = Abandoned then
            Jobs (Job).State := Discarding;
            Release := True;
         else
            Jobs (Job).State := (if Ok then Ready else Broken);
            Jobs (Job).Dark := Dark;
         end if;
      end Finish;

      procedure Freed (Job : Ticket) is
      begin
         Jobs (Job).State := Free;
      end Freed;

      function Standing (Job : Ticket) return States is
        (case Jobs (Job).State is
            when Ready  => Done,
            when Broken => Failed,
            when others => Working);

      function Busy return Boolean is
        (for some Each of Jobs =>
           Each.State in Waiting | Running | Abandoned | Discarding);

   end Board;

   task type Worker (Me : Worker_Id)
     with Storage_Size => 4 * 1024 * 1024
   is
      entry Run;
   end Worker;

   task body Worker is
      Name    : Name_Text;
      Length  : Natural;
      Job     : Natural;
      Dark    : Boolean;
      Ok      : Boolean;
      Release : Boolean;
   begin
      loop
         select
            accept Run;
         or
            terminate;
         end select;
         loop
            Board.Claim (Me, Job, Name, Length);
            exit when Job = 0;
            begin
               Decode (Results (Job), Name (1 .. Length), Dark);
               Ok := True;
            exception
               when others =>
                  Ok := False;
                  Dark := False;
            end;
            Board.Finish (Job, Ok, Dark, Release);
            if Release then
               SDL3.Pictures.Release (Results (Job));
               Board.Freed (Job);
            end if;
         end loop;
      end loop;
   end Worker;

   Worker_1 : Worker (1);
   Worker_2 : Worker (2);
   --  A task is idle, in Board, from when it finds no more work until it
   --  is woken for some: so Run is only called of a task about to accept.

   procedure Request
     (File_Name : String; Urgent : Boolean; Job : out Ticket)
   is
      Wake : Natural;
   begin
      Board.Add (File_Name, Urgent, Job, Wake);
      case Wake is
         when 1 => Worker_1.Run;
         when 2 => Worker_2.Run;
         when others => null;
      end case;
   end Request;

   procedure Prioritize (Job : Ticket) is
   begin
      Board.Bump (Job);
   end Prioritize;

   function State (Job : Ticket) return States is (Board.Standing (Job));

   procedure Finish
     (Job    : Ticket;
      Into   : in out SDL3.Windows.Renderers.Textures.Texture;
      Target : SDL3.Windows.Renderers.Renderer;
      Dark   : out Boolean) is
   begin
      begin
         SDL3.Windows.Renderers.Textures.Create_From_Decoded
           (Into, Target, Results (Job));
      exception
         when others =>
            Cancel (Job);
            raise;
      end;
      Board.Take (Job, Dark);
      SDL3.Pictures.Release (Results (Job));
   end Finish;

   procedure Cancel (Job : Ticket) is
      Release : Boolean;
   begin
      Board.Cancel (Job, Release);
      if Release then
         SDL3.Pictures.Release (Results (Job));
      end if;
   end Cancel;

   procedure Wait_Until_Idle is
   begin
      while Board.Busy loop
         delay 0.001;
      end loop;
   end Wait_Until_Idle;

end SDL3.Pictures.Jobs;
