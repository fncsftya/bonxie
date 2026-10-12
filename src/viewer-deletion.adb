with UI.Widgets;
with Viewer.Recent;

package body Viewer.Deletion is

   package Widgets renames UI.Widgets;
   package Labels renames UI.Widgets.Labels;

   procedure Confirm (Item : in out Session; Row : Positive) is
      Name : constant String :=
        Projects.Titles.To_String (Item.Listed.Items (Row).Title);
   begin
      Recent.Cancel_Edit (Item);
      Item.Deleting := Item.Listed.Items (Row).Key;
      Labels.Set_Text
        (Item.Confirm_Name,
         Name (Name'First ..
               Name'First - 1
               + Natural'Min (Name'Length, Labels.Text_Capacity)));
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
