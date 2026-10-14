private with Ada.Strings.Unbounded;

--  Where cut and copied text goes, and pasted text comes from.
package UI.Clipboards is

   type Clipboard is limited interface;

   function Text (Item : Clipboard) return String is abstract;
   --  What is on it, in UTF-8; "" if nothing.

   procedure Set_Text (Item : in out Clipboard; Value : String) is abstract;
   --  Put Value, in UTF-8, on it.

   type System_Clipboard is limited new Clipboard with null record;
   --  The system's, shared with other programs. SDL must be initialized.

   overriding function Text (Item : System_Clipboard) return String;
   overriding procedure Set_Text
     (Item : in out System_Clipboard; Value : String);

   type Memory_Clipboard is limited new Clipboard with private;
   --  One of its own, as for testing.

   overriding function Text (Item : Memory_Clipboard) return String;
   overriding procedure Set_Text
     (Item : in out Memory_Clipboard; Value : String);

private

   type Memory_Clipboard is limited new Clipboard with record
      Value : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end UI.Clipboards;
