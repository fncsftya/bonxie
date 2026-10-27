with Ada.Unchecked_Conversion;

package body Items.Readers.Callbacks is

   type Context_Access is access all Context;

   function To_Context is new Ada.Unchecked_Conversion (System.Address, Context_Access);
   function To_Handler is new Ada.Unchecked_Conversion (System.Address, Handler);
   function To_Address is new Ada.Unchecked_Conversion (Handler, System.Address);

   procedure Run (Self, Proc : System.Address; Which : Natural; Action : Actions);
   --  What a reader calls: Proc, with the Self that went with it.

   procedure Run (Self, Proc : System.Address; Which : Natural; Action : Actions) is
   begin
      To_Handler (Proc) (To_Context (Self).all, Which, Action);
   end Run;

   procedure On (Item : in out Reader; Which : Natural; Self : not null access Context; Do_This : not null Handler) is
   begin
      Item.Said := Run'Unrestricted_Access;
      Item.Said_Self := Self.all'Address;
      Item.Said_Proc := To_Address (Do_This);
      Item.Said_Which := Which;
   end On;

end Items.Readers.Callbacks;
