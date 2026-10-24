with Pomarine.Widgets.Editors;
with SDL3.Cursors;
with Pomarine.Boxes;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Viewer.Outlines;
with Viewer.Style;

package body Viewer.Build.Outline_View is

   package Widgets renames Pomarine.Widgets;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Grips renames Pomarine.Widgets.Grips;
   package Editors renames Pomarine.Widgets.Editors;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Make_Block (Item : in out Session; Index : Positive) is
      View   : Outline_Parts renames Item.Outline_View;
      Block  : Section_Block renames View.Blocks (Index);
      Pixels : constant Float := Item.Shell.Density;

      procedure Icon_Button
        (Part : in out Buttons.Button; Name : String; Icon : Pomarine.Icons.Icon) is
      begin
         Buttons.Set_Label (Part, Name);
         Buttons.Set_Icon (Part, Icon);
         Buttons.Set_Focusable (Part, True);
         Set_Layout (Part, Width => Outline_Button, Height => Outline_Button, Shrink => 0.0);
      end Icon_Button;
   begin
      Widgets.Add_Before (View.Content, Block.Row, View.None);
      Widgets.Add (Block.Row, Block.Line, Block.Notes_Sheet);
      Widgets.Add (Block.Line, Block.Handle, Block.Swatch, Block.Field, Block.Notes);
      Widgets.Add (Block.Line, Block.Up, Block.Down, Block.Remove);
      Widgets.Add (Block.Notes_Sheet, Block.Notes_Text);
      Grips.Set_Fill (Block.Row, Row_Fill);
      Grips.Set_Hover_Fill (Block.Row, Row_Fill);
      Grips.Set_Border (Block.Row, Themes.Border);
      Grips.Set_Shadow (Block.Row, Side_Fill);
      Grips.Set_Wanted_Cursor (Block.Row, SDL3.Cursors.Grab);
      Set_Layout
        (Block.Row, Shrink => 0.0, Flow => Column,
         Padding => (Left | Right => Index_Pad, others => <>), Shadowed => True);
      Set_Layout
        (Block.Line, Shrink => 0.0, Flow => Row, Align => Center, Gap => Tool_Gap);
      Set_Layout
        (Block.Line, Height => Outline_Block_Height * Pixels, Unit => Device_Pixels);
      Buttons.Set_Label (Block.Notes, "Notes");
      Buttons.Set_Captioned (Block.Notes, True);
      Buttons.Set_Focusable (Block.Notes, True);
      Set_Layout (Block.Notes, Width => Notes_Width, Height => Outline_Button, Shrink => 0.0);
      Set_Layout
        (Block.Notes_Sheet, Flow => Column, Height => Outline_Notes_Height, Shrink => 0.0,
         Margin => (Bottom => Tool_Gap, others => <>));
      Editors.Set_Shared (Block.Notes_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (Block.Notes_Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
      Editors.Set_Paper (Block.Notes_Text, Paper);
      Editors.Attach (Block.Notes_Text, Block.Notes_Doc'Unchecked_Access);
      Set_Layout (Block.Notes_Text, Grow => 1.0, Height => 0.0);
      Widgets.Set_Visible (Block.Notes_Sheet, False);
      Labels.Set_Text (Block.Handle, "::");
      Labels.Set_Ink (Block.Handle, Quiet_Ink);
      Set_Layout (Block.Handle, Width => Outline_Handle, Height => Index_Height, Shrink => 0.0);
      Set_Layout
        (Block.Swatch, Width => Outline_Field_Height - 2.0, Height => Outline_Field_Height - 2.0, Shrink => 0.0);
      Grips.Set_Wanted_Cursor (Block.Swatch, SDL3.Cursors.Pointer);
      Grips.Set_Hover_Outline (Block.Swatch, Themes.Foreground);
      Grips.Set_Focusable (Block.Swatch, True);
      Widgets.Set_Accessible_Name (Block.Swatch, "Change section colour");
      Text_Fields.Set_Shared (Block.Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Block.Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
      Text_Fields.Attach (Block.Field, Block.Doc'Unchecked_Access);
      Set_Layout (Block.Field, Grow => 1.0, Width => 0.0, Height => Outline_Field_Height);
      Icon_Button (Block.Up, "Move up", Pomarine.Icons.Chevron_Up);
      Icon_Button (Block.Down, "Move down", Pomarine.Icons.Chevron_Down);
      Icon_Button (Block.Remove, "Delete section", Icon_Set.Delete);
      Buttons.Set_Kind (Block.Remove, Buttons.Danger);
      Widgets.Set_Visible (Block.Row, False);
   end Make_Block;

   procedure Build_Outline (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);

   begin
      Widgets.Add (Item.Toolbar.Content_Panel, View.View);
      Widgets.Add (View.View, View.Form, View.Sections);
      Widgets.Add (View.Form, View.Name_Label, View.Name_Field, View.Desc_Label);
      Widgets.Add (View.Form, View.Desc_Sheet);
      Widgets.Add (View.Desc_Sheet, View.Desc_Text);
      Widgets.Add (View.Sections, View.Head, View.Scroll);
      Widgets.Add (View.Head, View.Heading, View.Add_Button);
      Widgets.Add (View.Scroll, View.Content);

      if not Item.Shell.Windowed then
         Panels.Set_Fill (View.View, Desk);
      end if;
      Set_Layout
        (View.View, Flow => Row, Grow => 1.0, Height => 0.0, Gap => Outline_Gap,
         Padding => (others => Outline_Gap));

      --  Two columns of the same width: the form, and the sections.
      Set_Layout (View.Form, Flow => Column, Grow => 1.0, Width => 0.0, Gap => Tool_Gap);
      Labels.Set_Text (View.Name_Label, "Title");
      Labels.Set_Style (View.Name_Label, Pomarine.Line_Texts.Caption);
      Set_Layout (View.Name_Label, Height => Heading_Height, Shrink => 0.0);
      Text_Fields.Set_Shared (View.Name_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (View.Name_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
      Text_Fields.Attach (View.Name_Field, View.Name_Doc'Unchecked_Access);
      Set_Layout (View.Name_Field, Height => Title_Height, Shrink => 0.0);
      Labels.Set_Text (View.Desc_Label, "Description");
      Labels.Set_Style (View.Desc_Label, Pomarine.Line_Texts.Caption);
      Set_Layout
        (View.Desc_Label, Height => Heading_Height, Shrink => 0.0,
         Margin => (Top => Tool_Gap, others => <>));
      --  The editor draws the outline.
      Set_Layout
        (View.Desc_Sheet, Flow => Column, Height => Outline_Description_Height,
         Shrink => 0.0);
      Editors.Set_Shared (View.Desc_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (View.Desc_Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
      Editors.Set_Paper (View.Desc_Text, Paper);
      Editors.Attach (View.Desc_Text, View.Desc_Doc'Unchecked_Access);
      Set_Layout (View.Desc_Text, Grow => 1.0, Height => 0.0);

      Set_Layout (View.Sections, Flow => Column, Grow => 1.0, Width => 0.0, Gap => Tool_Gap);
      Set_Layout
        (View.Head, Flow => Row, Align => Center, Height => Title_Height, Shrink => 0.0, Gap => Tool_Gap / 2.0);
      Labels.Set_Text (View.Heading, "Sections");
      Labels.Set_Style (View.Heading, Pomarine.Line_Texts.Caption);
      Set_Layout (View.Heading, Grow => 1.0, Width => 0.0, Height => Heading_Height);
      Buttons.Set_Label (View.Add_Button, "Add Section");
      Buttons.Set_Icon (View.Add_Button, Icon_Set.Plus);
      Buttons.Set_Captioned (View.Add_Button, True);
      Buttons.Set_Focusable (View.Add_Button, True);
      Set_Layout (View.Add_Button, Width => Add_Section_Width, Height => Bar_Button_Height, Shrink => 0.0);
      Set_Layout (View.Scroll, Grow => 1.0, Height => 0.0);
      Set_Layout
        (View.Content, Flow => Column, Shrink => 0.0,
         Gap => Index_Gap * Pixels - Offset, Unit => Device_Pixels);

      Labels.Set_Text (View.None, "No sections yet");
      Labels.Set_Ink (View.None, Closed_Ink);
      Widgets.Add (View.Content, View.None);
      Set_Layout (View.None, Height => Index_Height);
      Widgets.Add (View.Content, View.Drop_Line);
      Panels.Set_Fill (View.Drop_Line, Pomarine.Themes.Accent);
      Set_Layout (View.Drop_Line, Place => Absolute, Height => Drop_Line_Height);
      Widgets.Set_Visible (View.Drop_Line, False);
      --  The ghost of the block dragged: its title, in a box of the same
      --  outline, a little clear.
      Widgets.Add (View.Content, View.Ghost);
      Widgets.Add (View.Ghost, View.Ghost_Title);
      declare
         Fill : Themes.Color := Themes.Resolve (Colors, Row_Fill);
      begin
         Fill.Alpha := 225;
         Panels.Set_Fill_Color (View.Ghost, Fill);
      end;
      Panels.Set_Border (View.Ghost, Themes.Focus);
      Set_Layout
        (View.Ghost, Place => Absolute, Flow => Row, Align => Center,
         Padding => (Left | Right => Index_Pad + Outline_Handle + Tool_Gap, others => <>));
      Set_Layout (View.Ghost_Title, Grow => 1.0, Width => 0.0, Height => Index_Height);
      Widgets.Set_Visible (View.Ghost, False);
      Widgets.Add (Item.Toolbar.Content_Panel, View.Colour_Popout);
      Panels.Set_Fill (View.Colour_Popout, Themes.Background);
      Panels.Set_Border (View.Colour_Popout, Themes.Border);
      Panels.Set_Shadow (View.Colour_Popout, Themes.Shadow);
      Set_Layout (View.Colour_Popout, Place => Absolute, Flow => Column,
                  Width => 264.0, Height => 270.0, Padding => (others => 12.0), Gap => 10.0);
      Widgets.Add (View.Colour_Popout, View.Colour_Picker, View.Colour_Actions);
      Pomarine.Widgets.Grips.Set_Wanted_Cursor
        (Pomarine.Widgets.Grips.Grip (View.Colour_Picker), SDL3.Cursors.Pointer);
      Set_Layout (View.Colour_Picker, Width => 240.0, Height => 208.0, Shrink => 0.0);
      Set_Layout (View.Colour_Actions, Flow => Row, Height => 28.0, Gap => 8.0);
      Widgets.Add (View.Colour_Actions, View.Colour_Cancel, View.Colour_OK);
      Buttons.Set_Label (View.Colour_OK, "OK");
      Buttons.Set_Kind (View.Colour_OK, Buttons.Primary);
      Buttons.Set_Label (View.Colour_Cancel, "Cancel");
      Buttons.Set_Focusable (View.Colour_OK, True);
      Buttons.Set_Focusable (View.Colour_Cancel, True);
      Set_Layout (View.Colour_OK, Grow => 1.0, Width => 0.0);
      Set_Layout (View.Colour_Cancel, Grow => 1.0, Width => 0.0);
      Widgets.Set_Visible (View.Colour_Popout, False);
      Outlines.Listen (Item);
      Widgets.Set_Visible (View.View, False);
   end Build_Outline;

end Viewer.Build.Outline_View;
