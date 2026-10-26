with Pomarine.Marks;
with Pomarine.Text_Areas;
with Items.Windows.Builder;
with Items.Windows.Handlers;
with Items.Windows.Displays;
with Items.Windows.Parts;
with Items.Windows.Speaking;
with Items.Windows.Syncing;

package body Items.Windows is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Views renames Pomarine.Widgets.Page_Views;
   package Versions renames Pomarine.View_Models;

   use type Widgets.Clipboard_Access;
   use type Docs.Version;

   function Is_Assigned (Item : Window) return Boolean is
     (Item.Model /= null and then Items.Models.Is_Assigned (Item.Model.all));

   procedure Mount_Search_Bar
     (Item : in out Window; Screen : in out Pomarine.UI.View; Content : Pomarine.UI.Layout) is
   begin
      Pomarine.UI.Mount_Before (Screen, Frames.Content_End (Item.Chrome).all, Content);
   end Mount_Search_Bar;

   function Searchable (Item : Window) return Boolean is
     (Is_Assigned (Item) and then Items.Models.Details (Item.Model.all).State = Open and then
       (Items.Models.Details (Item.Model.all).Kind /= Source or else Items.Models.Is_Text_Source (Item.Model.all)
        or else Items.Models.Is_Paged (Item.Model.all)
        or else (Items.Models.Details (Item.Model.all).Origin = Remote
                 and then Items.Models.Recognized (Item.Model.all).Count > 0)));

   procedure Search (Item : in out Window; Term : String) is
      M : Items.Models.Item renames Item.Model.all;
   begin
      if Items.Models.Details (M).Kind /= Source then
         Pomarine.Text_Areas.Search (Editors.Area (Item.Body_Text).all, Term);
         Widgets.Invalidate (Item.Body_Text);
      elsif Items.Models.Is_Text_Source (M) then
         Pomarine.Text_Areas.Search (Editors.Area (Item.Text_View).all, Term);
         Widgets.Invalidate (Item.Text_View);
      elsif Items.Models.Is_Paged (M) then
         Views.Search (Item.Pages, Term);
      else
         Pictures.Search (Item.Picture, Term);
      end if;
   end Search;

   procedure Search_Step (Item : in out Window; Backwards : Boolean := False) is
      M : Items.Models.Item renames Item.Model.all;
   begin
      if Items.Models.Details (M).Kind /= Source then
         Pomarine.Text_Areas.Search_Step (Editors.Area (Item.Body_Text).all, Backwards);
         Widgets.Invalidate (Item.Body_Text);
      elsif Items.Models.Is_Text_Source (M) then
         Pomarine.Text_Areas.Search_Step (Editors.Area (Item.Text_View).all, Backwards);
         Widgets.Invalidate (Item.Text_View);
      elsif Items.Models.Is_Paged (M) then
         Views.Search_Step (Item.Pages, Backwards);
      else
         Pictures.Search_Step (Item.Picture, Backwards);
      end if;
   end Search_Step;

   function Search_Busy (Item : Window) return Boolean is
     (Items.Models.Is_Paged (Item.Model.all) and then Views.Search_Busy (Item.Pages));

   function Search_Count (Item : Window) return Natural is
     (if Items.Models.Details (Item.Model.all).Kind /= Source then Editors.Search_Count (Item.Body_Text)
      elsif Items.Models.Is_Text_Source (Item.Model.all) then Editors.Search_Count (Item.Text_View)
      elsif Items.Models.Is_Paged (Item.Model.all) then Views.Search_Count (Item.Pages)
      else Pictures.Search_Count (Item.Picture));

   function Search_Current (Item : Window) return Natural is
     (if Items.Models.Details (Item.Model.all).Kind /= Source then Editors.Search_Current (Item.Body_Text)
      elsif Items.Models.Is_Text_Source (Item.Model.all) then Editors.Search_Current (Item.Text_View)
      elsif Items.Models.Is_Paged (Item.Model.all) then Views.Search_Current (Item.Pages)
      else Pictures.Search_Current (Item.Picture));

   procedure Set_Shared
     (Item   : in out Window;
      Shared : not null Shared_Access) is
   begin
      Frames.Share_Title (Item.Chrome, Shared);
      Editors.Set_Shared (Item.Body_Text, Shared);
      Editors.Set_Shared (Item.Text_View, Shared);
   end Set_Shared;

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
      if Items.Models.Details (Item.Model.all).Kind = Note then
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

   procedure Set_Dictation_Editor
     (Item : in out Window; To : access Pomarine.Widgets.Editors.Editor) is
   begin
      Item.Dictate_In := To;
   end Set_Dictation_Editor;

   function Marks_Version (Item : Window) return Natural is
     (Parts.Shown_Marks_Version (Item));

   function Is_Marking (Item : Window) return Boolean is
     (if Items.Models.Is_Paged (Item.Model.all) then Views.Is_Marking (Item.Pages)
      else Pomarine.Widgets.Pictures.Is_Marking (Item.Picture));

   procedure Get_Marks (Item : Window; Into : out Items.Marks.Mark_List) is
   begin
      Into.Past := (if Items.Models.Is_Paged (Item.Model.all) then Views.History_Of (Item.Pages)
                    else Pomarine.Widgets.Pictures.History_Of (Item.Picture));
      if Items.Models.Is_Paged (Item.Model.all) then
         Into.Count := Views.Mark_Count (Item.Pages);
         Pomarine.Marks.Reserve (Into.Marks, Into.Count);
         for Index in 1 .. Into.Count loop
            declare
               Each : constant Views.Mark := Views.Mark_At (Item.Pages, Index);
            begin
               Into.Marks.Data (Index) :=
                 (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => Each.Page, Trace => Each.Trace);
            end;
         end loop;
         return;
      end if;
      Into.Count := Pomarine.Widgets.Pictures.Mark_Count (Item.Picture);
      Pomarine.Marks.Reserve (Into.Marks, Into.Count);
      for Index in 1 .. Into.Count loop
         declare
            Each : constant Pomarine.Widgets.Pictures.Mark :=
              Pomarine.Widgets.Pictures.Mark_At (Item.Picture, Index);
         begin
            Into.Marks.Data (Index) :=
              (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => 1, Trace => Each.Trace);
         end;
      end loop;
   end Get_Marks;

   function Recognized_Count (Item : Window) return Natural is
     (if Items.Models.Is_Paged (Item.Model.all) then Views.Word_Count (Item.Pages)
      else Items.Models.Recognized (Item.Model.all).Count);

   function Document_Page (Item : Window) return Natural is
     (if Items.Models.Is_Paged (Item.Model.all) and then Views.Is_Settled (Item.Pages)
      then Views.Current_Page (Item.Pages) else 0);

   procedure Go_To_Page (Item : in out Window; Page : Positive) is
   begin
      Views.Show_Page (Item.Pages, Page);
   end Go_To_Page;

   function Selected_Text (Item : Window) return String is
     (if Items.Models.Is_Paged (Item.Model.all) then Views.Selected_Text (Item.Pages)
      else Pomarine.Widgets.Pictures.Selected_Text (Item.Picture));

   function Selected_Shown_Text (Item : Window) return String is
     (Pomarine.Text_Areas.Selected_Text
        (Editors.Area (Item.Text_View'Unrestricted_Access.all).all));
   --  (Area takes the editor to change; looking does not.)

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
     (if Items.Models.Is_Paged (Item.Model.all) then Widgets.Contains (Item.Pages, X, Y)
      else Widgets.Contains (Item.Picture, X, Y));

   function Over_Picture_Selection
     (Item : Window; X, Y : Float) return Boolean is
     (if Items.Models.Is_Paged (Item.Model.all) then Views.Is_Over_Selection (Item.Pages, X, Y)
      else Pictures.Is_Over_Selection (Item.Picture, X, Y));

   function Has_Words (Item : Window) return Boolean is
     (if Items.Models.Is_Paged (Item.Model.all) then Views.Has_Words (Item.Pages)
      else Pictures.Has_Words (Item.Picture));

   procedure Select_All_Words (Item : in out Window) is
   begin
      if Items.Models.Is_Paged (Item.Model.all) then
         Views.Select_All (Item.Pages);
      else
         Pictures.Select_All (Item.Picture);
      end if;
   end Select_All_Words;

   procedure Copy_Words (Item : Window) is
   begin
      if Items.Models.Is_Paged (Item.Model.all) then
         Views.Copy (Item.Pages);
      else
         Pictures.Copy (Item.Picture);
      end if;
   end Copy_Words;

   function Is_Hovered (Item : Window) return Boolean is
     (Is_Assigned (Item) and then Items.Models.Details (Item.Model.all).State = Open
      and then Frames.Is_Hovered (Item.Chrome));

   procedure Warm (Item : in out Window) is
   begin
      Pomarine.Widgets.Pictures.Load_Soon
        (Item.Picture, Urgent => Items.Models.Details (Item.Model.all).State = Open);
   end Warm;

   function Gesture (Item : Window) return Gestures is (Item.Dragged);

   procedure Place (Item : in out Window) is
      Pixels   : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
      Zoom     : constant Float := Item.Looking.Zoom;
      Origin_X : constant Float := Item.Looking.Origin_X;
      Origin_Y : constant Float := Item.Looking.Origin_Y;
   begin
      Item.Placed_Once := True;
      if Is_Assigned (Item) and then Items.Models.Details (Item.Model.all).State = Open then
         declare
            Details : constant Items.Info := Items.Models.Details (Item.Model.all);
            Where   : Items.Frame renames Details.Where;
         begin
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
               (if Details.Kind = Source then 1.0 else Zoom));
         end;
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

   overriding procedure Requested (Self : in out Command_Effects; What : Item_Window_VM.Command; Index : Natural) is
   begin
      Handlers.Perform (Self.Owner.all, What, Index);
   end Requested;

   overriding procedure Changed (Self : in out Command_Effects) is
   begin
      Show (Self.Owner.all);
   end Changed;

   procedure Build
     (Item    : in out Window;
      Model   : not null access Items.Models.Item;
      Looking : not null access constant Items.Models.Camera;
      Canvas  : in out Pomarine.Widgets.Widget'Class;
      Dock    : in out Pomarine.Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float) is
   begin
      Item.Model := Model.all'Unrestricted_Access;
      Item.Looking := Looking.all'Unrestricted_Access;
      Item.Control_Effects.Owner := Item'Unrestricted_Access;
      Item_Window_VM.Initialize (Item.Controls, Model, Item.Control_Effects'Access);
      Builder.Make_Parts (Item, Canvas, Dock, Bar, Density);
   end Build;

   procedure Show (Item : in out Window) is
   begin
      if not Is_Assigned (Item) then
         return;
      end if;
      declare
         M : Items.Models.Item renames Item.Model.all;
      begin
         Items.Models.Refresh (M);
         if Docs.Current (Items.Models.Title_Document (M).all) /= Item.Title_Shown then
            Displays.Show_Title (Item);
         end if;
         if Versions.Changed (Item.Seen_Picture, Items.Models.Picture_Version (M)) then
            Displays.Show_Picture (Item);
         end if;
         if Versions.Changed (Item.Seen_Words, Items.Models.Recognized_Version (M)) then
            Displays.Show_Words (Item);
         end if;
         if Versions.Changed (Item.Seen_Marks, Items.Models.Marks_To_Show (M)) then
            Displays.Show_Marks (Item);
         end if;
         if Versions.Changed (Item.Seen_Look, Items.Models.Look_Version (M)) then
            Displays.Show_Look (Item);
         end if;
         if Versions.Changed (Item.Seen_Shape, Items.Models.Shape_Version (M)) then
            Displays.Show_Mode (Item);
         end if;
         if Versions.Changed (Item.Seen_Zoom, Items.Models.Zoom_Version (M))
           and then Items.Models.Details (M).Kind = Source
         then
            Displays.Show_Zoom (Item);
         end if;
         if Versions.Changed (Item.Seen_Tool, Items.Models.Tool_Version (M)) then
            Displays.Show_Tool (Item);
         end if;
         Item_Window_VM.Poll (Item.Controls);
         Pomarine.UI.Synchronize (Item.UI_Host.Screen.all);
         Displays.Show_Status (Item);
         if Versions.Changed (Item.Seen_Where, Items.Models.Where_Version (M)) then
            Displays.Show_Where (Item);
            if Item.Placed_Once then
               Place (Item);
            end if;
         end if;
      end;
   end Show;

   procedure Assigned (Item : in out Window) is
      Fresh   : Versions.Watch;
      Details : constant Items.Info := Items.Models.Details (Item.Model.all);
   begin
      Item.Seen_Where := Fresh;
      Item.Seen_Picture := Fresh;
      Item.Seen_Words := Fresh;
      Item.Seen_Marks := Fresh;
      Item.Seen_Look := Fresh;
      Item.Seen_Shape := Fresh;
      Item.Seen_Zoom := Fresh;
      Item.Seen_Tool := Fresh;
      --  The documents are loaded again: what edits them starts from the top of what is in them.
      Frames.Attach_Title (Item.Chrome, Items.Models.Title_Document (Item.Model.all));
      Editors.Attach (Item.Body_Text, Items.Models.Content_Document (Item.Model.all));
      Editors.Attach (Item.Text_View, Items.Models.Text_Document (Item.Model.all));
      Frames.Reset_Title_Edit (Item.Chrome);
      Displays.Show_Title (Item);
      Show (Item);
      if Details.Kind = Source then
         Pictures.Scroll_To (Item.Picture, Float'Min (1.0, Details.Scroll));
         Pictures.Scroll_Across_To (Item.Picture, Float'Min (1.0, Details.Scroll_Across));
         if Items.Models.Is_Paged (Item.Model.all) then
            Views.Scroll_To (Item.Pages, Float'Min (1.0, Details.Scroll));
            Views.Scroll_Across_To (Item.Pages, Float'Min (1.0, Details.Scroll_Across));
         end if;
      end if;
   end Assigned;

   procedure Release (Item : in out Window) is
   begin
      if Is_Assigned (Item) then
         Search (Item, "");
      end if;
      Pictures.Set_Words (Item.Picture, null);
      Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Pictures.Unload (Item.Picture);
      Frames.Set_Shown (Item.Chrome, False, False);
      Item.Was_Used := False;
   end Release;

   procedure Update (Item : in out Window) renames Syncing.Use_Window;

   procedure Report (Item : in out Window) renames Syncing.Tell_Model;

   procedure Set_Dictation
     (Item   : in out Window;
      To     : Items.Models.Dictations;
      Detail : String := "") renames Speaking.Change;

   procedure Add_Dictation (Item : in out Window; Said : String) renames Speaking.Append_Said;

   procedure Set_Live_Dictation (Item : in out Window; Said : String; Settled : Natural := 0)
     renames Speaking.Show_Live;

end Items.Windows;
