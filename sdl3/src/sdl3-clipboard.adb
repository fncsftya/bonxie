with Interfaces.C.Strings;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Clipboard is

   function Text return String is
      Got : constant Interfaces.C.Strings.chars_ptr :=
        Thin.Get_Clipboard_Text;
      Value : constant String := Interfaces.C.Strings.Value (Got);
   begin
      Thin.Free (Got);
      return Value;
   end Text;

   procedure Set_Text (Value : String) is
      C_Value : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Value);
      Done    : constant Interfaces.C.C_bool :=
        Thin.Set_Clipboard_Text (C_Value);
   begin
      Interfaces.C.Strings.Free (C_Value);
      Errors.Check (Done, "SDL_SetClipboardText");
   end Set_Text;

end SDL3.Clipboard;
