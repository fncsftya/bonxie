with SDL3.Windows.Renderers;
with SDL3.Windows.Renderers.Textures;

--  Pictures read in the background, by a few tasks of their own, while the
--  caller goes on. A job is asked for (Request) with a ticket; the caller
--  polls it (State) and, when it is Done, makes a texture of it (Finish),
--  or gives it up (Cancel). Jobs that are Urgent are begun before those
--  that are not, which wait for a task to be free of them; of the same
--  kind, in the order asked.
--
--  Only one thread, the caller's, may use the subprograms here.
package SDL3.Pictures.Jobs is

   Max_Jobs : constant := 32;
   --  Asked for and not yet finished or given up. A cancelled job that is
   --  running counts until it ends.

   Max_Path : constant := 1_024;

   subtype Ticket is Positive range 1 .. Max_Jobs;

   type States is (Working, Done, Failed);
   --  Working: waiting or being read. Done: the picture is there to
   --  Finish. Failed: the file could not be read; Cancel the ticket.

   procedure Request
     (File_Name : String; Urgent : Boolean; Job : out Ticket)
     with Pre => File_Name'Length in 1 .. Max_Path;
   --  Begin to read the PNG file. The state is Working. Raises
   --  Program_Error if there are Max_Jobs outstanding.

   procedure Prioritize (Job : Ticket);
   --  Make it Urgent, if it is still waiting.

   function State (Job : Ticket) return States;

   procedure Finish
     (Job    : Ticket;
      Into   : in out SDL3.Windows.Renderers.Textures.Texture;
      Target : SDL3.Windows.Renderers.Renderer;
      Dark   : out Boolean)
     with Pre => State (Job) = Done;
   --  Replace Into with the picture, drawn smoothed by Target. Dark is
   --  as for Decode. The ticket is used up.

   procedure Cancel (Job : Ticket);
   --  Forget the job, whatever its state: its picture, if it has one, is
   --  let go of, and one being read is thrown away when it is. The ticket
   --  is used up.

   procedure Wait_Until_Idle;
   --  Wait for every job asked for to be read (or to fail): for tests,
   --  that draw a picture the moment it is ready, not when it is.

end SDL3.Pictures.Jobs;
