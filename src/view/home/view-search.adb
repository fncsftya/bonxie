with Items.Models;
with Ada.Strings.Unbounded;
with Pomarine.Line_Texts;
with Pomarine.Icons;
with Icon_Set;
with Pomarine.Themes;
with Pomarine.Widgets.Panels;
with Pomarine.Text_Areas;
with Search_UI;
with Pomarine.UI;
with Pomarine.Widgets.Layouts;
with View.Canvas_Items;
with View.Style;
with View.Writing;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Scrollers;

package body View.Search is
   package UI renames Pomarine.UI;
   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
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
   use type Search_VM.Scopes;
   use type Widgets.Widget_Access;

   procedure Build_Bar (Item : in out Session; In_Window : Boolean := False) is
      use Pomarine.Widgets.Layouts;
      S : Search_State renames Item.Searching;
      Bar_Style : constant Layouts.Style :=
        (if In_Window
         then (Flow => Row, Height => 36.0, Shrink => 0.0, Gap => 3.0, Padding => (others => 3.0), others => <>)
         else (Flow => Row, Height => 44.0, Shrink => 0.0, Gap => 8.0, Padding => (others => 6.0), others => <>));
      Wide : constant Float := (if In_Window then 24.0 else 36.0);
   begin
      if Item.Forms (Search_Region).Screen = null then
         Fields.Set_Shared (S.Field, Item.Host.Doc_Resources'Unchecked_Access);
         Fields.Configure (S.Field, Pomarine.Line_Texts.Interface_Font, View.Style.Edit_Size);
         Fields.Attach (S.Field, S.Doc'Unchecked_Access);
         Open (Item.Forms (Search_Region), Item.Root.Widgets'Unchecked_Access, Search_Region);
         declare
            Bound : constant Search_UI.Controls.Context'Class :=
              Search_UI.Controls.Bind (Item.Forms (Search_Region).Screen.all, S.Model'Unrestricted_Access);
            Bar : constant UI.Widget_Handle := Bound.Borrow_Widget (S.Bar);
         begin
            S.Query_Control := Bound.Borrow_Field (S.Field, S.Doc, Search_UI.Query);
            S.Count_Control := Bound.Borrow_Label (S.Count, Search_UI.Summary);
            S.Previous_Control := Bound.Borrow_Button (S.Previous, Search_VM.Previous);
            S.Next_Control := Bound.Borrow_Button (S.Next, Search_VM.Next);
            S.Close_Control := Bound.Borrow_Button (S.Close, Search_VM.Close);
            Bound.Show_When (UI.Any (Bar), Search_UI.Showing);
         end;
      end if;
      declare
         Form : UI.View renames Item.Forms (Search_Region).Screen.all;

         function Button
           (Part : in out Buttons.Button; Control : UI.Button_Handle; Look : Buttons.Settings) return UI.Layout is
         begin
            Buttons.Configure (Part, Look);
            return UI.Place (Control, Width => Layouts.Length_Of (Wide), Exact => True);
         end Button;

         Field    : constant UI.Layout :=
           UI.Place (S.Query_Control, Grow => 1.0, Width => 0.0, Exact => True);
         Counting : constant UI.Layout :=
           UI.Place (S.Count_Control, Width => UI.Layouts.Length_Of (if In_Window then 48.0 else 100.0), Exact => True);
         Back     : constant UI.Layout :=
           Button (S.Previous, S.Previous_Control,
                   Buttons.Looks ("Previous", Icon => Pomarine.Icons.Shown (Icon_Set.Back), Focusable => True));
         Forward  : constant UI.Layout :=
           Button (S.Next, S.Next_Control,
                   Buttons.Looks ("Next", Icon => Pomarine.Icons.Shown (Icon_Set.Forward), Focusable => True));
         Closer   : constant UI.Layout :=
           Button (S.Close, S.Close_Control,
                   Buttons.Looks ("Close", Icon => Pomarine.Icons.Shown (Pomarine.Icons.Close), Focusable => True));
         Parts    : constant UI.Layout_Array := [Field, Counting, Back, Forward, Closer];
      begin
         --  The bar moves between the project and the window of an item: it is taken out, with what is in it,
         --  and put again where it is wanted.
         if Widgets.Is_Attached (S.Bar) then
            Widgets.Remove (S.Bar);
         end if;
         if In_Window then
            Items.Windows.Mount_Search_Bar
              (Item.Windows (Search_VM.Location (S.Model).Target), Form,
               UI.Styled (UI.Put_In (Form, S.Bar, Parts, Flow => Layouts.Row), Bar_Style));
         else
            UI.Mount_Into
              (Form, Project_Panel (Item).all,
               UI.Styled (UI.Put_In (Form, S.Bar, Parts, Flow => Layouts.Row), Bar_Style));
         end if;
      end;
      Pomarine.Widgets.Panels.Set_Fill (S.Bar, Pomarine.Themes.Strip);
      Fields.Set_Placeholder (S.Field, "Find in item");
      Widgets.Set_Accessible_Name (S.Field, "Find in item");
      Widgets.Set_Accessible_Help (S.Previous, "Previous match (Shift+F3)");
      Widgets.Set_Accessible_Help (S.Next, "Next match (F3)");
      Widgets.Set_Accessible_Help (S.Close, "Close search (Escape)");
   end Build_Bar;

   procedure Build (Item : in out Session) is
   begin
      Item.Finding.Owner := Item'Unchecked_Access;
      Search_VM.Initialize (Item.Searching.Model, Item.Finding'Unchecked_Access);
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
      What : constant Search_VM.Command := (if Backwards then Search_VM.Previous else Search_VM.Next);
   begin
      if Search_VM.Can_Execute (Item.Searching.Model, What) then
         Search_VM.Execute (Item.Searching.Model, What);
      end if;
   end Step;

   procedure Step_Engine (Item : in out Session; Where : Search_VM.Context; Backwards : Boolean) is
      S : Search_State renames Item.Searching;
   begin
      if Where.Scope = Search_VM.Canvas_Item then
         Items.Windows.Search_Step (Item.Windows (Where.Target), Backwards);
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
   end Step_Engine;

   procedure Update_Documents (Item : in out Session; Term : String) is
      S : Search_State renames Item.Searching;
      New_Term : constant Boolean := Term /= To_String (S.Term);
      Changed : Boolean := New_Term or else S.Documents.Count /= Trees.Page_Count (Item.Docs.Ordering);
   begin
      Search_Document_Lists.Resize (S.Documents, Trees.Page_Count (Item.Docs.Ordering), (others => <>));
      S.Total := 0;
      for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
         declare
            Which : constant Items.Slot := Trees.Page_At (Item.Docs.Ordering, Rank);
            Doc : constant Docs.Document_Access := Items.Models.Content_Document (Item.Models (Which));
            Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Rank).Text).all;
            State : Search_Document renames S.Documents (Rank);
            Key : constant Items.Id := Items.Models.Details (Item.Models (Which)).Key;
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
         Step_Engine (Item, Search_VM.Location (S.Model), False);
      end if;
   end Update_Documents;

   procedure Reveal (Item : in out Session) is
      S : Search_State renames Item.Searching;
      X, Y, Wide, High : Float;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if not Search_VM.Is_Showing (S.Model) or else Search_VM.Location (S.Model).Scope /= Search_VM.Writing
        or else not S.Reveal_Pending
      then
         return;
      end if;
      pragma Assert (S.Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering));
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

   procedure Clear_Engine (Item : in out Session; Where : Search_VM.Context) is
      S : Search_State renames Item.Searching;
   begin
      if Where.Scope = Search_VM.Writing then
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
      elsif Where.Target <= Item.Windows.Count
        and then Items.Windows.Is_Assigned (Item.Windows (Where.Target))
        and then Items.Models.Details (Item.Models (Where.Target)).Key = Where.Key
      then
         Items.Windows.Search (Item.Windows (Where.Target), "");
      end if;
      S.Term := Null_Unbounded_String;
      S.Seen := 0;
   end Clear_Engine;

   function Valid (Item : Session; Where : Search_VM.Context) return Boolean is
     (Screen (Item) = Project
      and then (if Where.Scope = Search_VM.Writing then View_Mode (Item) = Write
                else View_Mode (Item) = Canvas and then Where.Target <= Item.Windows.Count
                  and then Items.Windows.Searchable (Item.Windows (Where.Target))
                  and then Items.Models.Details (Item.Models (Where.Target)).Key = Where.Key));

   procedure Refresh_Engine
     (Item : in out Session; Where : Search_VM.Context; Term : String; Found : out Search_VM.Result)
   is
      S : Search_State renames Item.Searching;
   begin
      if Where.Scope = Search_VM.Writing then
         Update_Documents (Item, Term);
         Found := (S.Current, S.Total, False);
      else
         declare
            W : Items.Windows.Window renames Item.Windows (Where.Target);
            Revision : constant Docs.Version :=
              Docs.Current (Items.Models.Content_Document (Item.Models (Where.Target)).all);
         begin
            if Term /= To_String (S.Term) or else Revision /= S.Seen then
               S.Term := To_Unbounded_String (Term);
               S.Seen := Revision;
               Items.Windows.Search (W, Term);
               Items.Windows.Search_Step (W);
            end if;
            Found := (Items.Windows.Search_Current (W), Items.Windows.Search_Count (W), Items.Windows.Search_Busy (W));
         end;
      end if;
   end Refresh_Engine;

   procedure Sync (Item : in out Session) is
   begin
      UI.Synchronize (Item.Forms (Search_Region).Screen.all);
   end Sync;

   procedure Close (Item : in out Session) is
   begin
      if Search_VM.Can_Execute (Item.Searching.Model, Search_VM.Close) then
         Search_VM.Execute (Item.Searching.Model, Search_VM.Close);
      end if;
      Sync (Item);
   end Close;

   procedure Update (Item : in out Session) is
   begin
      Sync (Item);
      Search_VM.Poll (Item.Searching.Model);
      Sync (Item);
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
      if Search_VM.Is_Showing (S.Model) and then Event.Key = Pomarine.Events.Key_Escape then
         Close (Item);
         Handled := True;
      elsif Search_VM.Is_Showing (S.Model) and then Event.Key = Pomarine.Events.Key_F3 then
         Step (Item, Event.Shift);
         Handled := True;
      elsif Event.Command and then Event.Key = Pomarine.Events.Key_F then
         if View_Mode (Item) = Write then
            if not Search_VM.Is_Showing (S.Model) then
               Build_Bar (Item);
               Search_VM.Open (S.Model, (Scope => Search_VM.Writing, others => <>));
               Fields.Set_Placeholder (S.Field, "Find in all documents");
               Widgets.Set_Accessible_Name (S.Field, "Find in all documents");
               Sync (Item);
            end if;
            Widgets.Focus (S.Field);
            Areas.Select_All (Fields.Area (S.Field).all);
            Update (Item);
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
            Fields.Set_Placeholder (S.Field, "Find in item");
            Widgets.Set_Accessible_Name (S.Field, "Find in item");
            Search_VM.Open
              (S.Model, (Search_VM.Canvas_Item, Target, Items.Models.Details (Item.Models (Target)).Key));
            Build_Bar (Item, In_Window => True);
            Sync (Item);
         end if;
         if Search_VM.Is_Showing (S.Model) then
            Widgets.Focus (S.Field);
            Pomarine.Text_Areas.Select_All (Fields.Area (S.Field).all);
            Handled := True;
         end if;
      end if;
   end Handle;
end View.Search;
