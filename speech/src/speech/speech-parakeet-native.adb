with Interfaces.C;
with System;

package body Speech.Parakeet.Native
  with SPARK_Mode => Off
is

   use type Interfaces.C.int;

   function PK_Present (Directory : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "pk_present";

   function PK_Load
     (Directory : System.Address; Message : System.Address; Message_Room : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "pk_load";

   function PK_Transcribe
     (Samples      : System.Address;
      Count        : Interfaces.C.int;
      Text         : System.Address;
      Text_Room    : Interfaces.C.int;
      Text_Length  : out Interfaces.C.int;
      Token_Room   : Interfaces.C.int;
      Tokens       : out Interfaces.C.int;
      Text_Ends    : System.Address;
      Starts       : System.Address;
      Ends         : System.Address;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "pk_transcribe";

   procedure PK_Unload
   with Import, Convention => C, External_Name => "pk_unload";

   function GR_Present (Directory : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "gr_present";

   function GR_Load
     (Directory : System.Address; Message : System.Address; Message_Room : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "gr_load";

   function GR_Transcribe
     (Samples      : System.Address;
      Count        : Interfaces.C.int;
      Text         : System.Address;
      Text_Room    : Interfaces.C.int;
      Text_Length  : out Interfaces.C.int;
      Token_Room   : Interfaces.C.int;
      Tokens       : out Interfaces.C.int;
      Text_Ends    : System.Address;
      Starts       : System.Address;
      Ends         : System.Address;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "gr_transcribe";

   procedure GR_Unload
   with Import, Convention => C, External_Name => "gr_unload";

   Loaded : Model_Kinds := Parakeet_V3
   with Atomic;
   --  The model that hears: the last that was loaded.

   procedure Say (Raw : Interfaces.C.char_array; Message : in out String; Last : out Natural);
   --  Copy what the library said, as much as Message holds.

   procedure Say (Raw : Interfaces.C.char_array; Message : in out String; Last : out Natural) is
      Said : constant String := Interfaces.C.To_Ada (Raw);
      Used : constant Natural := Natural'Min (Said'Length, Message'Length);
   begin
      Message := [others => ' '];
      Message (Message'First .. Message'First + Used - 1) := Said (Said'First .. Said'First + Used - 1);
      Last := Used;
   end Say;

   function Models_Present (Kind : Model_Kinds; Directory : String) return Boolean is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
   begin
      return
        Directory /= ""
        and then (case Kind is
                    when Parakeet_V3 => PK_Present (Where'Address) = 1,
                    when Granite_5   => GR_Present (Where'Address) = 1);
   end Models_Present;

   procedure Load_Models
     (Kind : Model_Kinds; Directory : String; Ok : out Boolean; Message : in out String; Last : out Natural)
   is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Raw   : aliased Interfaces.C.char_array (0 .. 255) := [others => Interfaces.C.nul];
      Done  : Interfaces.C.int;
   begin
      --  Only one is kept in memory: the other is let go.
      case Kind is
         when Parakeet_V3 =>
            GR_Unload;
            Done := PK_Load (Where'Address, Raw'Address, Raw'Length);

         when Granite_5   =>
            PK_Unload;
            Done := GR_Load (Where'Address, Raw'Address, Raw'Length);
      end case;
      Ok := Done = 1;
      if Ok then
         Loaded := Kind;
      end if;
      Message := [others => ' '];
      Last := 0;
      if not Ok then
         Say (Raw, Message, Last);
      end if;
   end Load_Models;

   procedure Unload_Models is
   begin
      PK_Unload;
      GR_Unload;
   end Unload_Models;

   procedure Raw_Tokens
     (Audio             : Windows.Samples;
      Token_Text        : in out String;
      Token_Text_Length : out Natural;
      Token_Ends        : in out Windows.Offsets;
      Token_Starts      : in out Windows.Offsets;
      Token_Stops       : in out Windows.Offsets;
      Token_Count       : out Natural;
      Ok                : out Boolean;
      Message           : in out String;
      Last              : out Natural)
   is
      Raw    : aliased Interfaces.C.char_array (0 .. 255) := [others => Interfaces.C.nul];
      Length : Interfaces.C.int;
      Found  : Interfaces.C.int;
      Done   : Interfaces.C.int;
   begin
      Token_Text_Length := 0;
      Token_Count := 0;
      case Loaded is
         when Parakeet_V3 =>
            Done :=
              PK_Transcribe
                (Audio'Address,
                 Interfaces.C.int (Audio'Length),
                 Token_Text'Address,
                 Interfaces.C.int (Token_Text'Length),
                 Length,
                 Interfaces.C.int (Token_Ends'Length),
                 Found,
                 Token_Ends'Address,
                 Token_Starts'Address,
                 Token_Stops'Address,
                 Raw'Address,
                 Raw'Length);

         when Granite_5   =>
            Done :=
              GR_Transcribe
                (Audio'Address,
                 Interfaces.C.int (Audio'Length),
                 Token_Text'Address,
                 Interfaces.C.int (Token_Text'Length),
                 Length,
                 Interfaces.C.int (Token_Ends'Length),
                 Found,
                 Token_Ends'Address,
                 Token_Starts'Address,
                 Token_Stops'Address,
                 Raw'Address,
                 Raw'Length);
      end case;
      Ok := Done = 1;
      Message := [others => ' '];
      Last := 0;
      if Ok then
         Token_Text_Length := Natural (Interfaces.C.int'Max (0, Interfaces.C.int'Min (Length, Token_Text'Length)));
         Token_Count := Natural (Interfaces.C.int'Max (0, Interfaces.C.int'Min (Found, Token_Ends'Length)));
      else
         Say (Raw, Message, Last);
      end if;
   end Raw_Tokens;

end Speech.Parakeet.Native;
