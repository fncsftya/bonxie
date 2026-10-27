with Word_Tools;
with Item_Window_UI;
with Items.Sources;
with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Layouts;
with Items.Windows.Handlers;
with Items.Windows.Metrics;
with Pomarine.Icons;
with Pomarine.UI;

package body Items.Windows.Builder is

   package UI renames Pomarine.UI;
   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;

   procedure Make_Parts
     (Item    : in out Window;
      Canvas  : in out Widgets.Widget'Class;
      Dock    : in out Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float)
   is
      Pixels : constant Float := Density;
      Edge   : constant Float := Pomarine.Boxes.Edge (Metrics.Outline * Pixels);
      --  In whole pixels, as the outline is.

      function Size (Wide, High : Float) return Layouts.Style is
        (Width => Layouts.Length_Of (Wide), Height => Layouts.Length_Of (High), others => <>);
   begin
      Item.Pixels := Pixels;
      Frames.Build
        (Item.Chrome, Canvas, Bar, Pixels, Editable_Title => True,
         Dock => Dock'Unrestricted_Access);
      Item.UI_Host.Open (Canvas);
      declare
         Screen : UI.View renames Item.UI_Host.Screen.all;
         Bound : constant Item_Window_UI.Controls.Context'Class :=
           Item_Window_UI.Controls.Bind (Screen, Item.Controls'Access);

         function Put (Part : in out Widgets.Widget'Class; Using : Layouts.Style) return UI.Layout is
           (UI.Styled (UI.Put (Screen, Part), Using));

         function Button
           (Part : in out Buttons.Button; What : Item_Window_VM.Command;
            Look : Buttons.Settings; Wide, High : Float; Index : Natural := 0) return UI.Layout is
         begin
            Buttons.Configure (Part, Look);
            declare
               Handle : constant UI.Button_Handle := Bound.Borrow_Button (Part, What, Index, Reflect => False);
            begin
               case What is
                  when Item_Window_VM.Use_Pointer => Bound.Selected_When (Handle, Item_Window_UI.Pointer_Flag);
                  when Item_Window_VM.Use_Marker => Bound.Selected_When (Handle, Item_Window_UI.Marker_Flag);
                  when Item_Window_VM.Use_Eraser => Bound.Selected_When (Handle, Item_Window_UI.Eraser_Flag);
                  when Item_Window_VM.Previous_Page =>
                     Bound.Enabled_When (Handle, Item_Window_UI.Previous_Flag);
                  when Item_Window_VM.Next_Page => Bound.Enabled_When (Handle, Item_Window_UI.Next_Flag);
                  when others => null;
               end case;
               return UI.Styled (UI.Place (Handle), Size (Wide, High));
            end;
         end Button;

         Link : constant UI.Layout := Button
           (Item.Link_Button, Item_Window_VM.Choose_Link,
            Buttons.Looks ("From URL", Icon => Pomarine.Icons.Shown (Icon_Set.Link), Captioned => True),
            Metrics.Wizard_Button_Width, Metrics.Wizard_Button_Height);
         File : constant UI.Layout := Button
           (Item.File_Button, Item_Window_VM.Choose_File,
            Buttons.Looks ("From File", Icon => Pomarine.Icons.Shown (Icon_Set.Document), Captioned => True),
            Metrics.Wizard_Button_Width, Metrics.Wizard_Button_Height);
         Wizard : constant UI.Layout := UI.Styled
           (UI.Put_In (Screen, Item.Wizard, [Link, File], Gap => Layouts.Length_Of (Metrics.Wizard_Gap),
                       Align => Layouts.Center, Spread => Layouts.Center),
            (Grow => 1.0, Height => 0.0, Align => Layouts.Center, Spread => Layouts.Center,
             Gap => Layouts.Length_Of (Metrics.Wizard_Gap), others => <>));
         Text_Box : constant Layouts.Style :=
           (Grow => 1.0, Height => 0.0, Margin => (Left | Right => Layouts.Length_Of (-Edge), others => <>),
            Unit => Layouts.Device_Pixels, others => <>);
         Body_Control : constant UI.Widget_Handle := Bound.Borrow_Widget (Item.Body_Text);
         Content : constant UI.Layout := UI.Fragment
           (Screen, [UI.Styled (UI.Place (Body_Control), Text_Box),
                     Put (Item.Picture, (Grow => 1.0, Height => 0.0, others => <>)),
                     Put (Item.Pages, (Grow => 1.0, Height => 0.0, others => <>)),
                     Put (Item.Text_View, Text_Box), Wizard]);
         Previous : constant UI.Layout := Button
           (Item.Prev_Button, Item_Window_VM.Previous_Page,
            Buttons.Looks ("Previous page", Icon => Pomarine.Icons.Shown (Icon_Set.Back)),
            Metrics.Tool_Size, Metrics.Zoom_Row_Height);
         Next : constant UI.Layout := Button
           (Item.Next_Button, Item_Window_VM.Next_Page,
            Buttons.Looks ("Next page", Icon => Pomarine.Icons.Shown (Icon_Set.Forward)),
            Metrics.Tool_Size, Metrics.Zoom_Row_Height);
         Pager : constant UI.Layout := UI.Put_In
           (Screen, Item.Pager, [Previous, Next], Flow => Layouts.Row, Gap => Layouts.Length_Of (Metrics.Button_Gap));
         Speech : constant UI.Layout := Button
           (Item.Speak_Button, Item_Window_VM.Speak,
            Buttons.Looks ("Dictate", Icon => Pomarine.Icons.Shown (Icon_Set.Microphone),
                           Icon_Points => Metrics.Speak_Icon_Size, Captioned => True),
            Metrics.Speak_Width, Metrics.Zoom_Row_Height);
         Cursor : constant UI.Layout := Button
           (Item.Cursor_Button, Item_Window_VM.Use_Pointer,
            Buttons.Looks ("Ptr", Icon => Pomarine.Icons.Shown (Icon_Set.Cursor)),
            Metrics.Tool_Size, Metrics.Zoom_Row_Height);
         Marker : constant UI.Layout := Button
           (Item.Marker_Button, Item_Window_VM.Use_Marker,
            Buttons.Looks ("Mark", Icon => Pomarine.Icons.Shown (Icon_Set.Highlighter)),
            Metrics.Tool_Size, Metrics.Zoom_Row_Height);
         Eraser : constant UI.Layout := Button
           (Item.Eraser_Button, Item_Window_VM.Use_Eraser,
            Buttons.Looks ("Rub", Icon => Pomarine.Icons.Shown (Icon_Set.Eraser)),
            Metrics.Tool_Size, Metrics.Zoom_Row_Height);
         Tools : constant UI.Layout := UI.Put_In
           (Screen, Item.Tools, [Cursor, Marker, Eraser], Flow => Layouts.Row,
            Gap => Layouts.Length_Of (Metrics.Button_Gap));
         Outline : constant UI.Layout := Button
           (Item.Outline_Button, Item_Window_VM.Link_To_Outline,
            Buttons.Looks ("Section", Captioned => True, Shape => Buttons.Dropdown),
            Metrics.Outline_Button_Width, Metrics.Zoom_Row_Height);
         Zoom : constant UI.Layout := Button
           (Item.Zoom_Button, Item_Window_VM.Toggle_Zoom,
            Buttons.Looks ("100%", Captioned => True, Shape => Buttons.Dropdown),
            Metrics.Zoom_Button_Width, Metrics.Zoom_Row_Height);
         Status : constant UI.Layout := UI.Fragment
           (Screen, [Pager, Speech,
                     Put (Item.Status, (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Metrics.Label_Height),
                                        others => <>)),
                     Tools, Outline, Zoom]);
         Progress : constant UI.Layout := Put
           (Item.Progress, (Place => Layouts.Absolute,
                            Position => (Left | Right | Bottom => 0.0, others => <>),
                            Height => Layouts.Length_Of (Metrics.Progress_Height), others => <>));

         function Zoom_Row (Row : Positive) return UI.Layout is
            First : constant Positive := (Row - 1) * 3 + 1;
            Children : UI.Layout_Array (1 .. 3);
         begin
            for Offset in Children'Range loop
               declare
                  Which : constant Positive := First + Offset - 1;
               begin
                  Children (Offset) := Button
                    (Item.Menu_Buttons (Which), Item_Window_VM.Zoom_Preset,
                     Buttons.Looks (Items.Sources.Percent (Metrics.Preset_Zooms (Which))),
                     Metrics.Preset_Width, Metrics.Zoom_Row_Height, Index => Which);
               end;
            end loop;
            return UI.Styled
              (UI.Put_In (Screen, Item.Menu_Rows (Row), Children, Flow => Layouts.Row),
               (Flow => Layouts.Row, Gap => Layouts.Length_Of (Edge), Unit => Layouts.Device_Pixels, others => <>));
         end Zoom_Row;

         Slider_Handle : constant UI.Widget_Handle :=
           Bound.Borrow_Slider (Item.Zoom_Slider, Item_Window_UI.Zoom_Value);
         Slider : constant UI.Layout := UI.Styled
           (UI.Place (Slider_Handle), Size (Metrics.Zoom_Slider_Width, Metrics.Zoom_Row_Height));
         First_Row : constant UI.Layout := Zoom_Row (1);
         Second_Row : constant UI.Layout := Zoom_Row (2);
         Menu : constant UI.Layout := UI.Styled
           (UI.Put_In (Screen, Item.Zoom_Menu, [Slider, First_Row, Second_Row]),
            (Place => Layouts.Absolute,
             Position => (Right => Layouts.Length_Of ((Metrics.Corner_Size + Edge) * Pixels),
                          Bottom => Layouts.Length_Of ((Metrics.Status_Height + Edge) * Pixels), others => <>),
             Flow => Layouts.Column, Padding => (others => Layouts.Length_Of (Edge)), Gap => Layouts.Length_Of (Edge),
             Unit => Layouts.Device_Pixels, others => <>));
         Fetch : constant UI.Layout := Button
           (Item.Fetch_Button, Item_Window_VM.Capture,
            Buttons.Looks ("Add", Buttons.Primary),
            Metrics.Fetch_Width, Metrics.Fetch_Height);
         Fetch_Overlay : constant UI.Layout := UI.Styled
           (Fetch, (Width => Layouts.Length_Of (Metrics.Fetch_Width * Pixels),
                    Height => Layouts.Length_Of (Metrics.Fetch_Height * Pixels),
                    Place => Layouts.Absolute,
                    Position => (Right => Layouts.Length_Of
                                          (Edge + Pomarine.Boxes.Offset (Pixels) + Metrics.Fetch_Inset * Pixels),
                                 others => <>),
                    Unit => Layouts.Device_Pixels, others => <>));
         Overlays : constant UI.Layout := UI.Fragment (Screen, [Menu, Fetch_Overlay]);
      begin
         Bound.On_Frame_Event (Item.Chrome, Widgets.Double_Click, Item_Window_VM.Begin_Title_Edit);
         Bound.On_Frame_Event (Item.Chrome, Widgets.Submit, Item_Window_VM.Accept_Title);
         Bound.On_Frame_Event (Item.Chrome, Widgets.Blur, Item_Window_VM.Accept_Title);
         Bound.On_Frame_Event (Item.Chrome, Widgets.Minimize, Item_Window_VM.Minimize_Window);
         Bound.On_Frame_Event (Item.Chrome, Widgets.Restore, Item_Window_VM.Restore_Window);
         Bound.On_Frame_Event (Item.Chrome, Widgets.Close, Item_Window_VM.Close_Window);
         Bound.On_Event (Body_Control, Widgets.Submit, Item_Window_VM.Capture);
         Bound.On_Event (Body_Control, Widgets.Click, Item_Window_VM.Choose_File);
         Bound.On_Editor_Event (Body_Control, Item_Window_UI.Controls.Tool_Used, Item_Window_VM.Use_Tool, 0, True);
         Bound.On_Editor_Event (Body_Control, Item_Window_UI.Controls.Link_Followed, Item_Window_VM.Follow_Link);
         UI.Mount_Before (Screen, Frames.Content_End (Item.Chrome).all, Content);
         UI.Mount_Before (Screen, Frames.Status_End (Item.Chrome).all, Status);
         UI.Mount_Into (Screen, Frames.Status_Surface (Item.Chrome).all, Progress);
         UI.Mount_Into (Screen, Frames.Surface (Item.Chrome).all, Overlays);
      end;

      Pomarine.Widgets.Progress_Bars.Set_Over (Item.Progress, Pomarine.Themes.Strip, Meter_Slot);
      Panels.Set_Fill (Item.Wizard, Pomarine.Themes.Page);
      Panels.Set_Fill (Item.Zoom_Menu, Pomarine.Themes.Border);
      Editors.Configure
        (Item.Body_Text, Pomarine.Line_Texts.Serif, Metrics.Text_Size, Metrics.Measure);
      Editors.Set_Paper (Item.Body_Text, Pomarine.Themes.Page);
      Editors.Set_Toolbar (Item.Body_Text);
      Word_Tools.Add (Item.Body_Text);
      Editors.Configure
        (Item.Text_View, Pomarine.Line_Texts.Serif, Metrics.Text_Size, Metrics.Measure);
      Editors.Set_Paper (Item.Text_View, Pomarine.Themes.Page);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Text_View).all);

      Widgets.Set_Visible (Item.Fetch_Button, False);
      Widgets.Set_Visible (Item.Tools, False);
      Widgets.Set_Visible (Item.Zoom_Button, False);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Pager, False);
      Widgets.Set_Visible (Item.Text_View, False);
      Widgets.Set_Visible (Item.Wizard, False);
      Widgets.Set_Visible (Item.Picture, False);
      Widgets.Set_Visible (Item.Pages, False);
      Widgets.Set_Visible (Item.Progress, False);
      --  What they edit is the model's, and is there as long as it is.
      Frames.Attach_Title (Item.Chrome, Items.Models.Title_Document (Item.Model.all));
      Editors.Attach (Item.Body_Text, Items.Models.Content_Document (Item.Model.all));
      Editors.Attach (Item.Text_View, Items.Models.Text_Document (Item.Model.all));
      Handlers.Listen (Item);
   end Make_Parts;

end Items.Windows.Builder;
