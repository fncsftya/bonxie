with Interfaces.C;
with System;

package body Speech.Parakeet is

   use type Interfaces.C.int;

   function PK_Present (Directory : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_present";

   function PK_Load
     (Directory    : System.Address;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_load";

   function PK_Transcribe
     (Samples      : System.Address;
      Count        : Interfaces.C.int;
      Text         : System.Address;
      Text_Room    : Interfaces.C.int;
      Text_Length  : out Interfaces.C.int;
      Word_Room    : Interfaces.C.int;
      Words        : out Interfaces.C.int;
      Text_Ends    : System.Address;
      Sample_Starts : System.Address;
      Sample_Ends  : System.Address;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_transcribe";

   procedure PK_Unload
     with Import, Convention => C, External_Name => "pk_unload";

   procedure Say
     (Raw     : Interfaces.C.char_array;
      Message : out String;
      Last    : out Natural);
   --  Copy what the library said, as much as Message holds.

   procedure Say
     (Raw     : Interfaces.C.char_array;
      Message : out String;
      Last    : out Natural)
   is
      Said : constant String := Interfaces.C.To_Ada (Raw);
      Used : constant Natural := Natural'Min (Said'Length, Message'Length);
   begin
      Message := [others => ' '];
      Message (Message'First .. Message'First + Used - 1) :=
        Said (Said'First .. Said'First + Used - 1);
      Last := Message'First - 1 + Used;
   end Say;

   function Present (Directory : String) return Boolean is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
   begin
      return Directory /= "" and then PK_Present (Where'Address) = 1;
   end Present;

   procedure Load
     (Directory : String;
      Ok        : out Boolean;
      Message   : out String;
      Last      : out Natural)
   is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Raw   : aliased Interfaces.C.char_array (0 .. 255) := [others => Interfaces.C.nul];
      Done  : constant Interfaces.C.int := PK_Load (Where'Address, Raw'Address, Raw'Length);
   begin
      Ok := Done = 1;
      Message := [others => ' '];
      Last := 0;
      if not Ok then
         Say (Raw, Message, Last);
      end if;
   end Load;

   procedure Transcribe
     (Audio   : Windows.Samples;
      Into    : out Heard;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Raw    : aliased Interfaces.C.char_array (0 .. 255) := [others => Interfaces.C.nul];
      Length : Interfaces.C.int;
      Words  : Interfaces.C.int;
      Done   : Interfaces.C.int;
   begin
      Into.Count := 0;
      Into.Text_Length := 0;
      Done := PK_Transcribe
        (Audio'Address, Interfaces.C.int (Audio'Length),
         Into.Text'Address, Interfaces.C.int (Into.Text'Length), Length,
         Interfaces.C.int (Max_Words), Words,
         Into.Text_Ends'Address, Into.Sample_Starts'Address, Into.Sample_Ends'Address,
         Raw'Address, Raw'Length);
      Ok := Done = 1;
      Message := [others => ' '];
      Last := 0;
      if Ok then
         Into.Text_Length := Natural (Interfaces.C.int'Min (Length, Interfaces.C.int (Text_Capacity)));
         Into.Count := Word_Count (Interfaces.C.int'Min (Words, Interfaces.C.int (Max_Words)));
         Windows.Repair
           (Into.Sample_Starts (1 .. Into.Count), Into.Sample_Ends (1 .. Into.Count), Audio'Length);
         if not Windows.Text_Plausible (Into.Text_Ends (1 .. Into.Count), Into.Text_Length) then
            Ok := False;
            Into.Count := 0;
            Into.Text_Length := 0;
            Say (Interfaces.C.To_C ("The speech model's text could not be made sense of"), Message, Last);
         end if;
      else
         Say (Raw, Message, Last);
      end if;
   end Transcribe;

   procedure Unload is
   begin
      PK_Unload;
   end Unload;

end Speech.Parakeet;
