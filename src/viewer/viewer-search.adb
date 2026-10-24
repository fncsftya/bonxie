with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Pomarine.Line_Texts;
with Pomarine.Icons;
with Icon_Set;
with Pomarine.Themes;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Layouts;
with Viewer.Canvas_Items;
with Viewer.Style;
with Viewer.Writing;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Scrollers;

package body Viewer.Search is
   package Widgets renames Pomarine.Widgets;
   package Fields renames Pomarine.Widgets.Text_Fields;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Docs renames Texts.Documents;
   package Areas renames Pomarine.Text_Areas;
   package Editors renames Pomarine.Widgets.Editors;
   use Ada.Strings.Unbounded;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use type Docs.Version;
   use type Items.Id;
   use type Widgets.Widget_Access;

   procedure Build_Bar (Item : in out Session; In_Window : Boolean := False) is
      use Pomarine.Widgets.Layouts;
      S : Search_State renames Item.Searching;
   begin
      if Widgets.Is_Attached (S.Bar) then
         Widgets.Remove (S.Bar);
      end if;
      if In_Window then
         Items.Windows.Add_Search_Bar (Item.Windows (S.Target), S.Bar);
      else
         Widgets.Add (Item.Toolbar.Project_Panel, S.Bar);
      end if;
      Widgets.Add (S.Bar, S.Field, S.Count, S.Previous);
      Widgets.Add (S.Bar, S.Next, S.Close);
      Set_Layout (S.Bar, Flow => Row, Height => 44.0, Shrink => 0.0, Gap => 8.0, Padding => (others => 6.0));
      Set_Layout (S.Field, Grow => 1.0, Width => 0.0);
      if In_Window then
         Set_Layout (S.Bar, Flow => Row, Height => 36.0, Shrink => 0.0, Gap => 3.0,
                     Padding => (others => 3.0));
      end if;
      Set_Layout (S.Count, Width => (if In_Window then 48.0 else 100.0));
      Set_Layout (S.Previous, Width => (if In_Window then 24.0 else 36.0));
      Set_Layout (S.Next, Width => (if In_Window then 24.0 else 36.0));
      Set_Layout (S.Close, Width => (if In_Window then 24.0 else 36.0));
      Pomarine.Widgets.Panels.Set_Fill (S.Bar, Pomarine.Themes.Strip);
      Fields.Set_Shared (S.Field, Item.Host.Doc_Resources'Unchecked_Access);
      Fields.Configure (S.Field, Pomarine.Line_Texts.Interface_Font, Viewer.Style.Edit_Size);
      Fields.Attach (S.Field, S.Doc'Unchecked_Access);
      Fields.Set_Placeholder (S.Field, "Find in item");
      Buttons.Set_Label (S.Previous, "Previous");
      Buttons.Set_Label (S.Next, "Next");
      Buttons.Set_Label (S.Close, "Close");
      Buttons.Set_Icon (S.Previous, Icon_Set.Back);
      Buttons.Set_Icon (S.Next, Icon_Set.Forward);
      Buttons.Set_Icon (S.Close, Pomarine.Icons.Close);
      Buttons.Set_Focusable (S.Previous, True);
      Buttons.Set_Focusable (S.Next, True);
      Buttons.Set_Focusable (S.Close, True);
      Widgets.Set_Accessible_Name (S.Field, "Find in item");
      Widgets.Set_Accessible_Help (S.Previous, "Previous match (Shift+F3)");
      Widgets.Set_Accessible_Help (S.Next, "Next match (F3)");
      Widgets.Set_Accessible_Help (S.Close, "Close search (Escape)");
      Widgets.Set_Visible (S.Bar, False);
   end Build_Bar;

   procedure Build (Item : in out Session) is
   begin
      Build_Bar (Item);
   end Build;

   procedure Choose_Document (Item : in out Session) is
      S : Search_State renames Item.Searching;
      Before : Natural := 0;
   begin
      S.Rank := 0;
      for Rank in 1 .. S.Documents.Count loop
         declare
            Count : constant Natural := S.Documents (Rank).Matches;
            Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Rank).Text).all;
         begin
            Areas.Search_Choose (Area, 0);
            if S.Current > Before and then S.Current <= Before + Count then
               Areas.Search_Choose (Area, S.Current - Before);
               S.Rank := Rank;
            end if;
            Widgets.Invalidate (Item.Docs.Pages (Rank).Text);
            Before := Before + Count;
         end;
      end loop;
      S.Reveal_Pending := S.Rank > 0;
   end Choose_Document;

   procedure Step (Item : in out Session; Backwards : Boolean := False) is
      S : Search_State renames Item.Searching;
   begin
      if not S.In_Writing then
         Items.Windows.Search_Step (Item.Windows (S.Target), Backwards);
      else
         if S.Total = 0 then
            S.Current := 0;
         elsif Backwards then
            S.Current := (if S.Current <= 1 then S.Total else S.Current - 1);
         else
            S.Current := (if S.Current >= S.Total then 1 else S.Current + 1);
         end if;
         Choose_Document (Item);
      end if;
   end Step;

   procedure Update_Documents (Item : in out Session) is
      S : Search_State renames Item.Searching;
      Term : constant String := Docs.Whole (S.Doc);
      New_Term : constant Boolean := Term /= To_String (S.Term);
      Changed : Boolean := New_Term or else S.Documents.Count /= Item.Reading.Write_Count;
   begin
      Search_Document_Lists.Resize (S.Documents, Item.Reading.Write_Count, (others => <>));
      S.Total := 0;
      for Rank in 1 .. Item.Reading.Write_Count loop
         declare
            Which : constant Items.Slot := Item.Reading.Write_Order (Rank);
            Doc : constant Docs.Document_Access := Items.Windows.Content_Document (Item.Windows (Which));
            Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Rank).Text).all;
            State : Search_Document renames S.Documents (Rank);
            Key : constant Items.Id := Items.Windows.Details (Item.Windows (Which)).Key;
         begin
            pragma Assert (Item.Docs.Pages (Rank).Bound = Which);
            if New_Term or else State.Which /= Which or else State.Key /= Key
              or else State.Revision /= Docs.Current (Doc.all) or else State.Serial /= Docs.Serial (Doc.all)
              or else State.Matches /= Areas.Search_Count (Area)
            then
               Areas.Search (Area, Term);
               State := (Which, Key, Docs.Current (Doc.all), Docs.Serial (Doc.all), Areas.Search_Count (Area));
               Changed := True;
               Widgets.Invalidate (Item.Docs.Pages (Rank).Text);
            end if;
            S.Total := S.Total + State.Matches;
         end;
      end loop;
      S.Term := To_Unbounded_String (Term);
      if Changed then
         S.Current := 0;
         Step (Item);
      end if;
   end Update_Documents;

   procedure Reveal (Item : in out Session) is
      S : Search_State renames Item.Searching;
      X, Y, Wide, High : Float;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if not S.Showing or else not S.In_Writing or else not S.Reveal_Pending then
         return;
      end if;
      pragma Assert (S.Rank in 1 .. Item.Reading.Write_Count);
      if not Widgets.Is_Visible (Item.Docs.Pages (S.Rank).Box) then
         Writing.Select_Directory (Item, 0);
      end if;
      Areas.Search_Box (Editors.Area (Item.Docs.Pages (S.Rank).Text).all, X, Y, Wide, High);
      declare
         Scroll : Pomarine.Widgets.Scrollers.Scroller renames Item.Page_View.Pages_Scroll;
         Top : constant Float := Widgets.Top_Of (Scroll) + 32.0 * Pixels;
         Bottom : constant Float := Widgets.Top_Of (Scroll) + Widgets.Height_Of (Scroll) - 32.0 * Pixels;
      begin
         if Y < Top then
            Pomarine.Widgets.Scrollers.Scroll_To
              (Scroll, Pomarine.Widgets.Scrollers.Offset (Scroll) + (Y - Top) / Pixels);
         elsif Y + High > Bottom then
            Pomarine.Widgets.Scrollers.Scroll_To
              (Scroll, Pomarine.Widgets.Scrollers.Offset (Scroll) + (Y + High - Bottom) / Pixels);
         end if;
      end;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      S.Reveal_Pending := False;
   end Reveal;

   procedure Close (Item : in out Session) is
      S : Search_State renames Item.Searching;
   begin
      if not S.Showing then
         return;
      end if;
      if S.In_Writing then
         for Each of Item.Docs.Pages loop
            if Each.Bound /= 0 then
               Areas.Search (Editors.Area (Each.Text).all, "");
               Widgets.Invalidate (Each.Text);
            end if;
         end loop;
         Search_Document_Lists.Clear (S.Documents);
         S.Total := 0;
         S.Current := 0;
         S.Rank := 0;
         S.Reveal_Pending := False;
      elsif Items.Windows.Is_Assigned (Item.Windows (S.Target))
        and then Items.Windows.Details (Item.Windows (S.Target)).Key = S.Key
      then
         Items.Windows.Search (Item.Windows (S.Target), "");
      end if;
      S.Showing := False;
      Widgets.Set_Visible (S.Bar, False);
   end Close;

   procedure Update (Item : in out Session) is
      S : Search_State renames Item.Searching;
      Clicked : Boolean;
      function Image (N : Natural) return String is
        (Ada.Strings.Fixed.Trim (N'Image, Ada.Strings.Both));
   begin
      if not S.Showing then
         return;
      end if;
      if Item.Nav.Shown /= Project
        or else (if S.In_Writing then Item.Toolbar.Mode /= Write
                 else Item.Toolbar.Mode /= Canvas
                   or else not Items.Windows.Searchable (Item.Windows (S.Target))
                   or else Items.Windows.Details (Item.Windows (S.Target)).Key /= S.Key)
      then
         Close (Item);
         return;
      end if;
      if S.In_Writing then
         Update_Documents (Item);
         Buttons.Take_Click (S.Previous, Clicked);
         if Clicked then
            Step (Item, True);
         end if;
         Buttons.Take_Click (S.Next, Clicked);
         if Clicked then
            Step (Item);
         end if;
         Pomarine.Widgets.Labels.Set_Text (S.Count, Image (S.Current) & " / " & Image (S.Total));
         Buttons.Set_Enabled (S.Previous, S.Total > 0);
         Buttons.Set_Enabled (S.Next, S.Total > 0);
         Buttons.Take_Click (S.Close, Clicked);
         if Clicked then
            Close (Item);
         end if;
         return;
      end if;
      declare
         W : Items.Windows.Window renames Item.Windows (S.Target);
         Term : constant String := Docs.Whole (S.Doc);
         Revision : constant Docs.Version := Docs.Current (Items.Windows.Content_Document (W).all);
      begin
         if Term /= To_String (S.Term) or else Revision /= S.Seen then
            S.Term := To_Unbounded_String (Term);
            S.Seen := Revision;
            Items.Windows.Search (W, Term);
            Items.Windows.Search_Step (W);
         end if;
         Buttons.Take_Click (S.Previous, Clicked);
         if Clicked then
            Items.Windows.Search_Step (W, True);
         end if;
         Buttons.Take_Click (S.Next, Clicked);
         if Clicked then
            Items.Windows.Search_Step (W);
         end if;
         Pomarine.Widgets.Labels.Set_Text
           (S.Count, Image (Items.Windows.Search_Current (W)) & " / " & Image (Items.Windows.Search_Count (W))
            & (if Items.Windows.Search_Busy (W) then " ..." else ""));
         Buttons.Set_Enabled (S.Previous, Items.Windows.Search_Count (W) > 0);
         Buttons.Set_Enabled (S.Next, Items.Windows.Search_Count (W) > 0);
      end;
      Buttons.Take_Click (S.Close, Clicked);
      if Clicked then
         Close (Item);
      end if;
   end Update;

   procedure Handle (Item : in out Session; Event : Pomarine.Events.Event; Handled : out Boolean) is
      S : Search_State renames Item.Searching;
      Focused : constant Widgets.Widget_Access := Widgets.Focus_Of (Item.Root.Widgets);
      Target : Items.Slot := Items.Slot'First;
      Found : Boolean := False;
   begin
      Handled := False;
      if Event.Kind /= Pomarine.Events.Key_Down then
         return;
      end if;
      if S.Showing and then Event.Key = Pomarine.Events.Key_Escape then
         Close (Item);
         Handled := True;
      elsif S.Showing and then Event.Key = Pomarine.Events.Key_F3 then
         Step (Item, Event.Shift);
         Handled := True;
      elsif Event.Command and then Event.Key = Pomarine.Events.Key_F then
         if Item.Toolbar.Mode = Write then
            if not S.Showing then
               Build_Bar (Item);
               S.In_Writing := True;
               S.Showing := True;
               S.Term := Null_Unbounded_String;
               Fields.Set_Placeholder (S.Field, "Find in all documents");
               Widgets.Set_Accessible_Name (S.Field, "Find in all documents");
               Widgets.Set_Visible (S.Bar, True);
            end if;
            Widgets.Focus (S.Field);
            Areas.Select_All (Fields.Area (S.Field).all);
            Update_Documents (Item);
            Handled := True;
            return;
         end if;
         for Row in 1 .. Canvas_Items.Count (Item) loop
            declare
               Which : constant Items.Slot := Canvas_Items.Nth (Item, Row);
               W : Items.Windows.Window renames Item.Windows (Which);
            begin
               if Items.Windows.Searchable (W) then
                  if Focused /= null and then Items.Windows.Owns (W, Focused) then
                     Target := Which;
                     Found := True;
                     exit;
                  elsif Items.Windows.Is_Hovered (W) then
                     Target := Which;
                     Found := True;
                  end if;
               end if;
            end;
         end loop;
         if Found then
            Close (Item);
            S.In_Writing := False;
            Fields.Set_Placeholder (S.Field, "Find in item");
            Widgets.Set_Accessible_Name (S.Field, "Find in item");
            S.Target := Target;
            Build_Bar (Item, In_Window => True);
            S.Key := Items.Windows.Details (Item.Windows (Target)).Key;
            S.Showing := True;
            S.Seen := Docs.Current (Items.Windows.Content_Document (Item.Windows (Target)).all);
            S.Term := To_Unbounded_String (Docs.Whole (S.Doc));
            Items.Windows.Search (Item.Windows (Target), To_String (S.Term));
            Items.Windows.Search_Step (Item.Windows (Target));
            Widgets.Set_Visible (S.Bar, True);
         end if;
         if S.Showing then
            Widgets.Focus (S.Field);
            Pomarine.Text_Areas.Select_All (Fields.Area (S.Field).all);
            Handled := True;
         end if;
      end if;
   end Handle;
end Viewer.Search;
