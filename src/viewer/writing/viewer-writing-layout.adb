with Projects.Sections;
with Texts.Documents;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Viewer.Outlines;
with Viewer.Style;
with Pomarine.Widgets.Layouts;
with Viewer.Writing.Support;

package body Viewer.Writing.Layout is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Editors renames Pomarine.Widgets.Editors;
   package Labels renames Pomarine.Widgets.Labels;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Docs renames Texts.Documents;

   use type Docs.Version;
   use type Texts.Position;

   Reveal_Margin : constant Float := 48.0;
   --  How close to the edge of the view, in points, the caret may be
   --  before the pages are scrolled.

   procedure Place_Sections (Item : in out Session);
   --  Put the sections among the pages, in the order of the tree: each a
   --  heading, and the pages of its documents or the button to write
   --  one; and a faint line before each run of documents that are of no
   --  section (those between two sections, before the first or after
   --  the last). The pages keep their places in the order of the
   --  documents; only where they are put changes. With a section shown,
   --  it is that one alone. Without sections, or with a folder shown,
   --  the pages are one below the next, as they were.

   procedure Place_Sections (Item : in out Session) is
      Parts  : Section_View_Parts renames Item.Section_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Total  : constant Natural := Outlines.Section_Count (Item);
      Group  : constant Boolean :=
        Total > 0 and then (Item.Docs.Shown_Dir = 0 or else Support.Is_Section (Item, Item.Docs.Shown_Dir));

      function Notes_Box_Height (Place : Positive) return Float is
        (Parts.Notes (Place).High + 2.0 * Style.Notes_Pad + 2.0);
      --  In points: the text, and the padding and outline round it.

      procedure Set_Grouped (To : Boolean) is
      begin
         if To /= Parts.Grouped then
            Parts.Grouped := To;
            Parts.Plan_Count := 0;
            for Each of Item.Docs.Pages loop
               Layouts.Set_Layout
                 (Each.Box,
                  Place => (if To then Layouts.Absolute else Layouts.Flowing),
                  Position => (if To then (others => Layouts.Unset) else (others => 0.0)));
            end loop;
            Widgets.Set_Visible (Parts.Tail, To);
            Layouts.Set_Layout (Parts.Tail, Height => 0.0);
            if not To then
               for Each of Parts.Heads loop
                  Widgets.Set_Visible (Each.Row, False);
               end loop;
               for Each of Parts.Empties loop
                  Widgets.Set_Visible (Each.Box, False);
               end loop;
               for Each of Parts.Notes loop
                  Widgets.Set_Visible (Each.Box, False);
               end loop;
               for Each of Parts.Gaps loop
                  Widgets.Set_Visible (Each.Row, False);
               end loop;
            end if;
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         end if;
      end Set_Grouped;
   begin
      Set_Grouped (Group);
      if not Group then
         return;
      end if;
      --  The notes are as tall as they need to be, but not less than a few lines.
      for Place in 1 .. Outlines.Section_Count (Item) loop
         if Outlines.Notes_Shown (Item, Place) then
            Parts.Notes (Place).High :=
              Float'Max
                (Style.Notes_Min_Height,
                 Float'Ceiling (Pomarine.Text_Areas.Content_Height (Editors.Area (Parts.Notes (Place).Text).all)));
         end if;
      end loop;
      declare
         Plan   : Plan_Array;
         Planned  : Natural := 0;
         Runs   : Natural := 0;
         Open_Run : Boolean := False;
         --  The pages of documents that are of no section, in the order
         --  of the tree, which come one after another, are a run.

         procedure Add (Kind : Plan_Kinds; Index : Natural) is
         begin
            Plan.Append ((Kind => Kind, Index => Index, Top => 0.0));
            Planned := Plan.Count;
         end Add;

         procedure Add_Section (Dir : Positive) is
            Place : constant Natural :=
              Outlines.Index_Of_Key
                (Item, Projects.Sections.Section_Id (Item.Docs.Dirs (Dir).Section));
         begin
            if Place = 0 then
               return;
            end if;
            Add (Head_Entry, Place);
            if Outlines.Notes_Shown (Item, Place) then
               Add (Notes_Entry, Place);
            end if;
            if Support.Documents_In (Item, Dir) = 0 then
               Add (Empty_Entry, Place);
            end if;
            Open_Run := False;
         end Add_Section;
      begin
         if Item.Docs.Shown_Dir /= 0 then
            --  A section's own: its documents, or the button to write one.
            Add_Section (Item.Docs.Shown_Dir);
            for Row in 2 .. Item.Docs.Tree_Count loop
               if Item.Docs.Tree (Row).Kind = Document_Leaf
                 and then Item.Docs.Tree (Row).Dir = Item.Docs.Shown_Dir
               then
                  Add (Page_Entry, Support.Rank_Of (Item, Item.Docs.Tree (Row).Doc));
               end if;
            end loop;
         else
            for Row in 2 .. Item.Docs.Tree_Count loop
               declare
                  Node : Tree_Entry renames Item.Docs.Tree (Row);
               begin
                  case Node.Kind is
                     when Directory_Node =>
                        if Support.Is_Section (Item, Node.Dir) then
                           Add_Section (Node.Dir);
                        end if;
                     when Document_Leaf =>
                        if not Support.Is_Section (Item, Node.Dir) then
                           if not Open_Run then
                              Add (Gap_Entry, Runs);
                              Runs := Runs + 1;
                              Open_Run := True;
                           end if;
                        end if;
                        Add (Page_Entry, Support.Rank_Of (Item, Node.Doc));
                     when Overview_Node =>
                        null;
                  end case;
               end;
            end loop;
         end if;

         --  A section may have been renamed: it is the one name.
         for Each in 1 .. Planned loop
            if Plan (Each).Kind = Head_Entry then
               Labels.Set_Text
                 (Parts.Heads (Plan (Each).Index).Title,
                  Labels.Fitted
                    (Projects.Sections.Title_Texts.To_String
                       (Outlines.Section_At (Item, Plan (Each).Index).Title)));
            end if;
         end loop;

         --  Where each goes, down the view.
         declare
            Y : Float := 0.0;
         begin
            for Each in 1 .. Planned loop
               declare
                  Now  : Plan_Entry renames Plan (Each);
                  Gap  : constant Float :=
                    (if Each = 1 then 0.0
                     elsif Now.Kind = Head_Entry then Style.Section_Before * Pixels
                     elsif Plan (Each - 1).Kind in Head_Entry | Gap_Entry
                       and then Now.Kind /= Notes_Entry
                     then Style.Section_After * Pixels
                     elsif Now.Kind = Notes_Entry then Style.Page_Gap * Pixels
                     else Style.Page_Gap * Pixels);
                  High : constant Float :=
                    (case Now.Kind is
                        when Head_Entry  => Style.Section_Head_Height * Pixels,
                        when Empty_Entry => Style.Section_Empty_Height * Pixels,
                        when Notes_Entry => Notes_Box_Height (Now.Index) * Pixels,
                        when Gap_Entry   => Style.Gap_Mark_Height * Pixels,
                        when Page_Entry  =>
                          Widgets.Height_Of (Item.Docs.Pages (Now.Index).Box));
               begin
                  Y := Y + Gap;
                  Now.Top := Float'Rounding (Y);
                  Y := Y + High;
               end;
            end loop;
            if Planned /= Parts.Plan_Count
              or else (for some Each in 1 .. Planned => Plan (Each) /= Parts.Plan (Each))
              or else Float'Rounding (Y) /= Widgets.Height_Of (Parts.Tail)
            then
               declare
                  Wide : constant Float :=
                    Float'Max (Style.Page_Min_Width,
                               Float'Min (Style.Page_Width,
                                          Widgets.Width_Of (Item.Page_View.Pages_Content) / Pixels
                                          - 2.0 * Style.Page_Margin));
                  --  Where a page is, across: in the middle of the view.
                  Home_Left : constant Float :=
                    Float'Rounding ((Widgets.Width_Of (Item.Page_View.Pages_Content) - Wide * Pixels) / 2.0);
                  Home_Top  : constant Float :=
                    Widgets.Top_Of (Parts.Tail) - Widgets.Top_Of (Item.Page_View.Pages_Content);
                  Shown_Heads  : array (1 .. Parts.Heads.Count) of Boolean := [others => False];
                  Shown_Empty  : array (1 .. Parts.Heads.Count) of Boolean := [others => False];
                  Shown_Notes  : array (1 .. Parts.Heads.Count) of Boolean := [others => False];
                  Shown_Gaps   : array (0 .. Parts.Gaps.Count - 1) of Boolean := [others => False];

                  procedure Put (Part : in out Widgets.Widget'Class; Top : Float) is
                  begin
                     Layouts.Set_Layout (Part, Width => Wide);
                     Layouts.Set_Layout
                       (Part,
                        Position => (Left => Home_Left, Top => Home_Top + Top, others => <>),
                        Unit => Layouts.Device_Pixels);
                  end Put;
               begin
                  Layouts.Set_Layout (Parts.Tail, Width => Wide, Height => Float'Rounding (Y), Unit => Layouts.Points);
                  Layouts.Set_Layout (Parts.Tail, Height => Float'Rounding (Y), Unit => Layouts.Device_Pixels);
                  for Each in 1 .. Planned loop
                     declare
                        Now : Plan_Entry renames Plan (Each);
                     begin
                        case Now.Kind is
                           when Head_Entry =>
                              declare
                                 Head    : Section_Head renames Parts.Heads (Now.Index);
                                 Section : constant Projects.Sections.Section :=
                                   Outlines.Section_At (Item, Now.Index);
                                 Owned   : constant Natural := Outlines.Documents_In (Item, Now.Index);
                              begin
                                 Shown_Heads (Now.Index) := True;
                                 Widgets.Set_Visible (Head.Add, Owned > 0);
                                 Pomarine.Widgets.Buttons.Set_Selected (Head.Notes, Section.Open);
                                 Labels.Set_Text
                                   (Head.Title,
                                    Labels.Fitted (Projects.Sections.Title_Texts.To_String (Section.Title)));
                                 Labels.Set_Text
                                   (Head.Count,
                                    (if Owned = 0 then ""
                                     else Support.Count_Image (Owned)
                                          & (if Owned = 1 then " document" else " documents")));
                                 Pomarine.Widgets.Panels.Set_Fill (Head.Bar, Style.Section_Ink (Section.Colour));
                                 Put (Head.Row, Now.Top);
                              end;
                           when Notes_Entry =>
                              declare
                                 Note : Note_Box renames Parts.Notes (Now.Index);
                              begin
                                 Shown_Notes (Now.Index) := True;
                                 Pomarine.Widgets.Panels.Set_Border
                                   (Note.Box, Style.Section_Ink (Outlines.Section_At (Item, Now.Index).Colour));
                                 Layouts.Set_Layout (Note.Text, Height => Note.High);
                                 Layouts.Set_Layout (Note.Box, Height => Notes_Box_Height (Now.Index));
                                 Put (Note.Box, Now.Top);
                              end;
                           when Empty_Entry =>
                              Shown_Empty (Now.Index) := True;
                              Pomarine.Widgets.Panels.Set_Border
                                (Parts.Empties (Now.Index).Box,
                                 Style.Section_Ink (Outlines.Section_At (Item, Now.Index).Colour));
                              Put (Parts.Empties (Now.Index).Box, Now.Top);
                           when Gap_Entry =>
                              Shown_Gaps (Now.Index) := True;
                              Put (Parts.Gaps (Now.Index + 1).Row, Now.Top);
                           when Page_Entry =>
                              Put (Item.Docs.Pages (Now.Index).Box, Now.Top);
                        end case;
                     end;
                  end loop;
                  for Each in Shown_Heads'Range loop
                     Widgets.Set_Visible (Parts.Heads (Each).Row, Shown_Heads (Each));
                     Widgets.Set_Visible (Parts.Empties (Each).Box, Shown_Empty (Each));
                     Widgets.Set_Visible (Parts.Notes (Each).Box, Shown_Notes (Each));
                  end loop;
                  for Each in Shown_Gaps'Range loop
                     Widgets.Set_Visible (Parts.Gaps (Each + 1).Row, Shown_Gaps (Each));
                  end loop;
                  Parts.Plan := Plan;
                  Parts.Plan_Count := Planned;
                  Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
               end;
            end if;
         end;
      end;
   end Place_Sections;

   procedure Fit_Pages (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Changed : Boolean;
      Moved   : Boolean := False;
   begin
      if Item.Toolbar.Mode = Publish then
         --  The content area owns scrolling; the paper grows to contain
         --  all its text, and moves together with the surrounding margin.
         for Pass in 1 .. 3 loop
            Changed := False;
            declare
               View : Publish_Parts renames Item.Publish_View;
               Room : constant Float := Widgets.Width_Of (View.Scroll) / Pixels - 2.0 * Style.Page_Margin;
               Wide : constant Float := Float'Max (Style.Page_Min_Width, Float'Min (Style.Page_Width, Room));
               High : constant Float := Float'Max
                 (Style.Page_Min_Height,
                  Float'Ceiling (Pomarine.Text_Areas.Content_Height (Editors.Area (View.Text).all)));
            begin
               if Wide /= View.Wide then
                  Layouts.Set_Layout (View.Text, Width => Wide);
                  View.Wide := Wide;
                  Changed := True;
               end if;
               if High /= View.High then
                  Layouts.Set_Layout (View.Text, Height => High);
                  View.High := High;
                  Changed := True;
               end if;
            end;
            exit when not Changed;
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         end loop;
         return;
      end if;
      --  The text is as tall as it needs to be, at the width the sheet
      --  has: laying out again after a change of either settles it.
      for Pass in 1 .. 3 loop
         Changed := False;
         declare
            Room : constant Float :=
              Widgets.Width_Of (Item.Page_View.Pages_Content) / Pixels
              - 2.0 * Style.Page_Margin;
            Wide : constant Float :=
              Float'Max (Style.Page_Min_Width,
                         Float'Min (Style.Page_Width, Room));
         begin
            for Rank in 1 .. Item.Reading.Write_Count loop
               if Support.In_View (Item, Item.Reading.Write_Order (Rank)) then
                  declare
                     Each : Doc_Page renames Item.Docs.Pages (Rank);
                     High : constant Float :=
                       Float'Max
                         (Style.Page_Min_Height,
                          Float'Ceiling
                            (Pomarine.Text_Areas.Content_Height
                               (Editors.Area (Each.Text).all)));
                  begin
                     if Wide /= Each.Wide then
                        Layouts.Set_Layout (Each.Box, Width => Wide);
                        Each.Wide := Wide;
                        Changed := True;
                     end if;
                     if High /= Each.High then
                        Layouts.Set_Layout (Each.Text, Height => High);
                        Each.High := High;
                        Changed := True;
                     end if;
                  end;
               end if;
            end loop;
         end;
         exit when not Changed;
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end loop;

      Place_Sections (Item);

      --  The menu stays under its button, its left edge in line with the
      --  button's (or as far left as keeps it in the view), as the pages
      --  are scrolled.
      if Item.Page_View.Menu_Page /= 0 then
         declare
            Button : Buttons.Button renames
              Item.Docs.Pages (Item.Page_View.Menu_Page).Sources_Button;
            Place_Left   : constant Float :=
              Float'Max
                (0.0,
                 Float'Min
                   ((Widgets.Left_Of (Button)
                     - Widgets.Left_Of (Item.Page_View.Write_View)) / Pixels,
                    Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                    - Style.Menu_Width - Style.Reader_Margin));
            Place_Top    : constant Float :=
              (Widgets.Top_Of (Button) + Widgets.Height_Of (Button)
               - Widgets.Top_Of (Item.Page_View.Write_View)) / Pixels
              + Style.Menu_Gap;
         begin
            if Place_Left /= Item.Page_View.Menu_Left
               or else Place_Top /= Item.Page_View.Menu_Top
            then
               Item.Page_View.Menu_Left := Place_Left;
               Item.Page_View.Menu_Top := Place_Top;
               Layouts.Set_Layout
                 (Item.Page_View.Menu,
                  Position => (Left => Float'Rounding (Place_Left * Pixels),
                               Top  => Float'Rounding (Place_Top * Pixels),
                               others => <>),
                  Unit => Layouts.Device_Pixels);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         end;
      end if;

      --  The caret, where it has gone, is kept in view.
      for Rank in 1 .. Item.Reading.Write_Count loop
         declare
            Each : Doc_Page renames Item.Docs.Pages (Rank);
            Area : Pomarine.Text_Areas.Text_Area renames
              Editors.Area (Each.Text).all;
         begin
            if Widgets.Has_Focus (Each.Text) then
               declare
                  Caret   : constant Texts.Position :=
                    Pomarine.Text_Areas.Caret (Area);
                  Edited  : constant Docs.Version :=
                    Docs.Current (Pomarine.Text_Areas.Document (Area).all);
               begin
                  if Caret /= Each.Caret_For or else Edited /= Each.Caret_Seen
                  then
                     Each.Caret_For := Caret;
                     Each.Caret_Seen := Edited;
                     declare
                        X, Y, Wide, High : Float;
                        Reveal_Top    : constant Float :=
                          Widgets.Top_Of (Item.Page_View.Pages_Scroll)
                          + Reveal_Margin * Pixels;
                        Bottom : constant Float :=
                          Widgets.Top_Of (Item.Page_View.Pages_Scroll)
                          + Widgets.Height_Of (Item.Page_View.Pages_Scroll)
                          - Reveal_Margin * Pixels;
                        Offset : constant Float :=
                          Scrollers.Offset (Item.Page_View.Pages_Scroll);
                     begin
                        Editors.Caret_Box (Each.Text, X, Y, Wide, High);
                        if Y < Reveal_Top then
                           Scrollers.Scroll_To
                             (Item.Page_View.Pages_Scroll,
                              Offset - (Reveal_Top - Y) / Pixels);
                           Moved := True;
                        elsif Y + High > Bottom then
                           Scrollers.Scroll_To
                             (Item.Page_View.Pages_Scroll,
                              Offset + (Y + High - Bottom) / Pixels);
                           Moved := True;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      if Moved then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Fit_Pages;

end Viewer.Writing.Layout;
