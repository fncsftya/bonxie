with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Layouts;
with Items.Windows.Metrics;
with Items.Windows.Parts;

package body Items.Windows.Displays is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;

   procedure Show_Pager (Item : in out Window);
   --  Show the buttons to turn the page, if the source has pages to turn.

   procedure Show_Pager (Item : in out Window) is
      Paged : constant Boolean :=
        Item.Details.Kind = Source and then Item.Details.Page_Count > 1
        and then not Parts.Is_Text_Source (Item);
   begin
      Widgets.Set_Visible (Item.Pager, Paged);
      Buttons.Set_Enabled (Item.Prev_Button, Paged and then Item.Details.Page > 1);
      Buttons.Set_Enabled
        (Item.Next_Button, Paged and then Item.Details.Page < Item.Details.Page_Count);
   end Show_Pager;

   procedure Show_Fetch (Item : in out Window) is
      Wanted : constant Boolean :=
        Item.Details.Kind = Source and then Item.Details.Captured_At = 0
        and then Item.Details.Origin = Remote
        and then Item.Zoom >= Metrics.Compact_Below;
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
        Float'Min (1.0, Float'Max (Metrics.Min_Chrome, Item.Zoom));
      Pixels : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
      Narrow : constant Boolean := Item.Zoom < Metrics.Compact_Below;
      Of_Source : constant Boolean := Item.Details.Kind = Source;
   begin
      Frames.Set_Status_Visible (Item.Chrome, not Narrow);
      Widgets.Set_Visible
        (Item.Body_Text, not (Narrow and then Of_Source) and then not Parts.Is_Unchosen (Item));
      Frames.Set_Scale (Item.Chrome, Chrome);
      Layouts.Set_Layout
        (Item.Fetch_Button,
         Position => (Top => Pomarine.Boxes.Edge (Metrics.Outline * Pixels)
                             + (Metrics.Bar_Height * Chrome + (Metrics.Url_Height - Metrics.Fetch_Height) / 2.0)
                               * Pixels,
                      others => <>),
         Unit => Layouts.Device_Pixels);
      Show_Fetch (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Fit_Zoom;

   procedure Show_Mode (Item : in out Window) is
      Of_Source : constant Boolean := Item.Details.Kind = Source;
      Pictured  : constant Boolean :=
        Of_Source and then not Parts.Is_Unchosen (Item) and then not Parts.Is_Text_Source (Item);
   begin
      Widgets.Set_Visible (Item.Tools, Pictured);
      Widgets.Set_Visible (Item.Zoom_Slider, Pictured);
      Widgets.Set_Visible (Item.Zoom_Button, Pictured);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Picture, Pictured and then not Item.Paged);
      Widgets.Set_Visible (Item.Pages, Pictured and then Item.Paged);
      Widgets.Set_Visible (Item.Text_View, Parts.Is_Text_Source (Item));
      Widgets.Set_Visible (Item.Wizard, Parts.Is_Unchosen (Item));
      Show_Pager (Item);
      Fit_Zoom (Item);
   end Show_Mode;

   procedure Show_Title (Item : in out Window) is
      Typed : constant String := Docs.Whole (Item.Title_Doc);
      Title : constant Projects.Titles.Bounded_String :=
        Projects.Titles.To_Bounded_String (Typed, Ada.Strings.Right);
   begin
      Item.Details.Title := Title;
      Item.Title_Version := Docs.Current (Item.Title_Doc);
      Frames.Set_Title (Item.Chrome, Typed);
   end Show_Title;

   procedure Show_Words (Item : in out Window) is
   begin
      Item.Content_Version := Docs.Current (Item.Content_Doc);
      if Item.Details.Kind = Note then
         Item.Word_Count := Count_Words (Docs.Whole (Item.Content_Doc));
         --  A failure to dictate is told until the text is changed; what
         --  is going on is told while it is.
         if Item.Dictating in Silent | Failed then
            Item.Dictating := Silent;
            Labels.Set_Text (Item.Status, Parts.Status_Text (Item.Word_Count));
         end if;
      end if;
   end Show_Words;

   procedure Show_Kind (Item : in out Window) is
      Of_Source : constant Boolean := Item.Details.Kind = Source;
   begin
      --  A note's text is in the serif; a source's link, in the face of
      --  the interface.
      if Item.Face_Of /= Item.Details.Kind then
         Item.Face_Of := Item.Details.Kind;
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
      if Of_Source then
         Editors.Set_Icon (Item.Body_Text, Icon_Set.Link);
         Editors.Set_Placeholder (Item.Body_Text, "https://");
      else
         Editors.Clear_Icon (Item.Body_Text);
         Editors.Set_Placeholder (Item.Body_Text, "");
      end if;
      Layouts.Set_Layout
        (Item.Body_Text, Grow => (if Of_Source then 0.0 else 1.0),
         Height => (if Of_Source then Metrics.Url_Height else 0.0));
      Widgets.Set_Visible (Item.Speak_Button, not Of_Source);
      Widgets.Set_Visible (Item.Outline_Button, not Of_Source);
      if not Of_Source then
         Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Body_Text).all, False);
      end if;
      Show_Mode (Item);
      Widgets.Request_Layout (Item.Body_Text);
   end Show_Kind;

end Items.Windows.Displays;
