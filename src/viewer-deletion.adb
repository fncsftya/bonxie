with UI.Widgets;
with Viewer.Recent;

package body Viewer.Deletion is

   package Widgets renames UI.Widgets;
   package Labels renames UI.Widgets.Labels;

   Open_Quote  : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9C#)];
   Close_Quote : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9D#)];
   --  In UTF-8.

   function Asked (Name : String) return String;
   --  Delete "Name"?, in curved quotes, with as much of the name as fits a
   --  label, cut where a character begins.

   function Asked (Name : String) return String is
      Before : constant String := "Delete " & Open_Quote;
      After  : constant String := Close_Quote & "?";
      Room   : constant Natural :=
        Labels.Text_Capacity - Before'Length - After'Length;
      Last   : Natural := Name'First - 1 + Natural'Min (Name'Length, Room);
   begin
      while Last >= Name'First and then Last < Name'Last
        and then Character'Pos (Name (Last + 1)) in 16#80# .. 16#BF#
      loop
         Last := Last - 1;
      end loop;
      return Before & Name (Name'First .. Last) & After;
   end Asked;

   procedure Confirm (Item : in out Session; Row : Positive) is
      Name : constant String :=
        Projects.Titles.To_String (Item.Listed.Items (Row).Title);
   begin
      Recent.Cancel_Edit (Item);
      Item.Deleting := Item.Listed.Items (Row).Key;
      Labels.Set_Text (Item.Confirm_Message, Asked (Name));
      Widgets.Set_Visible (Item.Overlay, True);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Confirm;

   procedure Close (Item : in out Session) is
   begin
      Item.Deleting := 0;
      Widgets.Set_Visible (Item.Overlay, False);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Close;

   procedure Delete_Confirmed (Item : in out Session) is
      Key : constant Projects.Id := Item.Deleting;
   begin
      Close (Item);
      Projects.Delete (Item.Store, Key);
      Recent.Refresh (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Delete_Confirmed;

end Viewer.Deletion;
