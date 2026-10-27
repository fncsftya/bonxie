with Ada.Unchecked_Deallocation;

package body View_Parts.Common is

   procedure Free is new Ada.Unchecked_Deallocation (Pomarine.UI.View, Screen_Access);

   procedure Open (Holder : in out Screen_Holder; Tree : not null access Pomarine.Widgets.Tree; Kind : Form_Kinds) is
   begin
      Holder.Screen := new Pomarine.UI.View (Tree);
      Pomarine.UI.Use_Tags_From (Holder.Screen.all, Tag_Base (Kind));
   end Open;

   overriding
   procedure Finalize (Item : in out Screen_Holder) is
   begin
      Free (Item.Screen);
   end Finalize;

end View_Parts.Common;
