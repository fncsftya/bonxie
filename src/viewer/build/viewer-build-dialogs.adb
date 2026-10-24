with Icon_Set;
with Pomarine.Widgets.Checks;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Viewer.Style;

package body Viewer.Build.Dialogs is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Add_Dialog_Bar
     (Parent : in out Widgets.Widget'Class;
      Bar    : in out Panels.Panel;
      Named  : in out Labels.Label;
      Close  : in out Buttons.Button;
      Name   : String);
   --  Add the dark bar across the top of a dialog, as a window's, to Parent: its
   --  title, white, and a small button to close it, at the right.

   procedure Add_Dialog_Bar
     (Parent : in out Widgets.Widget'Class;
      Bar    : in out Panels.Panel;
      Named  : in out Labels.Label;
      Close  : in out Buttons.Button;
      Name   : String) is
   begin
      Layouts.Add
        (Parent, Bar,
         (Flow => Row, Align => Center, Height => Dialog_Bar_Height, Shrink => 0.0,
          Padding => (Left | Right => Dialog_Bar_Pad, others => <>), others => <>));
      Panels.Set_Fill (Bar, Toolbar);
      Layouts.Add (Bar, Named, (Grow => 1.0, Width => 0.0, Height => Dialog_Bar_Height, others => <>));
      Labels.Set_Text (Named, Name);
      Labels.Set_Style (Named, Pomarine.Line_Texts.Strong);
      Labels.Set_Ink (Named, Themes.Bar_Ink);
      Buttons.Add
        (Bar, Close,
         Buttons.Looks
           ("Close",
            Icon => Pomarine.Icons.Shown (Pomarine.Icons.Close),
            Icon_Points => Dialog_Close_Icon),
         (Width => Dialog_Close_Size, Height => Dialog_Close_Size, Shrink => 0.0, others => <>));
   end Add_Dialog_Bar;

   procedure Add_Border
     (Parent : in out Widgets.Widget'Class;
      Border : in out Panels.Panel;
      Width  : Float;
      Height : Float := Unset);
   --  Add the outline round a dialog to Parent, of this size.

   procedure Add_Border
     (Parent : in out Widgets.Widget'Class;
      Border : in out Panels.Panel;
      Width  : Float;
      Height : Float := Unset) is
   begin
      Layouts.Add (Parent, Border, (Flow => Column, Outlined => True, Width => Width, Height => Height, others => <>));
      Panels.Set_Fill (Border, Themes.Border);
      Panels.Set_Radius (Border, Themes.Large_Radius, Framed => True);
   end Add_Border;

   procedure Build_Modal (Item : in out Session) is
      Ask : Confirm_Parts renames Item.Confirm;
   begin
      Layouts.Add (Item.Root.Window_Panel, Ask.Overlay,
                   (Place => Absolute, Position => (others => 0.0), Flow => Column, Spread => Center, Align => Center,
                    others => <>));
      Add_Border (Ask.Overlay, Ask.Dialog_Border, Width => Dialog_Width);
      Add_Dialog_Bar (Ask.Dialog_Border, Ask.Dialog_Bar, Ask.Dialog_Title, Ask.Dialog_Close, "Delete project");
      Layouts.Add (Ask.Dialog_Border, Ask.Dialog, (Flow => Column, Padding => (others => Dialog_Pad), others => <>));
      Layouts.Add (Ask.Dialog, Ask.Confirm_Message, (Height => Dialog_Line, others => <>));
      Layouts.Add (Ask.Dialog, Ask.Confirm_Note, (Height => Dialog_Line, others => <>));
      Layouts.Add (Ask.Dialog, Ask.Delete_Documents, (Height => Dialog_Line, others => <>));
      Pomarine.Widgets.Checks.Set_Label (Ask.Delete_Documents, "Delete documents too");
      Pomarine.Widgets.Checks.Set_Focusable (Ask.Delete_Documents, True);
      Widgets.Set_Visible (Ask.Delete_Documents, False);
      Layouts.Add (Ask.Dialog_Border, Ask.Dialog_Rule, (Height => Hairline, others => <>));
      Layouts.Add (Ask.Dialog_Border, Ask.Confirm_Buttons,
                   (Flow => Row, Spread => Finish, Padding => (others => Dialog_Foot_Pad), Gap => Row_Gap,
                    others => <>));
      Layouts.Add (Ask.Confirm_Buttons, Ask.Confirm_Cancel,
                   (Height => Dialog_Button_Height, Width => Dialog_Button_Width, others => <>));
      Buttons.Add (Ask.Confirm_Buttons, Ask.Confirm_Delete,
                   Buttons.Looks ("Delete", Buttons.Danger, Icon => Pomarine.Icons.Shown (Icon_Set.Delete),
                                  Icon_Points => Mic_Icon_Size, Captioned => True),
                   (Height => Dialog_Button_Height, Width => Dialog_Button_Width, others => <>));

      Panels.Set_Fill (Ask.Overlay, Themes.Scrim);
      Panels.Set_Fill (Ask.Dialog, Paper);
      Labels.Set_Text (Ask.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Ask.Confirm_Cancel, "Cancel");
      Panels.Set_Fill (Ask.Dialog_Rule, Themes.Border);
      Panels.Set_Fill (Ask.Confirm_Buttons, Themes.Tint);

      --  Not in the layout of the screens: over them, all of the window,
      --  with the dialog in the middle.
   end Build_Modal;

   procedure Build_List (Item : in out Session) is
      Items_View : List_Parts renames Item.Item_List;
   begin
      Layouts.Add (Item.Root.Window_Panel, Items_View.List_Overlay,
                   (Place => Absolute, Position => (others => 0.0), Flow => Column, Spread => Center, Align => Center,
                    others => <>));
      Add_Border (Items_View.List_Overlay, Items_View.List_Border, Width => List_Width, Height => List_Height);
      Add_Dialog_Bar
        (Items_View.List_Border, Items_View.List_Head, Items_View.List_Heading, Items_View.List_Close, "Items");
      Layouts.Add (Items_View.List_Border, Items_View.List_Dialog,
                   (Flow => Column, Grow => 1.0, Height => 0.0, Padding => (others => Dialog_Pad), others => <>));
      Layouts.Add (Items_View.List_Dialog, Items_View.List_View, (Grow => 1.0, Height => 0.0, others => <>));
      Layouts.Add (Items_View.List_Dialog, Items_View.List_None, (Height => Title_Height, others => <>));
      Items_View.List_Rows.Owner := Item'Unchecked_Access;
      Pomarine.Widgets.Lists.Set_Model
        (Items_View.List_View, Items_View.List_Rows'Unchecked_Access);
      Pomarine.Widgets.Lists.Set_Row_Height (Items_View.List_View, Row_Height);

      Panels.Set_Fill (Items_View.List_Overlay, Themes.Scrim);
      Panels.Set_Fill (Items_View.List_Dialog, Paper);
      Labels.Set_Text (Items_View.List_None, No_Items);

      --  The list takes what the title bar and the border leave.
   end Build_List;

end Viewer.Build.Dialogs;
