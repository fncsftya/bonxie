with SDL3.Clipboard;

package body UI.Clipboards is

   overriding function Text (Item : System_Clipboard) return String is
     (SDL3.Clipboard.Text);

   overriding procedure Set_Text
     (Item : in out System_Clipboard; Value : String) is
   begin
      SDL3.Clipboard.Set_Text (Value);
   end Set_Text;

   overriding function Text (Item : Memory_Clipboard) return String is
     (Ada.Strings.Unbounded.To_String (Item.Value));

   overriding procedure Set_Text
     (Item : in out Memory_Clipboard; Value : String) is
   begin
      Item.Value := Ada.Strings.Unbounded.To_Unbounded_String (Value);
   end Set_Text;

end UI.Clipboards;
