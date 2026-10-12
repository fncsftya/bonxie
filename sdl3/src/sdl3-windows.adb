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

   overriding procedure Finalize (Item : in out Window) is
   begin
      if Item.Handle /= System.Null_Address then
         Thin.Destroy_Window (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Windows;
