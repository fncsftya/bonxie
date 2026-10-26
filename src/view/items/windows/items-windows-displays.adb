with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Icon_Set;
with Items.Sources;
with Pomarine.Line_Texts;
with Vision;
with Pomarine.Widgets.Layouts;
with Items.Windows.Metrics;

package body Items.Windows.Displays is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Views renames Pomarine.Widgets.Page_Views;

   use type Items.Models.Captures;
   use type Items.Models.Tools;

   function Tool_Of (Chosen : Items.Models.Tools) return Pictures.Tools is
     (case Chosen is
         when Items.Models.Pointer     => Pictures.Pointer,
         when Items.Models.Highlighter => Pictures.Highlighter,
         when Items.Models.Eraser      => Pictures.Eraser);

   procedure Show_Pager (Item : in out Window);
   --  Show the buttons to turn the page, if the source has pages to turn.

   procedure Show_Pager (Item : in out Window) is
      Details : constant Items.Info := Items.Models.Details (Item.Model.all);
      Paged   : constant Boolean :=
        Details.Kind = Source and then Details.Page_Count > 1 and then not Items.Models.Is_Text_Source (Item.Model.all);
   begin
      Widgets.Set_Visible (Item.Pager, Paged);
   end Show_Pager;

   procedure Show_Fetch (Item : in out Window) is
      Details : constant Items.Info := Items.Models.Details (Item.Model.all);
      Wanted : constant Boolean :=
        Details.Kind = Source and then Details.Captured_At = 0
        and then Details.Origin = Remote
        and then Item.Looking.Zoom >= Metrics.Compact_Below;
   begin
      if Wanted /= Widgets.Is_Visible (Item.Fetch_Button) then
         Widgets.Set_Visible (Item.Fetch_Button, Wanted);
         Pomarine.Text_Areas.Set_Trail
           (Editors.Area (Item.Body_Text).all,
            (if Wanted then Metrics.Fetch_Width + Metrics.Fetch_Inset else 0.0));
         Widgets.Request_Layout (Item.Body_Text);
      end if;
   end Show_Fetch;

   procedure Fit_Zoom (Item : in out Window) is
      Chrome : constant Float :=
        Float'Min (1.0, Float'Max (Metrics.Min_Chrome, Item.Looking.Zoom));
      Pixels : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
      Narrow : constant Boolean := Item.Looking.Zoom < Metrics.Compact_Below;
      Of_Source : constant Boolean := Items.Models.Details (Item.Model.all).Kind = Source;
   begin
      Frames.Set_Status_Visible (Item.Chrome, not Narrow);
      Editors.Set_Toolbar (Item.Body_Text, not Narrow);
      Widgets.Set_Visible
        (Item.Body_Text, not (Narrow and then Of_Source) and then not Items.Models.Is_Unchosen (Item.Model.all));
      Frames.Set_Scale (Item.Chrome, Chrome);
      Layouts.Set_Layout
        (Item.Fetch_Button,
         Position => (Top => Layouts.Length_Of (Pomarine.Boxes.Edge (Metrics.Outline * Pixels)
                             + (Metrics.Bar_Height * Chrome + (Metrics.Url_Height - Metrics.Fetch_Height) / 2.0)
                               * Pixels),
                      others => <>),
         Unit => Layouts.Device_Pixels);
      Show_Fetch (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Fit_Zoom;

   procedure Show_Mode (Item : in out Window) is
      M         : Items.Models.Item renames Item.Model.all;
      Of_Source : constant Boolean := Items.Models.Details (M).Kind = Source;
      Pictured  : constant Boolean :=
        Of_Source and then not Items.Models.Is_Unchosen (M) and then not Items.Models.Is_Text_Source (M);
      Paged     : constant Boolean := Items.Models.Is_Paged (M);
   begin
      Widgets.Set_Visible (Item.Tools, Pictured);
      Widgets.Set_Visible (Item.Zoom_Button, Pictured);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Picture, Pictured and then not Paged);
      Widgets.Set_Visible (Item.Pages, Pictured and then Paged);
      Widgets.Set_Visible (Item.Text_View, Items.Models.Is_Text_Source (M));
      Widgets.Set_Visible (Item.Wizard, Items.Models.Is_Unchosen (M));
      Show_Pager (Item);
      Fit_Zoom (Item);
   end Show_Mode;

   procedure Show_Title (Item : in out Window) is
   begin
      Item.Title_Shown := Docs.Current (Items.Models.Title_Document (Item.Model.all).all);
      Frames.Set_Title (Item.Chrome, Docs.Whole (Items.Models.Title_Document (Item.Model.all).all));
   end Show_Title;

   procedure Show_Tool (Item : in out Window) is
      Chosen : constant Items.Models.Tools := Items.Models.Tool (Item.Model.all);
   begin
      Pictures.Set_Tool (Item.Picture, Tool_Of (Chosen));
      Views.Set_Tool (Item.Pages, Tool_Of (Chosen));
   end Show_Tool;

   --  A source's link, or a note's text.
   procedure Show_Kind (Item : in out Window);

   procedure Show_Kind (Item : in out Window) is
      Of_Source : constant Boolean := Items.Models.Details (Item.Model.all).Kind = Source;
      Kind      : constant Items.Kinds := Items.Models.Details (Item.Model.all).Kind;
   begin
      --  A note's text is in the serif; a source's link, in the face of
      --  the interface.
      if Item.Face_Of /= Kind then
         Item.Face_Of := Kind;
         if Of_Source then
            Editors.Configure
              (Item.Body_Text, Pomarine.Line_Texts.Interface_Font, Metrics.Link_Size,
               Metrics.Measure);
         else
            Editors.Configure
              (Item.Body_Text, Pomarine.Line_Texts.Serif, Metrics.Text_Size, Metrics.Measure);
         end if;
      end if;
      Frames.Set_Tag_Visible (Item.Chrome, Of_Source);
      Pomarine.Text_Areas.Set_Single_Line
        (Editors.Area (Item.Body_Text).all, Of_Source);
      Pomarine.Text_Areas.Set_Radius
        (Editors.Area (Item.Body_Text).all, (if Of_Source then 0.0 else Pomarine.Themes.Small_Radius));
      --  A source's link is a band like the toolbar's, without a box.
      Editors.Set_Paper (Item.Body_Text, (if Of_Source then Pomarine.Themes.Strip else Pomarine.Themes.Page));
      Editors.Set_Borderless (Item.Body_Text, Of_Source);
      if Of_Source then
         --  A file's path is chosen, not typed: pressing it asks to choose another (see Listen).
         declare
            Is_File : constant Boolean := Items.Models.Details (Item.Model.all).Origin = Local;
         begin
            Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Body_Text).all, Is_File);
            Editors.Set_Icon (Item.Body_Text, (if Is_File then Icon_Set.Document else Icon_Set.Link));
            Editors.Set_Placeholder (Item.Body_Text, (if Is_File then "File" else "https://"));
         end;
      else
         Editors.Clear_Icon (Item.Body_Text);
         Editors.Set_Placeholder (Item.Body_Text, "");
      end if;
      Layouts.Set_Layout
        (Item.Body_Text, Grow => Layouts.Weight_Of (if Of_Source then 0.0 else 1.0),
         Height => (Layouts.Length_Of (if Of_Source then Metrics.Url_Height else 0.0)));
      Widgets.Set_Visible (Item.Speak_Button, not Of_Source);
      Widgets.Set_Visible (Item.Outline_Button, not Of_Source);
      if not Of_Source then
         Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Body_Text).all, False);
      end if;
      Show_Mode (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Show_Kind;

   procedure Show_Zoom (Item : in out Window) is
      To : constant Float := Items.Models.Details (Item.Model.all).Zoom;
   begin
      Pictures.Set_Zoom (Item.Picture, To);
      Views.Set_Zoom (Item.Pages, To);
      Buttons.Set_Label (Item.Zoom_Button, Items.Sources.Percent (To));
      for Which in Item.Menu_Buttons'Range loop
         Buttons.Set_Selected (Item.Menu_Buttons (Which), abs (Metrics.Preset_Zooms (Which) - To) < 0.005);
      end loop;
   end Show_Zoom;

   procedure Show_Picture (Item : in out Window) is
      M       : Items.Models.Item renames Item.Model.all;
      Details : constant Items.Info := Items.Models.Details (M);
   begin
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Pictures.Clear_Marks (Item.Picture);
      Views.Clear_Marks (Item.Pages);
      Pictures.Set_File (Item.Picture, "");
      if Details.Kind /= Source or else Items.Models.Capture (M) /= Items.Models.Ready
        or else Items.Models.Picture_File (M) = ""
      then
         return;
      end if;
      if Items.Models.Wants_Pages (M) then
         declare
            Message : String (1 .. 160);
            Last    : Natural;
         begin
            Items.Vector_Pages.Open
              (Item.Pages, Item.Doc_Sizes, Item.Doc_Source, Items.Models.Picture_File (M),
               Details.Page_Count, Message, Last);
            Items.Models.Pages_Opened
              (M, Last < Message'First, (if Last < Message'First then "" else Message (1 .. Last)));
            if Items.Models.Is_Paged (M) then
               Views.Show_Page (Item.Pages, Details.Page);
            end if;
         end;
      else
         Pictures.Set_File (Item.Picture, Items.Models.Picture_File (M));
      end if;
   end Show_Picture;

   procedure Show_Words (Item : in out Window) is
      Found : constant access Vision.Result := Items.Models.Recognized (Item.Model.all);
   begin
      if Found.Count > 0 then
         Pictures.Set_Words (Item.Picture, Found.all'Unrestricted_Access);
      else
         Pictures.Set_Words (Item.Picture, null);
      end if;
   end Show_Words;

   procedure Show_Marks (Item : in out Window) is
      Kept  : constant Items.Marks.Mark_List := Items.Models.Kept_Marks (Item.Model.all);
      Shown : Pictures.Mark_Array (1 .. Kept.Count);
      Paged : Views.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Marks.Mark renames Kept.Marks.Data (Index);
         begin
            Shown (Index) := Pictures.Clamped_Mark (Each.Left, Each.Right, Each.Y);
            Shown (Index).Trace := Each.Trace;
            Paged (Index) := Views.Clamped_Mark (Each.Left, Each.Right, Each.Y, Each.Page);
            Paged (Index).Trace := Each.Trace;
         end;
      end loop;
      Pictures.Set_Marks (Item.Picture, Shown, Kept.Past);
      Views.Set_Marks (Item.Pages, Paged, Kept.Past);
      --  What the picture says of them is not the person's.
      Items.Models.Marks_Shown_As
        (Item.Model.all,
         (if Items.Models.Is_Paged (Item.Model.all) then Views.Marks_Version (Item.Pages)
          else Pictures.Marks_Version (Item.Picture)));
   end Show_Marks;

   procedure Show_Look (Item : in out Window) is
   begin
      Show_Kind (Item);
      Show_Fetch (Item);
   end Show_Look;

   procedure Show_Status (Item : in out Window) is
      M       : Items.Models.Item renames Item.Model.all;
      Stopping : constant Boolean :=
        Items.Models.Dictation (M) in Items.Models.Preparing | Items.Models.Listening;
   begin
      Labels.Set_Text (Item.Status, Items.Models.Status (M));
      Widgets.Set_Visible (Item.Progress, Items.Models.Shows_Progress (M));
      Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, Items.Models.Progress (M));
      Buttons.Set_Icon (Item.Speak_Button, (if Stopping then Icon_Set.Stop else Icon_Set.Microphone));
      Buttons.Set_Label (Item.Speak_Button, (if Stopping then "Stop" else "Dictate"));
   end Show_Status;

   procedure Show_Where (Item : in out Window) is
      Details : constant Items.Info := Items.Models.Details (Item.Model.all);
   begin
      if Details.State /= Open then
         Widgets.Set_Visible (Item.Zoom_Menu, False);
         Pictures.Unload (Item.Picture);
         Views.Unload (Item.Pages);
      end if;
      Frames.Set_Shown (Item.Chrome, Details.State = Open, Details.State = Minimized);
      if Details.State /= Open then
         Item.Was_Used := False;
      end if;
   end Show_Where;

end Items.Windows.Displays;
