with Interfaces.C.Strings;

package body Webshot is

   use type Interfaces.C.int;

   function WS_Start
     (Which      : Interfaces.C.int;
      URL, Path  : Interfaces.C.char_array;
      Width      : Interfaces.C.int;
      Look       : Interfaces.C.char_array;
      Dismiss    : Interfaces.C.int;
      Tiles      : Interfaces.C.char_array) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_start";

   function WS_State (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_state";

   function WS_Height (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_height";

   function WS_Progress (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_progress";

   function WS_Title
     (Which : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "ws_title";

   function WS_Message
     (Which : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "ws_message";

   procedure WS_Pump (Milliseconds : Interfaces.C.int)
     with Import, Convention => C, External_Name => "ws_pump";

   procedure WS_Reset (Which : Interfaces.C.int)
     with Import, Convention => C, External_Name => "ws_reset";

   function Index (Which : Slot) return Interfaces.C.int is
     (Interfaces.C.int (Which - 1));

   function WS_Press (Which : Interfaces.C.int; Label : Interfaces.C.char_array) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_press";

   function WS_Continue (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_continue";

   function WS_Pressed (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_pressed";

   function WS_Document
     (Which : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "ws_document";

   procedure Start
     (Which           : Slot;
      URL             : String;
      File_Name       : String;
      Look_File       : String := "";
      Dismiss_Banners : Boolean := True;
      Tile_Prefix     : String := "")
   is
      Started : constant Interfaces.C.int :=
        WS_Start
          (Index (Which),
           Interfaces.C.To_C (URL), Interfaces.C.To_C (File_Name),
           Page_Width, Interfaces.C.To_C (Look_File), (if Dismiss_Banners then 1 else 0),
           Interfaces.C.To_C (Tile_Prefix));
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
         when 4 => Looked,
         when others => Idle);

   procedure Press (Which : Slot; Label : String) is
      Asked : constant Interfaces.C.int := WS_Press (Index (Which), Interfaces.C.To_C (Label));
   begin
      pragma Assert (Asked = 1);
   end Press;

   function WS_Tiles (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "ws_tiles";

   function Tile_Count (Which : Slot) return Natural is (Natural (WS_Tiles (Index (Which))));

   function Pressed (Which : Slot) return Boolean is (WS_Pressed (Index (Which)) = 1);

   procedure Continue (Which : Slot) is
      Asked : constant Interfaces.C.int := WS_Continue (Index (Which));
   begin
      pragma Assert (Asked = 1);
   end Continue;

   function Document_Link (Which : Slot) return String is
     (Interfaces.C.Strings.Value (WS_Document (Index (Which))));

   function Height (Which : Slot) return Natural is
     (Natural (WS_Height (Index (Which))));

   function Progress (Which : Slot) return Float is
     (Float'Min
        (1.0, Float'Max (0.0, Float (WS_Progress (Index (Which))) / 100.0)));

   function Page_Title (Which : Slot) return String is
     (Interfaces.C.Strings.Value (WS_Title (Index (Which))));

   function Message (Which : Slot) return String is
     (Interfaces.C.Strings.Value (WS_Message (Index (Which))));

   procedure Reset (Which : Slot) is
   begin
      WS_Reset (Index (Which));
   end Reset;

end Webshot;
