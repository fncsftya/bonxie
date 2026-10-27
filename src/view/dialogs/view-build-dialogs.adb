with Confirm_VM;
with Item_List_VM;
with Nav_UI;
with Nav_VM;
with Icon_Set;
with Pomarine.UI.Contexts;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with View.Style;

package body View.Build.Dialogs is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Themes renames Pomarine.Themes;

   package UI renames Pomarine.UI;

   use Style;
   use Pomarine.Widgets.Layouts;

   function Bar (Heading : UI.Label_Handle; Close : UI.Button_Handle) return UI.Layout
   is (UI.Styled
         (UI.Row
            ([UI.Place (Heading, Grow => 1.0, Width => 0.0, Height => Dialog_Bar_Height, Exact => True),
              UI.Place (Close, Width => Dialog_Close_Size, Height => Dialog_Close_Size, Shrink => 0.0, Exact => True)],
             Appearance => (Fill => Toolbar, others => <>)),
          (Flow    => Row,
           Align   => Center,
           Height  => Dialog_Bar_Height,
           Shrink  => 0.0,
           Padding => (Left | Right => Dialog_Bar_Pad, others => <>),
           others  => <>)));
   --  The dark bar across the top of a dialog, as a window's: its title, white, and a small button to close
   --  it, at the right.

   function Closer return Buttons.Settings
   is (Buttons.Looks
         ("Close",
          Icon        => Pomarine.Icons.Shown (Pomarine.Icons.Close),
          Icon_Points => Dialog_Close_Icon,
          Focusable   => True));

   function Boxed
     (Inside : UI.Layout_Array; Width : UI.Layouts.Length; Height : UI.Layouts.Length := UI.Unset) return UI.Layout
   is (UI.Styled
         (UI.Column
            (Inside,
             Appearance => (Fill => Themes.Border, Radius => Themes.Large_Radius, Framed => True, others => <>)),
          (Flow => Column, Outlined => On, Width => Width, Height => Height, others => <>)));
   --  The outline round a dialog, of this size.

   function Over_All (Dialog : UI.Layout) return UI.Layout
   is (UI.Styled
         (UI.Column ([Dialog], Appearance => (Fill => Themes.Scrim, others => <>)),
          (Place    => Absolute,
           Position => (others => 0.0),
           Flow     => Column,
           Spread   => Center,
           Align    => Center,
           others   => <>)));
   --  Not in the layout of the screens: over them, all of the window, with the dialog in the middle.

   --  The dialog that asks before something is deleted: its controls are the view's (Pomarine.UI), bound to
   --  the Confirm_VM, which has what it says and what it is about.

   package Confirm_UI is new Pomarine.UI.Contexts (Confirm_VM.Commands, Confirm_VM.View_Model);

   procedure Set_Documents (Item : in out Confirm_VM.View_Model; To : Boolean);
   procedure Set_Documents (Item : in out Confirm_VM.View_Model; To : Boolean) is
   begin
      --  The box is the person's to tick, where it is offered.
      if Confirm_VM.Offers_Documents (Item) then
         Confirm_VM.Set_Delete_Documents (Item, To);
      end if;
   end Set_Documents;

   Title_Text     : constant Confirm_UI.Text_Property := Confirm_UI.Showing (Confirm_VM.Title'Access);
   Message_Text   : constant Confirm_UI.Text_Property := Confirm_UI.Showing (Confirm_VM.Message'Access);
   Note_Text      : constant Confirm_UI.Text_Property := Confirm_UI.Showing (Confirm_VM.Note'Access);
   Documents_Flag : constant Confirm_UI.Flag_Property :=
     Confirm_UI.Editing (Confirm_VM.Delete_Documents'Access, Set_Documents'Access);
   Offers_Flag    : constant Confirm_UI.Flag_Property := Confirm_UI.Showing (Confirm_VM.Offers_Documents'Access);

   procedure Build_Modal (Item : in out Session) is
   begin
      Open_Screen (Item, Confirm_Region);
      declare
         Form  : UI.View renames Screen_Of (Item, Confirm_Region).all;
         Bound : constant Confirm_UI.Context'Class := Confirm_UI.Bind (Form, Item.Dialog_Model.Model);

         Heading : constant UI.Label_Handle :=
           Bound.Label (Title_Text, Style => Pomarine.Line_Texts.Strong, Ink => Themes.Bar_Ink);
         Close   : constant UI.Button_Handle := Bound.Button (Closer, Confirm_VM.Cancel);
         Message : constant UI.Label_Handle := Bound.Label (Message_Text);
         Note    : constant UI.Label_Handle := Bound.Label (Note_Text);
         Offered : constant UI.Check_Handle := Bound.Check ("Delete documents too", Documents_Flag);
         Cancel  : constant UI.Button_Handle :=
           Bound.Button (Buttons.Looks ("Cancel", Focusable => True), Confirm_VM.Cancel);
         Delete  : constant UI.Button_Handle :=
           Bound.Button
             (Buttons.Looks
                ("Delete",
                 Buttons.Danger,
                 Icon        => Pomarine.Icons.Shown (Icon_Set.Delete),
                 Icon_Points => Mic_Icon_Size,
                 Captioned   => True,
                 Focusable   => True),
              Confirm_VM.Confirm);

         Body_Layout : constant UI.Layout :=
           UI.Styled
             (UI.Column
                ([UI.Place (Message, Height => Dialog_Line, Exact => True),
                  UI.Place (Note, Height => Dialog_Line, Exact => True),
                  UI.Called (UI.Place (Offered, Height => Dialog_Line, Exact => True), Delete_Documents_Check)],
                 Appearance => (Fill => Paper, others => <>)),
              (Flow => Column, Padding => (others => Dialog_Pad), others => <>));

         Rule : constant UI.Layout :=
           UI.Styled (UI.Spacer (Form, (Fill => Themes.Border, others => <>)), (Height => Hairline, others => <>));

         Foot : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([UI.Called
                    (UI.Place (Cancel, Height => Dialog_Button_Height, Width => Dialog_Button_Width, Exact => True),
                     Confirm_Cancel_Button),
                  UI.Called
                    (UI.Place (Delete, Height => Dialog_Button_Height, Width => Dialog_Button_Width, Exact => True),
                     Confirm_Delete_Button)],
                 Appearance => (Fill => Themes.Tint, others => <>)),
              (Flow => Row, Spread => Finish, Padding => (others => Dialog_Foot_Pad), Gap => Row_Gap, others => <>));

         Border  : constant UI.Layout :=
           UI.Called (Boxed ([Bar (Heading, Close), Body_Layout, Rule, Foot], Dialog_Width), Confirm_Border);
         Overlay : constant UI.Layout := UI.Called (Over_All (Border), Confirm_Overlay);
      begin
         Bound.Show_When (UI.Any (Offered), Offers_Flag);
         UI.Mount_Into (Form, Item.Root.Window_Panel, Overlay);
      end;
   end Build_Modal;

   --  The list of items: a dialog over the project screen. Its closing is the navigation's; what it says
   --  when there are no items is the list's.

   package Items_UI is new Pomarine.UI.Contexts (Item_List_VM.Commands, Item_List_VM.View_Model);

   function Is_Empty (Item : Item_List_VM.View_Model) return Boolean
   is (Item_List_VM.Count (Item) = 0);
   function Is_Filled (Item : Item_List_VM.View_Model) return Boolean
   is (Item_List_VM.Count (Item) > 0);

   Empty_Flag  : constant Items_UI.Flag_Property := Items_UI.Showing (Is_Empty'Access);
   Filled_Flag : constant Items_UI.Flag_Property := Items_UI.Showing (Is_Filled'Access);

   procedure Build_List (Item : in out Session) is
      Parts : List_Parts renames Item.Item_List;
   begin
      Open_Screen (Item, List_Region);
      declare
         Form  : UI.View renames Screen_Of (Item, List_Region).all;
         Navs  : constant Nav_UI.Context'Class := Nav_UI.Bind (Form, Item.Nav_Model.Model);
         Bound : constant Items_UI.Context'Class := Items_UI.Bind (Form, Item.Item_List.Model);

         Heading : constant UI.Label_Handle :=
           Bound.Label ("Items", Style => Pomarine.Line_Texts.Strong, Ink => Themes.Bar_Ink);
         Close   : constant UI.Button_Handle := Navs.Button (Closer, Nav_VM.Close_List);
         Rows    : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.List_View);
         None    : constant UI.Label_Handle := Bound.Label (No_Items);

         Dialog : constant UI.Layout :=
           UI.Styled
             (UI.Column
                ([UI.Place (Rows, Grow => 1.0, Height => 0.0, Exact => True),
                  UI.Place (None, Height => Title_Height, Exact => True)],
                 Appearance => (Fill => Paper, others => <>)),
              (Flow => Column, Grow => 1.0, Height => 0.0, Padding => (others => Dialog_Pad), others => <>));

         Border  : constant UI.Layout :=
           UI.Called (Boxed ([Bar (Heading, Close), Dialog], List_Width, List_Height), List_Border);
         Overlay : constant UI.Layout := UI.Called (Over_All (Border), List_Overlay);
      begin
         Bound.On_Event (Rows, Widgets.Click, Item_List_VM.Reveal, Index_From_Event => True);
         Bound.On_Event (Rows, Widgets.Submit, Item_List_VM.Reveal, Index_From_Event => True);
         Bound.On_List_Actions (Rows, [Item_List_VM.Toggle_Shown, Item_List_VM.Remove]);
         Bound.Show_When (UI.Any (Rows), Filled_Flag);
         Bound.Show_When (UI.Any (None), Empty_Flag);
         Parts.List_Rows.Owner := Item'Unchecked_Access;
         Pomarine.Widgets.Lists.Set_Model (Parts.List_View, Parts.List_Rows'Unchecked_Access);
         Pomarine.Widgets.Lists.Set_Row_Height (Parts.List_View, Row_Height);
         UI.Mount_Into (Form, Item.Root.Window_Panel, Overlay);
      end;
   --  The list takes what the title bar and the border leave.
   end Build_List;

end View.Build.Dialogs;
