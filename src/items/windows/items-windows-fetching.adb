with Items.Sources;
with Pomarine.Text_Areas;
with Icon_Set;
with Items.Windows.Displays;
with Items.Windows.Parts;

package body Items.Windows.Fetching is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;
   package Editors renames Pomarine.Widgets.Editors;
   package Views renames Pomarine.Widgets.Page_Views;

   procedure Apply_Pages
     (Item : in out Window; Document : String; Page, Count : Natural) is
   begin
      Item.Details.Document :=
        Items.Extensions.To_Bounded_String (Document, Ada.Strings.Right);
      Item.Details.Page := Page;
      Item.Details.Page_Count := Count;
      Displays.Show_Mode (Item);
      --  Turning to another page of a document that is shown.
      if Item.Paged and then Count > 0 and then Item.Details.Captured_At > 0 then
         Labels.Set_Text (Item.Status, Parts.Page_Status (Item));
      end if;
   end Apply_Pages;

   procedure Apply_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0) is
   begin
      Widgets.Set_Visible (Item.Progress, To = Busy);
      if To = Busy then
         Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, 0.0);
      end if;
      case To is
         when Waiting =>
            Labels.Set_Text
              (Item.Status,
               (case Item.Details.Origin is
                   when Unchosen => "Choose where it comes from",
                   when Remote   => "Press Return to capture",
                   when Local    => "Choose a file"));
         when Busy =>
            Labels.Set_Text (Item.Status, "Capturing...");
         when Ready =>
            Item.Details.Captured_At := At_Time;
            Parts.Clear_Recognized (Item);
            Pomarine.Widgets.Pictures.Clear_Marks (Item.Picture);
            Views.Clear_Marks (Item.Pages);
            if Item.Details.Page > 0
              and then Items.Sources.Is_Vector (Items.Extensions.To_String (Item.Details.Document))
            then
               declare
                  Message : String (1 .. 160);
                  Last    : Natural;
               begin
                  Items.Vector_Pages.Open
                    (Item.Pages, Item.Doc_Sizes, Item.Doc_Source, File,
                     Item.Details.Page_Count, Message, Last);
                  Item.Paged := Last < Message'First;
                  if not Item.Paged then
                     Labels.Set_Text (Item.Status, Labels.Fitted ("Failed: " & Message (1 .. Last)));
                     return;
                  end if;
                  Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
                  Views.Show_Page (Item.Pages, Item.Details.Page);
               end;
            else
               Item.Paged := False;
               Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
               Pomarine.Widgets.Pictures.Set_File (Item.Picture, File);
            end if;
            Displays.Show_Mode (Item);
            Labels.Set_Text
              (Item.Status,
               (if Item.Details.Page_Count > 0
                then Parts.Page_Status (Item) else "Captured " & Parts.Day (At_Time)));
            Displays.Show_Fetch (Item);
         when Failed =>
            Labels.Set_Text
              (Item.Status, Labels.Fitted ("Failed: " & Detail));
      end case;
   end Apply_Capture;

   procedure Apply_Origin (Item : in out Window; To : Items.Origins) is
      Is_File : constant Boolean := To = Items.Local;
   begin
      Item.Details.Origin := To;
      --  A file's path is chosen, not typed: pressing it asks to choose
      --  another (see Listen).
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Body_Text).all, Is_File);
      Editors.Set_Icon (Item.Body_Text, (if Is_File then Icon_Set.Document else Icon_Set.Link));
      Editors.Set_Placeholder (Item.Body_Text, (if Is_File then "File" else "https://"));
      Displays.Show_Mode (Item);
      if Item.Details.Captured_At = 0 then
         Apply_Capture (Item, Waiting);
      end if;
   end Apply_Origin;

end Items.Windows.Fetching;
