with Interfaces.C.Strings;

package body Webshot is

   use type Interfaces.C.int;

   function WS_Start
     (Which      : Interfaces.C.int;
      URL, Path  : Interfaces.C.char_array;
      Width      : Interfaces.C.int;
      Tallest    : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_start";

   function WS_State (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_state";

   function WS_Height (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_height";

   function WS_Message
     (Which : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "ws_message";

   procedure WS_Pump (Milliseconds : Interfaces.C.int)
     with Import, Convention => C, External_Name => "ws_pump";

   procedure WS_Reset (Which : Interfaces.C.int)
     with Import, Convention => C, External_Name => "ws_reset";

   function Index (Which : Slot) return Interfaces.C.int is
     (Interfaces.C.int (Which - 1));

   procedure Start (Which : Slot; URL : String; File_Name : String) is
      Started : constant Interfaces.C.int :=
        WS_Start
          (Index (Which),
           Interfaces.C.To_C (URL), Interfaces.C.To_C (File_Name),
           Page_Width, Max_Height);
   begin
      pragma Assert (Started = 1);
   end Start;

   procedure Pump (Milliseconds : Natural) is
   begin
      WS_Pump (Interfaces.C.int (Milliseconds));
   end Pump;

   function State (Which : Slot) return States is
     (case WS_State (Index (Which)) is
         when 1 => Working,
         when 2 => Done,
         when 3 => Failed,
         when others => Idle);

   function Height (Which : Slot) return Natural is
     (Natural (WS_Height (Index (Which))));

   function Message (Which : Slot) return String is
     (Interfaces.C.Strings.Value (WS_Message (Index (Which))));

   procedure Reset (Which : Slot) is
   begin
      WS_Reset (Index (Which));
   end Reset;

end Webshot;
