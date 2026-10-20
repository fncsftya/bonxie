with Items.Sources;
with Pomarine.Text_Areas;
with Items.Windows.Builder;
with Items.Windows.Displays;
with Items.Windows.Fetching;
with Items.Windows.Metrics;
with Items.Windows.Parts;
with Items.Windows.Speaking;
with Items.Windows.Syncing;

package body Items.Windows is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Sliders renames Pomarine.Widgets.Sliders;
   package Views renames Pomarine.Widgets.Page_Views;

   use type Widgets.Clipboard_Access;

   pragma Assert (Items.Marks.Max_Marks = Pomarine.Widgets.Pictures.Max_Marks);
   pragma Assert (Items.Marks.Max_Marks = Pomarine.Widgets.Page_Views.Max_Marks);

   function Count_Words (Of_Text : String) return Natural is
      Total  : Natural := 0;
      Inside : Boolean := False;
   begin
      for C of Of_Text loop
         if C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Inside := False;
         elsif not Inside then
            Inside := True;
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Count_Words;

   procedure Set_Shared
     (Item   : in out Window;
      Shared : not null Shared_Access) is
   begin
      Frames.Share_Title (Item.Chrome, Shared);
      Editors.Set_Shared (Item.Body_Text, Shared);
      Editors.Set_Shared (Item.Text_View, Shared);
   end Set_Shared;

   function Is_Assigned (Item : Window) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Window; To : Pomarine.Themes.Slot) is
   begin
      Frames.Set_Tag (Item.Chrome, To);
   end Set_Tag;

   procedure Set_Outline_Link
     (Item   : in out Window;
      Linked : Boolean;
      Ink    : Pomarine.Themes.Slot;
      Open   : Boolean) is
   begin
      if Item.Details.Kind = Note then
         if Linked then
            Frames.Set_Tag (Item.Chrome, Ink);
         end if;
         Frames.Set_Tag_Visible (Item.Chrome, Linked);
         Buttons.Set_Selected (Item.Outline_Button, Open);
      end if;
   end Set_Outline_Link;

   function Outline_Box (Item : Window) return Items.Frame is
     ((Left   => Widgets.Left_Of (Item.Outline_Button),
       Top    => Widgets.Top_Of (Item.Outline_Button),
       Width  => Widgets.Width_Of (Item.Outline_Button),
       Height => Widgets.Height_Of (Item.Outline_Button)));

   function Details (Item : Window) return Items.Info is (Item.Details);

   function Text (Item : Window) return String is
     (Docs.Whole (Item.Content_Doc));

   function Words (Item : Window) return Natural is (Item.Word_Count);

   function Title_Document
     (Item : in out Window) return Texts.Documents.Document_Access is
     (Item.Title_Doc'Unchecked_Access);

   function Content_Document
     (Item : in out Window) return Texts.Documents.Document_Access is
     (Item.Content_Doc'Unchecked_Access);

   procedure Hold_Typing (Item : in out Window; To : Boolean) is
   begin
      Item.Held := To;
   end Hold_Typing;

   function Marks_Version (Item : Window) return Natural is
     (Parts.Shown_Marks_Version (Item));

   function Is_Marking (Item : Window) return Boolean is
     (if Item.Paged then Views.Is_Marking (Item.Pages)
      else Pomarine.Widgets.Pictures.Is_Marking (Item.Picture));

   procedure Get_Marks (Item : Window; Into : out Items.Marks.Mark_List) is
   begin
      if Item.Paged then
         Into.Count := Views.Mark_Count (Item.Pages);
         for Index in 1 .. Into.Count loop
            declare
               Each : constant Views.Mark := Views.Mark_At (Item.Pages, Index);
            begin
               Into.Marks (Index) :=
                 (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => Each.Page);
            end;
         end loop;
         return;
      end if;
      Into.Count := Pomarine.Widgets.Pictures.Mark_Count (Item.Picture);
      for Index in 1 .. Into.Count loop
         declare
            Each : constant Pomarine.Widgets.Pictures.Mark :=
              Pomarine.Widgets.Pictures.Mark_At (Item.Picture, Index);
         begin
            Into.Marks (Index) :=
              (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => 1);
         end;
      end loop;
   end Get_Marks;

   function Status (Item : Window) return String is
     (Labels.Text (Item.Status));

   function Tool (Item : Window) return Pomarine.Widgets.Pictures.Tools is
     (if Item.Paged then Views.Tool (Item.Pages)
      else Pomarine.Widgets.Pictures.Tool (Item.Picture));

   function Mark_Count (Item : Window) return Natural is
     (if Item.Paged then Views.Mark_Count (Item.Pages)
      else Pomarine.Widgets.Pictures.Mark_Count (Item.Picture));

   procedure Select_Tool
     (Item : in out Window; To : Pomarine.Widgets.Pictures.Tools) is
   begin
      Pomarine.Widgets.Pictures.Set_Tool (Item.Picture, To);
      Views.Set_Tool (Item.Pages, To);
      Buttons.Set_Selected
        (Item.Cursor_Button, To = Pomarine.Widgets.Pictures.Pointer);
      Buttons.Set_Selected
        (Item.Marker_Button, To = Pomarine.Widgets.Pictures.Highlighter);
      Buttons.Set_Selected
        (Item.Eraser_Button, To = Pomarine.Widgets.Pictures.Eraser);
   end Select_Tool;

   procedure Set_Marks (Item : in out Window; Kept : Items.Marks.Mark_List) is
      Shown  : Pomarine.Widgets.Pictures.Mark_Array (1 .. Kept.Count);
      Paged  : Views.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Marks.Mark renames Kept.Marks (Index);
         begin
            Shown (Index) :=
              Pomarine.Widgets.Pictures.Clamped_Mark
                (Each.Left, Each.Right, Each.Y);
            Paged (Index) := Views.Clamped_Mark (Each.Left, Each.Right, Each.Y, Each.Page);
         end;
      end loop;
      Pomarine.Widgets.Pictures.Set_Marks (Item.Picture, Shown);
      Views.Set_Marks (Item.Pages, Paged);
      Item.Marks_Saved := Parts.Shown_Marks_Version (Item);
   end Set_Marks;

   procedure Set_Recognized
     (Item : in out Window; Found : Vision.Result) is
   begin
      Item.Recognized := Found;
      Pomarine.Widgets.Pictures.Set_Words
        (Item.Picture, Item.Recognized'Unchecked_Access);
   end Set_Recognized;

   function Is_Paged (Item : Window) return Boolean is
     (Item.Paged);

   function Shows_Picture (Item : Window) return Boolean is
     (Item.Paged or else Pomarine.Widgets.Pictures.File_Name (Item.Picture) /= "");

   function Document_Page (Item : Window) return Natural is
     (if Item.Paged and then Views.Is_Settled (Item.Pages)
      then Views.Current_Page (Item.Pages) else 0);

   procedure Go_To_Page (Item : in out Window; Page : Positive) is
   begin
      Views.Show_Page (Item.Pages, Page);
   end Go_To_Page;

   function Recognized_Count (Item : Window) return Natural is
     (if Item.Paged then Views.Word_Count (Item.Pages) else Item.Recognized.Count);

   function Selected_Text (Item : Window) return String is
     (if Item.Paged then Views.Selected_Text (Item.Pages)
      else Pomarine.Widgets.Pictures.Selected_Text (Item.Picture));

   procedure Set_Title_Text (Item : in out Window; To : String) is
   begin
      Docs.Replace
        (Item.Title_Doc, (Paragraph => 1, Index => 1),
         Docs.Text_End (Item.Title_Doc), To);
      --  Poll shows it, as it does what is typed.
   end Set_Title_Text;

   procedure Set_Progress (Item : in out Window; To : Float) is
   begin
      Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, To);
   end Set_Progress;

   function Selected_Shown_Text (Item : Window) return String is
     (Pomarine.Text_Areas.Selected_Text
        (Editors.Area (Item.Text_View'Unrestricted_Access.all).all));
   --  (Area takes the editor to change; looking does not.)

   function Shown_Text (Item : Window) return String is
     (Docs.Whole (Item.Text_Doc));

   procedure Set_Link (Item : in out Window; To : String) is
   begin
      Docs.Replace
        (Item.Content_Doc, (Paragraph => 1, Index => 1),
         Docs.Text_End (Item.Content_Doc), To);
      --  Poll shows it, as it does what is typed.
   end Set_Link;

   procedure Show_Text (Item : in out Window; File : String; At_Time : Projects.Seconds) is
   begin
      Item.Details.Captured_At := At_Time;
      Parts.Clear_Recognized (Item);
      Pomarine.Widgets.Pictures.Clear_Marks (Item.Picture);
      Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Docs.Load (Item.Text_Doc, Items.Sources.Read_Text (File));
      Widgets.Set_Visible (Item.Progress, False);
      Displays.Show_Mode (Item);
      Labels.Set_Text (Item.Status, "Captured " & Parts.Day (At_Time));
   end Show_Text;

   procedure Set_Zoom (Item : in out Window; To : Float) is
   begin
      if To /= Item.Details.Zoom then
         Item.Details.Zoom := To;
         Item.Zoom_Dirty := True;
      end if;
      Pomarine.Widgets.Pictures.Set_Zoom (Item.Picture, To);
      Views.Set_Zoom (Item.Pages, To);
      Sliders.Set_Value (Item.Zoom_Slider, Items.Sources.To_Slider (To));
      Buttons.Set_Label (Item.Zoom_Button, Items.Sources.Percent (To));
      for Which in Item.Menu_Buttons'Range loop
         Buttons.Set_Selected
           (Item.Menu_Buttons (Which), abs (Metrics.Preset_Zooms (Which) - To) < 0.005);
      end loop;
   end Set_Zoom;

   function Box (Item : Window) return Items.Frame is
     ((Left   => Frames.Left_Of (Item.Chrome),
       Top    => Frames.Top_Of (Item.Chrome),
       Width  => Frames.Width_Of (Item.Chrome),
       Height => Frames.Height_Of (Item.Chrome)));

   function Owns (Item : Window; Hit : Pomarine.Widgets.Widget_Access)
     return Boolean is (Frames.Owns (Item.Chrome, Hit));

   function Text_Contains (Item : Window; X, Y : Float) return Boolean is
     (Widgets.Contains (Item.Body_Text, X, Y));

   function Over_Text_Selection
     (Item : in out Window; X, Y : Float) return Boolean is
     (Pomarine.Text_Areas.Is_Over_Selection
        (Editors.Area (Item.Body_Text).all, X, Y));

   procedure Put_Caret (Item : in out Window; X, Y : Float) is
      Area : Pomarine.Text_Areas.Text_Area renames Editors.Area (Item.Body_Text).all;
   begin
      Widgets.Focus (Item.Body_Text);
      Pomarine.Text_Areas.Click (Area, X, Y);
      Pomarine.Text_Areas.Release (Area);
   end Put_Caret;

   procedure Edit_Text (Item : in out Window; Act : Text_Acts) is
      Area  : Pomarine.Text_Areas.Text_Area renames
        Editors.Area (Item.Body_Text).all;
      Board : constant Widgets.Clipboard_Access :=
        Widgets.Clipboard (Item.Body_Text);
   begin
      if Act = Select_All then
         Pomarine.Text_Areas.Select_All (Area);
      elsif Board /= null then
         case Act is
            when Copy =>
               Pomarine.Text_Areas.Copy (Area, Board.all);
            when Cut =>
               Pomarine.Text_Areas.Cut (Area, Board.all);
            when Paste =>
               Pomarine.Text_Areas.Paste (Area, Board.all);
            when Select_All =>
               null;
         end case;
      end if;
   end Edit_Text;

   function Picture_Contains (Item : Window; X, Y : Float) return Boolean is
     (if Item.Paged then Widgets.Contains (Item.Pages, X, Y) else Widgets.Contains (Item.Picture, X, Y));

   function Over_Picture_Selection
     (Item : Window; X, Y : Float) return Boolean is
     (if Item.Paged then Views.Is_Over_Selection (Item.Pages, X, Y)
      else Pictures.Is_Over_Selection (Item.Picture, X, Y));

   function Has_Words (Item : Window) return Boolean is
     (if Item.Paged then Views.Has_Words (Item.Pages) else Pictures.Has_Words (Item.Picture));

   procedure Select_All_Words (Item : in out Window) is
   begin
      if Item.Paged then
         Views.Select_All (Item.Pages);
      else
         Pictures.Select_All (Item.Picture);
      end if;
   end Select_All_Words;

   procedure Copy_Words (Item : Window) is
   begin
      if Item.Paged then
         Views.Copy (Item.Pages);
      else
         Pictures.Copy (Item.Picture);
      end if;
   end Copy_Words;

   function Is_Hovered (Item : Window) return Boolean is
     (Item.Assigned and then Item.Details.State = Open
      and then Frames.Is_Hovered (Item.Chrome));

   function Dictation (Item : Window) return Dictations is
     (Item.Dictating);

   procedure Set_State (Item : in out Window; To : States) is
   begin
      Item.Details.State := To;
      if To /= Open then
         Select_Tool (Item, Pomarine.Widgets.Pictures.Pointer);
         Widgets.Set_Visible (Item.Zoom_Menu, False);
         Pomarine.Widgets.Pictures.Unload (Item.Picture);
         Views.Unload (Item.Pages);
      end if;
      Frames.Set_Shown (Item.Chrome, To = Open, To = Minimized);
      Item.Was_Used := False;
   end Set_State;

   procedure Warm (Item : in out Window) is
   begin
      Pomarine.Widgets.Pictures.Load_Soon
        (Item.Picture, Urgent => Item.Details.State = Open);
   end Warm;

   procedure Assign
     (Item       : in out Window;
      Of_Item    : Items.Info;
      Saved_Text : String;
      Picture_File : String := "") is
   begin
      Item.Assigned := True;
      Item.Details := Of_Item;
      Docs.Load
        (Item.Title_Doc, Projects.Titles.To_String (Of_Item.Title));
      Docs.Load_Stored (Item.Content_Doc, Saved_Text);
      Item.Dictating := Silent;
      Item.Live_Shown := False;
      Item.Live_Lost := False;
      Frames.Attach_Title (Item.Chrome, Item.Title_Doc'Unchecked_Access);
      Editors.Attach (Item.Body_Text, Item.Content_Doc'Unchecked_Access);
      Docs.Load (Item.Text_Doc, "");
      Editors.Attach (Item.Text_View, Item.Text_Doc'Unchecked_Access);
      Item.Title_Saved := Docs.State (Item.Title_Doc);
      Item.Title_Seen := Item.Title_Saved;
      Item.Content_Saved := Docs.State (Item.Content_Doc);
      Item.Content_Seen := Item.Content_Saved;
      Item.Frame_Dirty := False;
      Item.Zoom_Dirty := False;
      Item.Scroll_Seen := Of_Item.Scroll;
      Item.Across_Seen := Of_Item.Scroll_Across;
      Item.Scroll_At := 0;
      Item.Scroll_Pending := False;
      Frames.Reset_Title_Edit (Item.Chrome);
      Displays.Show_Title (Item);
      Displays.Show_Kind (Item);
      Parts.Clear_Recognized (Item);
      Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Pomarine.Widgets.Pictures.Clear_Marks (Item.Picture);
      Item.Marks_Saved := Parts.Shown_Marks_Version (Item);
      Select_Tool (Item, Pomarine.Widgets.Pictures.Pointer);
      if Of_Item.Kind = Source then
         Fetching.Apply_Origin (Item, Of_Item.Origin);
         Set_Zoom (Item, Of_Item.Zoom);
         Item.Zoom_Dirty := False;
         Item.Content_Version := Docs.Current (Item.Content_Doc);
         if Of_Item.Captured_At > 0 and then Picture_File /= "" then
            if Parts.Is_Text_Source (Item) then
               Show_Text (Item, Picture_File, Of_Item.Captured_At);
            else
               Fetching.Apply_Capture
                 (Item, Ready, Picture_File, At_Time => Of_Item.Captured_At);
            end if;
         else
            Fetching.Apply_Capture (Item, Waiting);
         end if;
         Pomarine.Widgets.Pictures.Scroll_To
           (Item.Picture, Float'Min (1.0, Of_Item.Scroll));
         Pomarine.Widgets.Pictures.Scroll_Across_To
           (Item.Picture, Float'Min (1.0, Of_Item.Scroll_Across));
         if Item.Paged then
            Views.Scroll_To (Item.Pages, Float'Min (1.0, Of_Item.Scroll));
            Views.Scroll_Across_To (Item.Pages, Float'Min (1.0, Of_Item.Scroll_Across));
         end if;
      else
         Displays.Show_Words (Item);
         Item.Scroll_Pending := Of_Item.Scroll > 0.0;
      end if;
      Set_State (Item, Of_Item.State);
      if Item.Placed_Once then
         Place (Item, Item.Zoom, Item.Origin_X, Item.Origin_Y);
      end if;
   end Assign;

   procedure Release (Item : in out Window) is
   begin
      Parts.Clear_Recognized (Item);
      Pomarine.Widgets.Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Pomarine.Widgets.Pictures.Unload (Item.Picture);
      Frames.Set_Shown (Item.Chrome, False, False);
      Item.Assigned := False;
      Item.Frame_Dirty := False;
      Item.Zoom_Dirty := False;
      Item.Scroll_Pending := False;
      Item.Was_Used := False;
      Item.Dictating := Silent;
      Item.Live_Shown := False;
      Item.Live_Lost := False;
   end Release;

   procedure Place
     (Item : in out Window; Zoom, Origin_X, Origin_Y : Float)
   is
      Where  : Items.Frame renames Item.Details.Where;
      Pixels : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
   begin
      Item.Zoom := Zoom;
      Item.Origin_X := Origin_X;
      Item.Origin_Y := Origin_Y;
      Item.Placed_Once := True;
      if Item.Assigned and then Item.Details.State = Open then
         Displays.Fit_Zoom (Item);
         --  On whole pixels, so that its edges, and the borders in them,
         --  are the same wherever it is.
         Frames.Place
           (Item.Chrome,
            Float'Rounding ((Origin_X + Where.Left * Zoom) * Pixels),
            Float'Rounding ((Origin_Y + Where.Top * Zoom) * Pixels),
            Float'Rounding (Where.Width * Zoom * Pixels),
            Float'Rounding (Where.Height * Zoom * Pixels));
         --  The link is not zoomed, nor is the title.
         Editors.Set_Zoom
           (Item.Body_Text,
            (if Item.Details.Kind = Source then 1.0 else Zoom));
      end if;
   end Place;

   procedure Bring_To_Front (Item : in out Window) is
   begin
      Frames.Raise_To_Front (Item.Chrome);
   end Bring_To_Front;

   function Is_Editing_Title (Item : Window) return Boolean is
     (Frames.Is_Editing_Title (Item.Chrome));

   procedure Focus_Text (Item : in out Window) is
   begin
      Widgets.Focus (Item.Body_Text);
   end Focus_Text;

   function Is_Dragging (Item : Window) return Boolean is
     (Frames.Is_Dragging (Item.Chrome));

   procedure Build
     (Item    : in out Window;
      Canvas  : in out Pomarine.Widgets.Widget'Class;
      Dock    : in out Pomarine.Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float) renames Builder.Make_Parts;

   procedure Set_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0) renames Fetching.Apply_Capture;

   procedure Set_Origin (Item : in out Window; To : Items.Origins) renames Fetching.Apply_Origin;

   procedure Set_Pages
     (Item : in out Window; Document : String; Page, Count : Natural) renames Fetching.Apply_Pages;

   procedure Set_Dictation
     (Item   : in out Window;
      To     : Dictations;
      Detail : String := "") renames Speaking.Change;

   procedure Set_Level (Item : in out Window; To : Float) renames Speaking.Show_Level;

   procedure Add_Dictation (Item : in out Window; Said : String) renames Speaking.Append_Said;

   procedure Set_Live_Dictation (Item : in out Window; Said : String; Settled : Natural := 0)
     renames Speaking.Show_Live;

   procedure Update (Item : in out Window) renames Syncing.Sync;

   procedure Flush
     (Item  : in out Window;
      Store : in out Projects.Store;
      Now   : SDL3.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean) renames Syncing.Keep;

end Items.Windows;
