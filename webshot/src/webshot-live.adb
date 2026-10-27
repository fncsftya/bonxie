with Interfaces.C;

package body Webshot.Live is

   use type Interfaces.C.int;

   function WL_Attach (Window : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_attach";

   procedure WL_Detach
   with Import, Convention => C, External_Name => "wl_detach";

   procedure WL_Set_Frame (X, Y, W, H : Interfaces.C.double)
   with Import, Convention => C, External_Name => "wl_set_frame";

   procedure WL_Set_Hidden (Hidden : Interfaces.C.int)
   with Import, Convention => C, External_Name => "wl_set_hidden";

   procedure WL_Load (URL : Interfaces.C.char_array)
   with Import, Convention => C, External_Name => "wl_load";

   procedure WL_Focus (Page : Interfaces.C.int)
   with Import, Convention => C, External_Name => "wl_focus";

   function WL_Has_Focus return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_has_focus";

   procedure WL_Back
   with Import, Convention => C, External_Name => "wl_back";

   procedure WL_Forward
   with Import, Convention => C, External_Name => "wl_forward";

   procedure WL_Reload
   with Import, Convention => C, External_Name => "wl_reload";

   function WL_Can_Back return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_can_back";

   function WL_Can_Forward return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_can_forward";

   function WL_Loading return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_loading";

   function WL_Progress return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_progress";

   function WL_Title (Buffer : in out Interfaces.C.char_array; Capacity : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_title";

   function WL_URL (Buffer : in out Interfaces.C.char_array; Capacity : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_url";

   procedure WL_Keep (Letter, Number : Interfaces.C.int)
   with Import, Convention => C, External_Name => "wl_keep";

   function WL_Shortcut return Interfaces.C.int
   with Import, Convention => C, External_Name => "wl_shortcut";

   Is_Attached : Boolean := False;

   function Flag (Value : Boolean) return Interfaces.C.int
   is (if Value then 1 else 0);

   procedure Attach (Window : System.Address) is
   begin
      Is_Attached := WL_Attach (Window) /= 0;
   end Attach;

   procedure Detach is
   begin
      if Is_Attached then
         WL_Detach;
         Is_Attached := False;
      end if;
   end Detach;

   function Attached return Boolean
   is (Is_Attached);

   procedure Place (X, Y, Wide, High : Float) is
   begin
      WL_Set_Frame
        (Interfaces.C.double (X), Interfaces.C.double (Y), Interfaces.C.double (Wide), Interfaces.C.double (High));
   end Place;

   procedure Show (Visible : Boolean) is
   begin
      WL_Set_Hidden (Flag (not Visible));
   end Show;

   procedure Load (URL : String) is
   begin
      WL_Load (Interfaces.C.To_C (URL));
   end Load;

   procedure Focus (Page : Boolean) is
   begin
      WL_Focus (Flag (Page));
   end Focus;

   function Has_Focus return Boolean
   is (WL_Has_Focus /= 0);

   procedure Keep (Letter : Character; Number : Positive) is
   begin
      WL_Keep (Interfaces.C.int (Character'Pos (Letter)), Interfaces.C.int (Number));
   end Keep;

   function Shortcut return Natural
   is (Natural (WL_Shortcut));

   procedure Go_Back is
   begin
      WL_Back;
   end Go_Back;

   procedure Go_Forward is
   begin
      WL_Forward;
   end Go_Forward;

   procedure Reload is
   begin
      WL_Reload;
   end Reload;

   function Can_Go_Back return Boolean
   is (WL_Can_Back /= 0);

   function Can_Go_Forward return Boolean
   is (WL_Can_Forward /= 0);

   function Loading return Boolean
   is (WL_Loading /= 0);

   function Load_Progress return Float
   is (Float'Min (1.0, Float'Max (0.0, Float (WL_Progress) / 1000.0)));

   Text_Capacity : constant := 4096;
   --  Bytes of a title or address that are kept: what the page says is cut short.

   function Title return String is
      Buffer : Interfaces.C.char_array (0 .. Text_Capacity);
      Length : constant Interfaces.C.int := WL_Title (Buffer, Text_Capacity + 1);
   begin
      return Interfaces.C.To_Ada (Buffer (0 .. Interfaces.C.size_t (Length)));
   end Title;

   function Address return String is
      Buffer : Interfaces.C.char_array (0 .. Text_Capacity);
      Length : constant Interfaces.C.int := WL_URL (Buffer, Text_Capacity + 1);
   begin
      return Interfaces.C.To_Ada (Buffer (0 .. Interfaces.C.size_t (Length)));
   end Address;

end Webshot.Live;
