with Pomarine.Text_Areas;
with Items.Windows.Displays;
with Items.Windows.Parts;

package body Items.Windows.Syncing is

   package Widgets renames Pomarine.Widgets;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;
   package Sliders renames Pomarine.Widgets.Sliders;

   procedure Use_Window (Item : in out Window) is
      M    : Items.Models.Item renames Item.Model.all;
      Used : Boolean;
   begin
      if Items.Models.Scroll_Pending (M)
        and then Items.Models.Details (M).State = Open
        and then Widgets.Width_Of (Item.Body_Text) > 0.0
      then
         Pomarine.Text_Areas.Scroll_To
           (Editors.Area (Item.Body_Text).all, Items.Models.Details (M).Scroll);
         Widgets.Invalidate (Item.Body_Text);
         Items.Models.Scrolled (M, Parts.Scroll_Of (Item));
      end if;

      --  Raised when it starts to be used.
      Used := Frames.Is_Dragging (Item.Chrome)
        or else Sliders.Is_Dragging (Item.Zoom_Slider)
        or else Frames.Is_Editing_Title (Item.Chrome)
        or else Widgets.Has_Focus (Item.Body_Text);
      if Used and then not Item.Was_Used and then Items.Models.Details (M).State = Open then
         Frames.Raise_To_Front (Item.Chrome);
      end if;
      Item.Was_Used := Used;
      --  A ring round the window being typed in.
      Frames.Set_Ring
        (Item.Chrome,
         Frames.Is_Editing_Title (Item.Chrome)
         or else Widgets.Has_Focus (Item.Body_Text));
      Displays.Show_Status (Item);
   end Use_Window;

   procedure Tell_Model (Item : in out Window) is
      M       : Items.Models.Item renames Item.Model.all;
      Details : constant Items.Info := Items.Models.Details (M);
      Source  : constant Boolean := Details.Kind = Items.Source;
      Marking : constant Boolean := Source and then Is_Marking (Item);
      Opened  : constant Boolean := Details.State = Items.Open;
      Scroll  : constant Float := (if Opened then Parts.Scroll_Of (Item) else Details.Scroll);
      Across  : constant Float := (if Opened then Parts.Across_Of (Item) else Details.Scroll_Across);
   begin
      Items.Models.Report
        (M,
         (Dragging => Frames.Is_Dragging (Item.Chrome),
          Sizing   => Frames.Is_Sizing (Item.Chrome),
          Zooming  => Sliders.Is_Dragging (Item.Zoom_Slider),
          Typing   => Frames.Title_Has_Focus (Item.Chrome) or else Widgets.Has_Focus (Item.Body_Text),
          Marking  => Marking,
          Scroll   => Scroll,
          Across   => Across,
          Pending  => Items.Models.Scroll_Pending (M)));
      --  What was marked on the picture.
      if Source and then not Marking
        and then Parts.Shown_Marks_Version (Item) /= Items.Models.Marks_Reported (M)
      then
         declare
            Made    : Items.Marks.Mark_List;
            Version : constant Natural := Parts.Shown_Marks_Version (Item);
         begin
            Get_Marks (Item, Made);
            Items.Models.Report_Marks (M, Made, Version);
         end;
      end if;
   end Tell_Model;

end Items.Windows.Syncing;
