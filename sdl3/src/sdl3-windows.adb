with Interfaces.C.Strings;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Windows is

   use type System.Address;

   procedure Create
     (Item      : in out Window;
      Title     : String;
      Width     : Positive;
      Height    : Positive;
      Resizable : Boolean := False;
      High_Density : Boolean := False;
      Hidden    : Boolean := False)
   is
      use Interfaces.C;
      C_Title : Strings.chars_ptr := Strings.New_String (Title);
      use type Thin.Window_Flags;
      Flags   : constant Thin.Window_Flags :=
        (if Resizable then Thin.Window_Resizable else 0)
        + (if High_Density then Thin.Window_High_Pixel_Density else 0)
        + (if Hidden then Thin.Window_Hidden else 0);
   begin
      Finalize (Item);
      Item.Handle :=
        Thin.Create_Window (C_Title, int (Width), int (Height), Flags);
      Strings.Free (C_Title);
      if Item.Handle = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateWindow");
      end if;
   end Create;

   function Is_Open (Item : Window) return Boolean is
     (Item.Handle /= System.Null_Address);

   function Pixel_Density (Item : Window) return Float is
      Found : constant Float :=
        Float (Thin.Get_Window_Pixel_Density (Item.Handle));
   begin
      --  0.0 if SDL cannot say.
      return Float'Max (1.0, Found);
   end Pixel_Density;

   procedure Start_Text_Input (Item : Window) is
   begin
      Errors.Check
        (Thin.Start_Text_Input (Item.Handle), "SDL_StartTextInput");
   end Start_Text_Input;

   procedure Set_Text_Input_Area
     (Item : Window; X, Y, Width, Height : Integer)
   is
      use Interfaces.C;
      Rect : aliased constant Thin.IRect :=
        (X => int (X), Y => int (Y), W => int (Width), H => int (Height));
   begin
      Errors.Check
        (Thin.Set_Text_Input_Area (Item.Handle, Rect'Address, 0),
         "SDL_SetTextInputArea");
   end Set_Text_Input_Area;

   procedure Set_Title (Item : Window; Title : String) is
      C_Title : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Title);
      Done    : constant Interfaces.C.C_bool :=
        Thin.Set_Window_Title (Item.Handle, C_Title);
   begin
      Interfaces.C.Strings.Free (C_Title);
      Errors.Check (Done, "SDL_SetWindowTitle");
   end Set_Title;

   procedure Extend_Into_Title_Bar (Item : Window) is
      use Interfaces.C;
      use type Interfaces.Unsigned_64;
      Full_Size_Content : constant := 2 ** 15;  --  NSWindowStyleMask...
      Title_Hidden      : constant := 1;        --  NSWindowTitleHidden
      Cocoa_Window : constant System.Address :=
        Thin.Get_Pointer_Property
          (Thin.Get_Window_Properties (Item.Handle),
           To_C ("SDL.window.cocoa.window"), System.Null_Address);
   begin
      if Cocoa_Window = System.Null_Address then
         return;  --  not on macOS
      end if;
      Thin.Send_Unsigned
        (Cocoa_Window, Thin.Selector (To_C ("setStyleMask:")),
         Thin.Send_Flag (Cocoa_Window, Thin.Selector (To_C ("styleMask")))
         or Full_Size_Content);
      Thin.Send_Unsigned
        (Cocoa_Window, Thin.Selector (To_C ("setTitlebarAppearsTransparent:")),
         1);
      Thin.Send_Unsigned
        (Cocoa_Window, Thin.Selector (To_C ("setTitleVisibility:")),
         Title_Hidden);
   end Extend_Into_Title_Bar;

   procedure Set_Size (Item : Window; Width, Height : Positive) is
      use Interfaces.C;
   begin
      Errors.Check
        (Thin.Set_Window_Size (Item.Handle, int (Width), int (Height)),
         "SDL_SetWindowSize");
      --  It may be done by the system a while later.
      if not Boolean (Thin.Sync_Window (Item.Handle)) then
         null;  --  not all can say; the caller sees the size it gets
      end if;
   end Set_Size;

   procedure Get_Geometry
     (Item : Window; X, Y, Width, Height : out Integer; Found : out Boolean)
   is
      use Interfaces.C;
      PX, PY, W, H : int := 0;
   begin
      Found :=
        Boolean (Thin.Get_Window_Position (Item.Handle, PX, PY))
        and then Boolean (Thin.Get_Window_Size (Item.Handle, W, H))
        and then W > 0 and then H > 0;
      X := Integer (PX);
      Y := Integer (PY);
      Width := Integer (W);
      Height := Integer (H);
   end Get_Geometry;

   procedure Set_Position (Item : Window; X, Y : Integer) is
      use Interfaces.C;
   begin
      Errors.Check
        (Thin.Set_Window_Position (Item.Handle, int (X), int (Y)),
         "SDL_SetWindowPosition");
   end Set_Position;

   overriding procedure Finalize (Item : in out Window) is
   begin
      if Item.Handle /= System.Null_Address then
         Thin.Destroy_Window (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Windows;
