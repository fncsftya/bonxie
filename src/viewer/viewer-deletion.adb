with UI.Widgets;
with Viewer.Recent;
with Viewer.Writing;

package body Viewer.Deletion is

   package Widgets renames UI.Widgets;
   package Labels renames UI.Widgets.Labels;

   use type Items.Kinds;

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

   procedure Confirm_Node (Item : in out Session; Node : Tree_Entry) is
      Name : constant String :=
        (if Node.Kind = Directory_Node
         then Projects.Titles.To_String
                (Item.Dirs.Directories (Node.Dir).Title)
         else Projects.Titles.To_String
                (Items.Windows.Details (Item.Windows (Node.Doc)).Title));
   begin
      Item.Deleting_Node := Node;
      Labels.Set_Text
        (Item.Dialog_Title,
         (if Node.Kind = Directory_Node then "Delete folder"
          elsif Items.Windows.Details (Item.Windows (Node.Doc)).Kind
                = Items.Source
          then "Delete source"
          else "Delete document"));
      Labels.Set_Text (Item.Confirm_Message, Asked (Name));
      Labels.Set_Text
        (Item.Confirm_Note,
         (if Node.Kind = Directory_Node then "Its documents are kept."
          else "This cannot be undone."));
      Widgets.Set_Visible (Item.Overlay, True);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Confirm_Node;

   procedure Close (Item : in out Session) is
   begin
      Item.Deleting := 0;
      Item.Deleting_Node := (others => <>);
      Labels.Set_Text (Item.Dialog_Title, "Delete project");
      Labels.Set_Text (Item.Confirm_Note, "This cannot be undone.");
      Widgets.Set_Visible (Item.Overlay, False);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Close;

   procedure Delete_Confirmed (Item : in out Session) is
      Key  : constant Projects.Id := Item.Deleting;
      Node : constant Tree_Entry := Item.Deleting_Node;
   begin
      Close (Item);
      if Node.Kind /= Overview_Node then
         Writing.Delete_Node (Item, Node);
      else
         Projects.Delete (Item.Store, Key);
         Recent.Refresh (Item);
      end if;
      Widgets.Layout (Item.Widgets, Item.Target);
   end Delete_Confirmed;

end Viewer.Deletion;
