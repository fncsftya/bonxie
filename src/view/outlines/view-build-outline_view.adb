with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Editors;
with SDL3.Cursors;
with Pomarine.Boxes;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Outline_UI;
with Outline_VM;
with Pomarine.UI;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with View.Style;

package body View.Build.Outline_View is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Grips renames Pomarine.Widgets.Grips;
   package Editors renames Pomarine.Widgets.Editors;
   package Themes renames Pomarine.Themes;
   package UI renames Pomarine.UI;

   use Style;
   use Pomarine.Widgets.Layouts;

   --  A block, made as the sections grow: put in front of the words that say there are none.
   procedure Make_Block (Item : in out Session; Index : Positive) is
      Pane   : Outline_Parts renames Item.Outline_View;
      Block  : Section_Block renames Pane.Blocks (Index);
      Pixels : constant Float := Item.Shell.Density;
      Form   : UI.View renames Screen_Of (Item, Outline_Region).all;

      Outs : constant Outline_UI.Context'Class :=
        Outline_UI.Bind (Form, Item.Outline_Model.Model);

      --  The buttons of the block do the commands of the outline for its row.
      function Icon_Button
        (Part : in out Buttons.Button; Name : String; Icon : Pomarine.Icons.Icon; What : Outline_VM.Command;
         Of_Kind : Buttons.Kind := Buttons.Normal) return UI.Layout is
      begin
         Buttons.Configure
           (Part, Buttons.Looks (Name, Of_Kind, Icon => Pomarine.Icons.Shown (Icon), Focusable => True));
         return Outs.Borrow_Button
           (Part, What, Index, Width => Outline_Button, Height => Outline_Button, Shrink => 0.0, Exact => True);
      end Icon_Button;

      function Notes_Button return UI.Layout is
      begin
         Buttons.Configure (Block.Notes, Buttons.Looks ("Notes", Captioned => True, Focusable => True));
         return Outs.Borrow_Button
           (Block.Notes, Outline_VM.Toggle_Notes, Index, Width => Notes_Width, Height => Outline_Button,
            Shrink => 0.0, Exact => True);
      end Notes_Button;

      Name   : constant UI.Widget_Handle := Outs.Borrow_Widget (Block.Field);

      Line : constant UI.Layout :=
        UI.Styled
          (UI.Put_In
             (Form, Block.Line,
              [UI.Styled
                 (UI.Put (Form, Block.Handle),
                  (Width => Layouts.Length_Of (Outline_Handle), Height => Layouts.Length_Of (Index_Height),
                   Shrink => 0.0,
                                                others => <>)),
               Outs.Borrow_Widget
                 (Block.Swatch, Click => Outline_VM.Choose_Colour, Index => Index,
                  Width => Layouts.Length_Of (Outline_Field_Height - 2.0),
                  Height => Layouts.Length_Of (Outline_Field_Height - 2.0), Shrink => 0.0, Exact => True),
               UI.Place (Name, Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Outline_Field_Height),
                  Exact => True),
               Notes_Button,
               Icon_Button (Block.Up, "Move up", Pomarine.Icons.Chevron_Up, Outline_VM.Move_Up),
               Icon_Button (Block.Down, "Move down", Pomarine.Icons.Chevron_Down, Outline_VM.Move_Down),
               Icon_Button
                 (Block.Remove, "Delete section", Icon_Set.Delete, Outline_VM.Remove_Section, Buttons.Danger)]),
           (Shrink => 0.0, Flow => Row, Align => Center, Gap => Layouts.Length_Of (Tool_Gap * Pixels),
            Height => Layouts.Length_Of (Outline_Block_Height * Pixels), Unit => Device_Pixels, others => <>));

      Sheet : constant UI.Layout :=
        UI.Styled
          (UI.Put_In
             (Form, Block.Notes_Sheet,
              [UI.Styled (UI.Put (Form, Block.Notes_Text), (Grow => 1.0, Height => 0.0, others => <>))]),
           (Flow => Column, Height => Outline_Notes_Height, Shrink => 0.0,
            Margin => (Bottom => Layouts.Length_Of (Tool_Gap), others => <>), others => <>));

      Whole : constant UI.Layout :=
        UI.Styled
          (UI.Put_In (Form, Block.Row, [Line, Sheet]),
           (Shrink => 0.0, Flow => Column,
            Padding => (Left | Right => Layouts.Length_Of (Index_Pad * Pixels), others => <>),
            Shadowed => On, Unit => Device_Pixels, others => <>));
   begin
      Outs.On_Event (Name, Widgets.Submit, Outline_VM.End_Title);
      UI.Mount_Before (Form, Pane.None, Whole);
      Grips.Set_Fill (Block.Row, Row_Fill);
      Grips.Set_Hover_Fill (Block.Row, Row_Fill);
      Grips.Set_Border (Block.Row, Themes.Border);
      Grips.Set_Shadow (Block.Row, Side_Fill);
      Grips.Set_Wanted_Cursor (Block.Row, SDL3.Cursors.Grab);
      Editors.Set_Shared (Block.Notes_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (Block.Notes_Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
      Editors.Set_Paper (Block.Notes_Text, Paper);
      Editors.Attach (Block.Notes_Text, Block.Notes_Doc'Unchecked_Access);
      Widgets.Set_Visible (Block.Notes_Sheet, False);
      Labels.Set_Text (Block.Handle, "::");
      Labels.Set_Ink (Block.Handle, Quiet_Ink);
      Grips.Set_Wanted_Cursor (Block.Swatch, SDL3.Cursors.Pointer);
      Grips.Set_Hover_Outline (Block.Swatch, Themes.Foreground);
      Grips.Set_Focusable (Block.Swatch, True);
      Widgets.Set_Accessible_Name (Block.Swatch, "Change section colour");
      Widgets.Set_Accessible_Name (Block.Field, "Section title");
      Text_Fields.Set_Shared (Block.Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Block.Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
      Text_Fields.Attach (Block.Field, Block.Doc'Unchecked_Access);
      Widgets.Set_Visible (Block.Row, False);
   end Make_Block;

   procedure Build_Outline (Item : in out Session) is
      Pane   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);

   begin
      Open_Screen (Item, Outline_Region);
      Buttons.Configure
        (Pane.Add_Button,
         Buttons.Looks ("Add Section", Icon => Pomarine.Icons.Shown (Icon_Set.Plus), Captioned => True,
                        Focusable => True));
      Buttons.Configure (Pane.Colour_Cancel, Buttons.Looks ("Cancel", Focusable => True));
      Buttons.Configure (Pane.Colour_OK, Buttons.Looks ("OK", Buttons.Primary, Focusable => True));
      Pomarine.Widgets.Grips.Set_Wanted_Cursor
        (Pomarine.Widgets.Grips.Grip (Pane.Colour_Picker), SDL3.Cursors.Pointer);
      declare
         Form : UI.View renames Screen_Of (Item, Outline_Region).all;

         function Line (Widget : in out Widgets.Widget'Class; Box : Layouts.Style) return UI.Layout is
           (UI.Styled (UI.Put (Form, Widget), Box));

         Outs : constant Outline_UI.Context'Class :=
           Outline_UI.Bind (Form, Item.Outline_Model.Model);
         Adding : constant UI.Button_Handle := Outs.Borrow_Button (Pane.Add_Button, Outline_VM.Add_Section);
         Cancelling : constant UI.Button_Handle :=
           Outs.Borrow_Button (Pane.Colour_Cancel, Outline_VM.Cancel_Colour, Reflect => False);
         Accepting : constant UI.Button_Handle :=
           Outs.Borrow_Button (Pane.Colour_OK, Outline_VM.Accept_Colour, Reflect => False);

         --  Two columns of the same width: the form, and the sections.
         Form_Column : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form, Pane.Form,
                 [Line (Pane.Name_Label, (Height => Layouts.Length_Of (Heading_Height), Shrink => 0.0, others => <>)),
                  Line (Pane.Name_Field, (Height => Title_Height, Shrink => 0.0, others => <>)),
                  Line (Pane.Desc_Label,
                        (Height => Layouts.Length_Of (Heading_Height), Shrink => 0.0,
                         Margin => (Top => Layouts.Length_Of (Tool_Gap), others => <>),
                         others => <>)),
                  UI.Styled
                    (UI.Put_In
                       (Form, Pane.Desc_Sheet, [Line (Pane.Desc_Text, (Grow => 1.0, Height => 0.0, others => <>))]),
                     (Flow => Column, Height => Outline_Description_Height, Shrink => 0.0,
                      others => <>))]),
              (Flow => Column, Grow => 1.0, Width => 0.0, Gap => Layouts.Length_Of (Tool_Gap), others => <>));

         --  The ghost of the block dragged: its title, in a box of the same outline, a little clear.
         Blocks : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form, Pane.Content,
                 [Line (Pane.None, (Height => Layouts.Length_Of (Index_Height), others => <>)),
                  Line (Pane.Drop_Line,
                        (Place => Absolute, Height => Layouts.Length_Of (Drop_Line_Height), others => <>)),
                  UI.Styled
                    (UI.Put_In
                       (Form, Pane.Ghost,
                        [Line (Pane.Ghost_Title,
                               (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Index_Height), others => <>))]),
                     (Place => Absolute, Flow => Row, Align => Center,
                      Padding => (Left | Right => Layouts.Length_Of (Index_Pad + Outline_Handle + Tool_Gap),
                                  others => <>),
                      others => <>))]),
              (Flow => Column, Shrink => 0.0, Gap => Layouts.Length_Of (Index_Gap * Pixels - Offset),
               Unit => Device_Pixels,
               others => <>));

         Sections_Column : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form, Pane.Sections,
                 [UI.Styled
                    (UI.Put_In
                       (Form, Pane.Head,
                        [Line (Pane.Heading, (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Heading_Height),
                                              others => <>)),
                         UI.Place (Adding, Width => Add_Section_Width,
                            Height => Layouts.Length_Of (Bar_Button_Height), Shrink => 0.0, Exact => True)],
                        Flow => Layouts.Row),
                     (Flow => Row, Align => Center, Height => Title_Height, Shrink => 0.0,
                      Gap => Layouts.Length_Of (Tool_Gap / 2.0),
                      others => <>)),
                  UI.Styled
                    (UI.Put_In (Form, Pane.Scroll, [Blocks]), (Grow => 1.0, Height => 0.0, others => <>))]),
              (Flow => Column, Grow => 1.0, Width => 0.0, Gap => Layouts.Length_Of (Tool_Gap), others => <>));

         Whole : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Pane.View, [Form_Column, Sections_Column], Flow => Layouts.Row),
              (Flow => Row, Grow => 1.0, Height => 0.0, Gap => Outline_Gap,
               Padding => (others => Outline_Gap),
               others => <>));

         --  The colour of a section is chosen in a box over the content.
         Popout : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form, Pane.Colour_Popout,
                 [Line (Pane.Colour_Picker, (Width => 240.0, Height => 208.0, Shrink => 0.0, others => <>)),
                  UI.Styled
                    (UI.Put_In
                       (Form, Pane.Colour_Actions,
                        [UI.Place (Cancelling, Grow => 1.0, Width => 0.0, Exact => True),
                         UI.Place (Accepting, Grow => 1.0, Width => 0.0, Exact => True)],
                        Flow => Layouts.Row),
                     (Flow => Row, Height => 28.0, Gap => 8.0, others => <>))]),
              (Place => Absolute, Flow => Column, Width => 264.0, Height => 270.0, Padding => (others => 12.0),
               Gap => 10.0, others => <>));
      begin
         UI.Mount_Into (Form, Content_Panel (Item).all, Whole);
         UI.Mount_Into (Form, Content_Panel (Item).all, Popout);
      end;

      if not Item.Shell.Windowed then
         Panels.Set_Fill (Pane.View, Desk);
      end if;

      --  Two columns of the same width: the form, and the sections.
      Labels.Set_Text (Pane.Name_Label, "Title");
      Labels.Set_Style (Pane.Name_Label, Pomarine.Line_Texts.Caption);
      Text_Fields.Set_Shared (Pane.Name_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Pane.Name_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
      Text_Fields.Attach (Pane.Name_Field, Pane.Name_Doc'Unchecked_Access);
      Widgets.Set_Accessible_Name (Pane.Name_Field, "Project title");
      Labels.Set_Text (Pane.Desc_Label, "Description");
      Labels.Set_Style (Pane.Desc_Label, Pomarine.Line_Texts.Caption);
      --  The editor draws the outline.
      Editors.Set_Shared (Pane.Desc_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (Pane.Desc_Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
      Editors.Set_Paper (Pane.Desc_Text, Paper);
      Editors.Attach (Pane.Desc_Text, Pane.Desc_Doc'Unchecked_Access);

      Labels.Set_Text (Pane.Heading, "Sections");
      Labels.Set_Style (Pane.Heading, Pomarine.Line_Texts.Caption);

      Labels.Set_Text (Pane.None, "No sections yet");
      Labels.Set_Ink (Pane.None, Closed_Ink);
      Panels.Set_Fill (Pane.Drop_Line, Pomarine.Themes.Accent);
      Widgets.Set_Visible (Pane.Drop_Line, False);
      --  The ghost of the block dragged: its title, in a box of the same
      --  outline, a little clear.
      declare
         Fill : Themes.Color := Themes.Resolve (Colors, Row_Fill);
      begin
         Fill.Alpha := 225;
         Panels.Set_Fill_Color (Pane.Ghost, Fill);
      end;
      Panels.Set_Border (Pane.Ghost, Themes.Focus);
      Widgets.Set_Visible (Pane.Ghost, False);
      Panels.Set_Fill (Pane.Colour_Popout, Themes.Background);
      Panels.Set_Border (Pane.Colour_Popout, Themes.Border);
      Panels.Set_Shadow (Pane.Colour_Popout, Themes.Shadow);
      Widgets.Set_Visible (Pane.Colour_Popout, False);
      Widgets.Set_Visible (Pane.View, False);
   end Build_Outline;

end View.Build.Outline_View;
