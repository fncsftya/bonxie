with Icon_Set;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Viewer.Style;

package body Viewer.Build.Dialogs is

   package Widgets renames Pomarine.Widgets;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Build_Dialog_Bar
     (Bar   : in out Panels.Panel;
      Named : in out Labels.Label;
      Close : in out Buttons.Button;
      Name  : String);
   --  Style the dark bar across the top of a dialog, as a window's: its
   --  title, white, and a small button to close it, at the right.

   procedure Build_Dialog_Bar
     (Bar   : in out Panels.Panel;
      Named : in out Labels.Label;
      Close : in out Buttons.Button;
      Name  : String) is
   begin
      Panels.Set_Fill (Bar, Toolbar);
      Set_Layout
        (Bar, Flow => Row, Align => Center, Height => Dialog_Bar_Height, Shrink => 0.0,
         Padding => (Left | Right => Dialog_Bar_Pad, others => <>));
      Labels.Set_Text (Named, Name);
      Labels.Set_Style (Named, Pomarine.Line_Texts.Strong);
      Labels.Set_Ink (Named, Themes.Bar_Ink);
      Set_Layout (Named, Grow => 1.0, Width => 0.0, Height => Dialog_Bar_Height);
      Buttons.Set_Label (Close, "Close");
      Buttons.Set_Icon (Close, Pomarine.Icons.Close);
      Buttons.Set_Icon_Size (Close, Dialog_Close_Icon);
      Set_Layout (Close, Width => Dialog_Close_Size, Height => Dialog_Close_Size, Shrink => 0.0);
   end Build_Dialog_Bar;

   procedure Build_Border (Border : in out Panels.Panel);
   --  Style the outline round a dialog.

   procedure Build_Border (Border : in out Panels.Panel) is
   begin
      Panels.Set_Fill (Border, Themes.Border);
      Panels.Set_Radius (Border, Themes.Large_Radius, Framed => True);
      Set_Layout (Border, Flow => Column, Outlined => True);
   end Build_Border;

   procedure Build_Modal (Item : in out Session) is
      Ask : Confirm_Parts renames Item.Confirm;
   begin
      Widgets.Add (Item.Root.Window_Panel, Ask.Overlay);
      Widgets.Add (Ask.Overlay, Ask.Dialog_Border);
      Widgets.Add (Ask.Dialog_Border, Ask.Dialog_Bar);
      Widgets.Add (Ask.Dialog_Bar, Ask.Dialog_Title, Ask.Dialog_Close);
      Widgets.Add (Ask.Dialog_Border, Ask.Dialog);
      Widgets.Add (Ask.Dialog, Ask.Confirm_Message, Ask.Confirm_Note);
      Widgets.Add (Ask.Dialog_Border, Ask.Dialog_Rule, Ask.Confirm_Buttons);
      Widgets.Add (Ask.Confirm_Buttons, Ask.Confirm_Cancel, Ask.Confirm_Delete);

      Panels.Set_Fill (Ask.Overlay, Themes.Scrim);
      Build_Border (Ask.Dialog_Border);
      Build_Dialog_Bar (Ask.Dialog_Bar, Ask.Dialog_Title, Ask.Dialog_Close, "Delete project");
      Panels.Set_Fill (Ask.Dialog, Paper);
      Labels.Set_Text (Ask.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Ask.Confirm_Cancel, "Cancel");
      Buttons.Set_Label (Ask.Confirm_Delete, "Delete");
      Buttons.Set_Icon (Ask.Confirm_Delete, Icon_Set.Delete);
      Buttons.Set_Icon_Size (Ask.Confirm_Delete, Mic_Icon_Size);
      Buttons.Set_Captioned (Ask.Confirm_Delete, True);
      Buttons.Set_Kind (Ask.Confirm_Delete, Buttons.Danger);
      Panels.Set_Fill (Ask.Dialog_Rule, Themes.Border);
      Set_Layout (Ask.Dialog_Rule, Height => Hairline);
      Panels.Set_Fill (Ask.Confirm_Buttons, Themes.Tint);

      --  Not in the layout of the screens: over them, all of the window,
      --  with the dialog in the middle.
      Set_Layout
        (Ask.Overlay, Place => Absolute, Position => (others => 0.0), Flow => Column,
         Spread => Center, Align => Center);

      Set_Layout (Ask.Dialog_Border, Width => Dialog_Width);
      Set_Layout (Ask.Dialog, Flow => Column, Padding => (others => Dialog_Pad));
      Set_Layout (Ask.Confirm_Message, Height => Dialog_Line);
      Set_Layout (Ask.Confirm_Note, Height => Dialog_Line);

      Set_Layout
        (Ask.Confirm_Buttons, Flow => Row, Spread => Finish,
         Padding => (others => Dialog_Foot_Pad), Gap => Row_Gap);
      Set_Layout (Ask.Confirm_Cancel, Height => Dialog_Button_Height, Width => Dialog_Button_Width);
      Set_Layout (Ask.Confirm_Delete, Height => Dialog_Button_Height, Width => Dialog_Button_Width);
   end Build_Modal;

   procedure Build_List (Item : in out Session) is
      Items_View : List_Parts renames Item.Item_List;
   begin
      Widgets.Add (Item.Root.Window_Panel, Items_View.List_Overlay);
      Widgets.Add (Items_View.List_Overlay, Items_View.List_Border);
      Widgets.Add (Items_View.List_Border, Items_View.List_Head);
      Widgets.Add (Items_View.List_Head, Items_View.List_Heading, Items_View.List_Close);
      Widgets.Add (Items_View.List_Border, Items_View.List_Dialog);
      Widgets.Add (Items_View.List_Dialog, Items_View.List_View, Items_View.List_None);
      Items_View.List_Rows.Owner := Item'Unchecked_Access;
      Pomarine.Widgets.Lists.Set_Model
        (Items_View.List_View, Items_View.List_Rows'Unchecked_Access);
      Pomarine.Widgets.Lists.Set_Row_Height (Items_View.List_View, Row_Height);

      Panels.Set_Fill (Items_View.List_Overlay, Themes.Scrim);
      Build_Border (Items_View.List_Border);
      Build_Dialog_Bar
        (Items_View.List_Head, Items_View.List_Heading, Items_View.List_Close, "Items");
      Panels.Set_Fill (Items_View.List_Dialog, Paper);
      Labels.Set_Text (Items_View.List_None, No_Items);

      Set_Layout
        (Items_View.List_Overlay, Place => Absolute, Position => (others => 0.0),
         Flow => Column, Spread => Center, Align => Center);

      Set_Layout (Items_View.List_Border, Width => List_Width, Height => List_Height);
      Set_Layout
        (Items_View.List_Dialog, Flow => Column, Grow => 1.0, Height => 0.0,
         Padding => (others => Dialog_Pad));

      --  The list takes what the title bar and the border leave.
      Set_Layout (Items_View.List_View, Grow => 1.0, Height => 0.0);
      Set_Layout (Items_View.List_None, Height => Title_Height);
   end Build_List;

end Viewer.Build.Dialogs;
