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

   overriding procedure Finalize (Item : in out Window) is
   begin
      if Item.Handle /= System.Null_Address then
         Thin.Destroy_Window (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Windows;
