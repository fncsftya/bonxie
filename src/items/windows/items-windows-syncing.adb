with Items.Records;
with Items.Sources;
with Pomarine.Text_Areas;
with Items.Windows.Displays;
with Items.Windows.Parts;

package body Items.Windows.Syncing is

   package Widgets renames Pomarine.Widgets;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;
   package Sliders renames Pomarine.Widgets.Sliders;

   use type Docs.Version;
   use type Pomarine.Events.Milliseconds;

   procedure Sync (Item : in out Window) is
      Used : Boolean;
   begin
      if Item.Scroll_Pending
        and then Item.Details.State = Open
        and then Widgets.Width_Of (Item.Body_Text) > 0.0
      then
         Pomarine.Text_Areas.Scroll_To
           (Editors.Area (Item.Body_Text).all, Item.Details.Scroll);
         Widgets.Invalidate (Item.Body_Text);
         Item.Scroll_Pending := False;
         Item.Scroll_Seen := Parts.Scroll_Of (Item);
      end if;

      --  What is moved and sized is the handlers' (see Listen); here only
      --  the size the corner asks for, which is the size it has, while it
      --  is not being dragged.
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);

      --  Raised when it starts to be used.
      Used := Is_Dragging (Item)
        or else Sliders.Is_Dragging (Item.Zoom_Slider)
        or else Frames.Is_Editing_Title (Item.Chrome)
        or else Widgets.Has_Focus (Item.Body_Text);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Frames.Raise_To_Front (Item.Chrome);
      end if;
      Item.Was_Used := Used;
      --  A ring round the window being typed in.
      Frames.Set_Ring
        (Item.Chrome,
         Frames.Is_Editing_Title (Item.Chrome)
         or else Widgets.Has_Focus (Item.Body_Text));

      --  What was typed.
      if Docs.Current (Item.Title_Doc) /= Item.Title_Version then
         Displays.Show_Title (Item);
      end if;
      if Docs.Current (Item.Content_Doc) /= Item.Content_Version then
         Displays.Show_Words (Item);
      end if;
   end Sync;

   procedure Keep
     (Item  : in out Window;
      Store : in out Projects.Store;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
   is
      Title_Now   : constant Natural := Docs.State (Item.Title_Doc);
      Content_Now : constant Natural := Docs.State (Item.Content_Doc);
      Typing      : constant Boolean :=
        Frames.Title_Has_Focus (Item.Chrome)
        or else Widgets.Has_Focus (Item.Body_Text)
        or else Item.Held;
   begin
      Wrote := False;
      if Title_Now /= Item.Title_Seen or else Content_Now /= Item.Content_Seen
      then
         Item.Title_Seen := Title_Now;
         Item.Content_Seen := Content_Now;
         Item.Changed_At := Now;
      end if;

      if Item.Frame_Dirty and then not Is_Dragging (Item) then
         Items.Records.Set_Frame
           (Store, Item.Details.Key, Item.Details.Where);
         Item.Frame_Dirty := False;
         Wrote := True;
      end if;

      if Item.Zoom_Dirty
        and then not Sliders.Is_Dragging (Item.Zoom_Slider)
      then
         Items.Sources.Set_Zoom (Store, Item.Details.Key, Item.Details.Zoom);
         Item.Zoom_Dirty := False;
         Wrote := True;
      end if;

      if not Item.Scroll_Pending and then Item.Details.State = Open then
         declare
            Scrolled : constant Float := Parts.Scroll_Of (Item);
            Across   : constant Float := Parts.Across_Of (Item);
         begin
            if Scrolled /= Item.Scroll_Seen or else Across /= Item.Across_Seen
            then
               Item.Scroll_Seen := Scrolled;
               Item.Across_Seen := Across;
               Item.Scroll_At := Now;
            end if;
            if (Scrolled /= Item.Details.Scroll
                or else Across /= Item.Details.Scroll_Across)
              and then (Force or else Now >= Item.Scroll_At + Idle_Delay)
            then
               Items.Records.Set_Scroll
                 (Store, Item.Details.Key, Scrolled, Across);
               Item.Details.Scroll := Scrolled;
               Item.Details.Scroll_Across := Across;
               Wrote := True;
            end if;
         end;
      end if;

      if Item.Details.Kind = Source
        and then Parts.Shown_Marks_Version (Item) /= Item.Marks_Saved
        and then not Is_Marking (Item)
      then
         declare
            Kept : Items.Marks.Mark_List;
         begin
            Get_Marks (Item, Kept);
            Items.Marks.Save_Marks (Store, Item.Details.Key, Kept);
         end;
         Item.Marks_Saved := Parts.Shown_Marks_Version (Item);
         Wrote := True;
      end if;

      if (Title_Now /= Item.Title_Saved
          or else Content_Now /= Item.Content_Saved)
        and then (Force or else not Typing
                  or else Now >= Item.Changed_At + Idle_Delay)
      then
         if Title_Now /= Item.Title_Saved then
            Items.Records.Set_Title
              (Store, Item.Details.Key,
               Projects.Titles.To_String (Item.Details.Title));
            Item.Title_Saved := Title_Now;
         end if;
         if Content_Now /= Item.Content_Saved then
            Items.Records.Set_Content
              (Store, Item.Details.Key, Docs.Stored (Item.Content_Doc));
            Item.Content_Saved := Content_Now;
         end if;
         Wrote := True;
      end if;
   end Keep;

end Items.Windows.Syncing;
