with Interfaces.C.Strings;

package body Transcribe.Sessions is

   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.C.unsigned_long;
   use type System.Address;

   package C renames Interfaces.C;

   OK_Status : constant C.int := 0;
   --  TRANSCRIBE_OK.

   --  The structs of transcribe.h that are read or given, with the
   --  library's own init functions to fill them (they stamp struct_size).

   type Stream_Update is record
      Struct_Size        : C.unsigned_long;
      Result_Changed     : C.C_bool;
      Is_Final           : C.C_bool;
      Revision           : Interfaces.Integer_32;
      Input_Received_Ms  : Interfaces.Integer_64;
      Audio_Committed_Ms : Interfaces.Integer_64;
      Buffered_Ms        : Interfaces.Integer_64;
      Committed_Changed  : C.C_bool;
      Tentative_Changed  : C.C_bool;
   end record
     with Convention => C;

   type Stream_Text is record
      Struct_Size               : C.unsigned_long;
      Full_Text                 : System.Address;
      Full_Text_Bytes           : C.unsigned_long;
      Committed_Text            : System.Address;
      Committed_Text_Bytes      : C.unsigned_long;
      Tentative_Text            : System.Address;
      Tentative_Text_Bytes      : C.unsigned_long;
      Raw_Tentative_Start_Bytes : C.unsigned_long;
   end record
     with Convention => C;

   ABI_Stream_Update : constant C.int := 9;
   ABI_Stream_Text   : constant C.int := 10;

   function C_Struct_Size (Which : C.int) return C.size_t
     with Import, Convention => C,
          External_Name => "transcribe_abi_struct_size";

   function C_Status_String (Status : C.int) return C.Strings.chars_ptr
     with Import, Convention => C,
          External_Name => "transcribe_status_string";

   function C_Open
     (Path           : C.char_array;
      Load_Params    : System.Address;
      Session_Params : System.Address;
      Out_Session    : out System.Address) return C.int
     with Import, Convention => C, External_Name => "transcribe_open";

   type Log_Callback is access procedure
     (Level : C.int; Message : System.Address; Data : System.Address)
     with Convention => C;

   procedure C_Log_Set (Callback : Log_Callback; Data : System.Address)
     with Import, Convention => C, External_Name => "transcribe_log_set";

   procedure Ignore_Log
     (Level : C.int; Message : System.Address; Data : System.Address)
     with Convention => C;
   --  The library's chatter (every Metal kernel it compiles) is not for
   --  the terminal; what goes wrong comes back as a status.

   procedure Ignore_Log
     (Level : C.int; Message : System.Address; Data : System.Address) is
   begin
      null;
   end Ignore_Log;

   procedure C_Session_Free (Handle : System.Address)
     with Import, Convention => C, External_Name => "transcribe_session_free";

   function C_Stream_Begin
     (Handle        : System.Address;
      Run_Params    : System.Address;
      Stream_Params : System.Address) return C.int
     with Import, Convention => C, External_Name => "transcribe_stream_begin";

   procedure C_Update_Init (Update : out Stream_Update)
     with Import, Convention => C,
          External_Name => "transcribe_stream_update_init";

   procedure C_Text_Init (Found : out Stream_Text)
     with Import, Convention => C,
          External_Name => "transcribe_stream_text_init";

   function C_Stream_Feed
     (Handle    : System.Address;
      Pcm       : System.Address;
      N_Samples : C.int;
      Update    : in out Stream_Update) return C.int
     with Import, Convention => C, External_Name => "transcribe_stream_feed";

   function C_Stream_Finalize
     (Handle : System.Address;
      Update : in out Stream_Update) return C.int
     with Import, Convention => C,
          External_Name => "transcribe_stream_finalize";

   function C_Stream_Get_Text
     (Handle : System.Address;
      Found  : in out Stream_Text) return C.int
     with Import, Convention => C,
          External_Name => "transcribe_stream_get_text";

   procedure Say
     (Status  : C.int;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1;
   --  Message is the library's words for a status.

   procedure Say (Why : String; Message : out String; Last : out Natural)
     with Pre => Message'First = 1;

   procedure Say (Why : String; Message : out String; Last : out Natural) is
   begin
      Last := Natural'Min (Why'Length, Message'Length);
      Message := [others => ' '];
      Message (1 .. Last) := Why (Why'First .. Why'First + Last - 1);
   end Say;

   procedure Say
     (Status  : C.int;
      Message : out String;
      Last    : out Natural) is
   begin
      Say (C.Strings.Value (C_Status_String (Status)), Message, Last);
   end Say;

   function Layout_Agrees return Boolean is
     ((C_Struct_Size (ABI_Stream_Update) = 0
       or else C_Struct_Size (ABI_Stream_Update)
               = C.size_t (Stream_Update'Object_Size / 8))
      and then
      (C_Struct_Size (ABI_Stream_Text) = 0
       or else C_Struct_Size (ABI_Stream_Text)
               = C.size_t (Stream_Text'Object_Size / 8)));
   --  The records above are the library's (0 from it: it cannot say).

   function Is_Open (Item : Session) return Boolean is
     (Item.Handle /= System.Null_Address);

   function Is_Streaming (Item : Session) return Boolean is
     (Item.Streaming);

   procedure Open
     (Item    : in out Session;
      Path    : String;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Status : C.int;
   begin
      Last := 0;
      Message := [others => ' '];
      if not Layout_Agrees then
         Ok := False;
         Say ("The speech library is not the one built against",
              Message, Last);
         return;
      end if;
      C_Log_Set (Ignore_Log'Access, System.Null_Address);
      Status :=
        C_Open (C.To_C (Path), System.Null_Address, System.Null_Address,
                Item.Handle);
      Ok := Status = OK_Status and then Item.Handle /= System.Null_Address;
      if not Ok then
         Item.Handle := System.Null_Address;
         Say (Status, Message, Last);
      end if;
   end Open;

   procedure Begin_Stream
     (Item    : in out Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Status : constant C.int :=
        C_Stream_Begin (Item.Handle, System.Null_Address, System.Null_Address);
   begin
      Last := 0;
      Message := [others => ' '];
      Ok := Status = OK_Status;
      Item.Streaming := Ok;
      if not Ok then
         Say (Status, Message, Last);
      end if;
   end Begin_Stream;

   procedure Feed
     (Item    : in out Session;
      Audio   : Samples;
      Changed : out Boolean;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Update : Stream_Update;
      Status : C.int;
   begin
      Last := 0;
      Message := [others => ' '];
      Changed := False;
      if Audio'Length = 0 then
         Ok := True;
         return;
      end if;
      C_Update_Init (Update);
      Status :=
        C_Stream_Feed
          (Item.Handle, Audio (Audio'First)'Address,
           C.int (Audio'Length), Update);
      Ok := Status = OK_Status;
      if Ok then
         Changed := Boolean'Val (C.C_bool'Pos (Update.Result_Changed));
      else
         Item.Streaming := False;
         Say (Status, Message, Last);
      end if;
   end Feed;

   procedure Finalize_Stream
     (Item    : in out Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Update : Stream_Update;
      Status : C.int;
   begin
      Last := 0;
      Message := [others => ' '];
      C_Update_Init (Update);
      Status := C_Stream_Finalize (Item.Handle, Update);
      Ok := Status = OK_Status;
      Item.Streaming := False;
      if not Ok then
         Say (Status, Message, Last);
      end if;
   end Finalize_Stream;

   procedure Text
     (Item      : Session;
      Into      : out String;
      Last      : out Natural;
      Truncated : out Boolean)
   is
      Found : Stream_Text;
   begin
      Last := 0;
      Truncated := False;
      Into := [others => ' '];
      C_Text_Init (Found);
      if C_Stream_Get_Text (Item.Handle, Found) /= OK_Status
        or else Found.Full_Text = System.Null_Address
      then
         return;
      end if;
      --  The library's bytes are good only until the next Feed: copy them
      --  now, not in the middle of a UTF-8 character.
      declare
         Bytes : constant Natural :=
           Natural'Min (Natural (Found.Full_Text_Bytes), Text_Capacity);
         Chars : String (1 .. Bytes)
           with Import, Address => Found.Full_Text;
         Take  : Natural := Natural'Min (Bytes, Into'Length);
      begin
         Truncated := Take < Natural (Found.Full_Text_Bytes);
         if Truncated then
            while Take > 0
              and then Character'Pos (Chars (Take + 1)) in 16#80# .. 16#BF#
            loop
               Take := Take - 1;
            end loop;
         end if;
         Into (1 .. Take) := Chars (1 .. Take);
         Last := Take;
      end;
   end Text;

   procedure Close (Item : in out Session) is
   begin
      if Item.Handle /= System.Null_Address then
         C_Session_Free (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
      Item.Streaming := False;
   end Close;

   overriding procedure Finalize (Item : in out Session) is
   begin
      Close (Item);
   end Finalize;

end Transcribe.Sessions;
