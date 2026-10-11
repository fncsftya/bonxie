--  The system's clipboard, for text. SDL must be initialized.
package SDL3.Clipboard is

   function Text return String;
   --  What is on it, in UTF-8; "" if no text.

   procedure Set_Text (Value : String);
   --  Put Value, in UTF-8, on it.

end SDL3.Clipboard;
