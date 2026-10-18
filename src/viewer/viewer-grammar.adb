with Ada.Strings;
with Ada.Strings.Fixed;
with Harper;
with Grammar_Cards;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Switches;
with Texts.Documents;

package body Viewer.Grammar is

   package Docs renames Texts.Documents;
   package Areas renames Pomarine.Text_Areas;
   package Editors renames Pomarine.Widgets.Editors;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);
   use type Docs.Version;
   use type Harper.Request_Id;
   use type Harper.Check_Status;
   use type SDL3.Events.Milliseconds;
   use type Texts.Position;

   --  Harper desktop: src-tauri/src/lint_kind_color.rs at the vendored
   --  revision. draw_highlight.rs uses alpha 24 and a two-pixel underline.
   Colors : constant array (Harper.Lint_Kind) of Pomarine.Themes.Color :=
     [(16#22#, 16#8B#, 16#22#, 255), (16#8B#, 16#45#, 16#13#, 255),
      (16#54#, 16#0D#, 16#6E#, 255), (16#FF#, 16#8C#, 16#00#, 255),
      (16#0E#, 16#AD#, 16#69#, 255), (16#7D#, 16#3C#, 16#98#, 255),
      (16#9B#, 16#59#, 16#B6#, 255), (16#C7#, 16#15#, 16#85#, 255),
      (16#3B#, 16#CE#, 16#AC#, 255), (16#00#, 16#8B#, 16#8B#, 255),
      (16#D4#, 16#85#, 16#0F#, 255), (16#2E#, 16#8B#, 16#57#, 255),
      (16#46#, 16#82#, 16#B4#, 255), (16#C0#, 16#61#, 16#CB#, 255),
      (16#00#, 16#A6#, 16#7C#, 255), (16#EE#, 16#42#, 16#66#, 255),
      (16#FF#, 16#D2#, 16#3F#, 255), (16#FF#, 16#6B#, 16#35#, 255),
      (16#1E#, 16#90#, 16#FF#, 255), (16#22#, 16#8B#, 16#22#, 255),
      (16#4D#, 16#4D#, 16#FF#, 255)];

   function Active (Item : Session) return Boolean is
     (Item.Nav.Shown = Project and then Item.Toolbar.Mode = Write and then Item.Grammar_Checks.Enabled);

   function Image (Total : Natural) return String is
     (Ada.Strings.Fixed.Trim (Total'Image, Ada.Strings.Both));

   procedure Refresh (Item : in out Session);
   procedure Toggle (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   procedure Expand (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   procedure Apply (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   function Valid (Item : Session; Row : Grammar_Row) return Boolean is
     (Active (Item) and then Row.Token /= 0 and then Row.Rank <= Item.Reading.Write_Count
      and then Row.Token = Item.Grammar_Checks.Documents (Row.Rank).Token
      and then Item.Grammar_Checks.Documents (Row.Rank).Serial =
        Docs.Serial (Editors.Document (Item.Docs.Pages (Row.Rank).Text).all)
      and then Item.Grammar_Checks.Documents (Row.Rank).Seen =
        Docs.Current (Editors.Document (Item.Docs.Pages (Row.Rank).Text).all));

   procedure Close (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if State.Showing then
         for Card of State.Cards loop
            if Widgets.Has_Focus (Card) then
               Widgets.Focus (Item.Page_View.Grammar_Count);
               exit;
            end if;
         end loop;
         for Action of State.Actions loop
            if Widgets.Has_Focus (Action) then
               Widgets.Focus (Item.Page_View.Grammar_Count);
               exit;
            end if;
         end loop;
      end if;
      State.Showing := False;
      Widgets.Set_Visible (State.Popout, False);
   end Close;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Item.Grammar_Checks.Showing
        and then not Widgets.Contains (Item.Grammar_Checks.Popout, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (Item.Page_View.Grammar_Count, X * Pixels, Y * Pixels)
      then
         Close (Item);
      end if;
   end Pressed;

   procedure Build (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
      use Layouts;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, State.Popout);
      Panels.Set_Fill (State.Popout, Pomarine.Themes.Background);
      Panels.Set_Border (State.Popout, Pomarine.Themes.Border);
      Panels.Set_Shadow (State.Popout, Pomarine.Themes.Shadow);
      Set_Layout (State.Popout, Place => Absolute, Width => 360.0, Height => 520.0,
                  Flow => Column, Outlined => True, Shadowed => True, Padding => (others => 8.0));
      Widgets.Add (State.Popout, State.Heading, State.Scroll);
      Labels.Set_Text (State.Heading, "Grammar Suggestions");
      Labels.Set_Style (State.Heading, Pomarine.Line_Texts.Heading);
      Set_Layout (State.Heading, Height => 32.0, Shrink => 0.0);
      Set_Layout (State.Scroll, Grow => 1.0, Height => 0.0);
      Widgets.Add (State.Scroll, State.Content);
      Set_Layout (State.Content, Height => 40.0, Flow => Column, Shrink => 0.0);
      Widgets.Add (State.Content, State.Empty);
      Labels.Set_Text (State.Empty, "No grammar suggestions");
      Set_Layout (State.Empty, Place => Absolute, Position => (Top | Left => 8.0, others => <>),
                  Height => 24.0, Width => 300.0);
      for Index in State.Cards'Range loop
         Widgets.Add (State.Content, State.Cards (Index));
         Set_Layout (State.Cards (Index), Place => Absolute, Width => 320.0, Height => 40.0);
         Widgets.Set_Tag (State.Cards (Index), Widgets.No_Tag, Index);
         Hooks.On (State.Cards (Index), Widgets.Click, Item'Unchecked_Access, Expand'Access);
         Widgets.Set_Visible (State.Cards (Index), False);
      end loop;
      for Number in State.Actions'Range loop
         Widgets.Add (State.Content, State.Actions (Number));
         Buttons.Set_Label (State.Actions (Number), "Apply");
         Buttons.Set_Focusable (State.Actions (Number), True);
         Buttons.Set_Kind (State.Actions (Number), Buttons.Primary);
         Set_Layout (State.Actions (Number), Place => Absolute, Width => 56.0, Height => 28.0);
         Widgets.Set_Tag (State.Actions (Number), Widgets.No_Tag, Number);
         Hooks.On (State.Actions (Number), Widgets.Click, Item'Unchecked_Access, Apply'Access);
         Widgets.Set_Visible (State.Actions (Number), False);
      end loop;
      Widgets.Add (State.Content, State.Measure_Card);
      Widgets.Set_Visible (State.Measure_Card, False);
      Hooks.On (Item.Page_View.Grammar_Count, Widgets.Click, Item'Unchecked_Access, Toggle'Access);
      Widgets.Set_Visible (State.Popout, False);
   end Build;

   procedure Refresh (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Parent_Left : constant Float := Widgets.Left_Of (Item.Toolbar.Content_Panel) / Pixels;
      Parent_Top : constant Float := Widgets.Top_Of (Item.Toolbar.Content_Panel) / Pixels;
      Parent_Wide : constant Float := Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels;
      Parent_High : constant Float := Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels;
      Wide : constant Float := Float'Max (144.0, Float'Min (360.0, Parent_Wide - 16.0));
      Left : constant Float := Float'Max (8.0, Float'Min (Parent_Wide - Wide - 8.0,
        (Widgets.Left_Of (Item.Page_View.Grammar_Count) + Widgets.Width_Of (Item.Page_View.Grammar_Count))
        / Pixels - Parent_Left + 8.0));
      Top : constant Float := Float'Max (8.0,
        Widgets.Top_Of (Item.Page_View.Grammar_Count) / Pixels - Parent_Top);
      High : constant Float := Float'Max (80.0, Float'Min (520.0, Parent_High - Top - 8.0));
      Card_Wide : constant Float := Wide - 24.0;
      Fixable, Total : Natural := 0;
      Row_Top : Float := 4.0;
      Used : Natural := 0;
      Offset : constant Float := Pomarine.Widgets.Scrollers.Offset (State.Scroll);
      use Layouts;
   begin
      if not State.Dirty and then (not State.Showing or else
        (State.Left = Left and then State.Top = Top and then State.Width = Wide and then State.Height = High
         and then State.Offset = Offset))
      then
         return;
      end if;
      State.Left := Left;
      State.Top := Top;
      State.Width := Wide;
      State.Height := High;
      State.Offset := Offset;
      for Action of State.Actions loop
         Widgets.Set_Visible (Action, False);
      end loop;
      State.Bindings := [others => 0];
      for Index in State.Rows'Range loop
         declare
            Row : Grammar_Row renames State.Rows (Index);
         begin
            if Valid (Item, Row) then
               Total := Total + 1;
               if Row.Lint.Suggestion_Count > 0 then
                  Fixable := Fixable + 1;
               end if;
               declare
                  Height : Float := 40.0;
               begin
                  if State.Expanded = Index then
                     Grammar_Cards.Set_Diagnostic (State.Measure_Card, Row.Lint,
                       Labels.Text (Item.Docs.Pages (Row.Rank).Heading), Colors (Row.Lint.Kind));
                     Grammar_Cards.Set_Expanded (State.Measure_Card, True);
                     Height := Grammar_Cards.Height_For (State.Measure_Card, Card_Wide);
                  end if;
                  if Row_Top + Height >= Offset and then Row_Top <= Offset + High then
                     pragma Assert (Used < State.Cards'Length);
                     Used := Used + 1;
                     State.Bindings (Used) := Index;
                     Grammar_Cards.Set_Diagnostic (State.Cards (Used), Row.Lint,
                       Labels.Text (Item.Docs.Pages (Row.Rank).Heading), Colors (Row.Lint.Kind));
                     Grammar_Cards.Set_Expanded (State.Cards (Used), State.Expanded = Index);
                     Set_Layout (State.Cards (Used), Width => Card_Wide, Height => Height,
                                 Position => (Left => 4.0, Top => Row_Top, others => <>));
                     Widgets.Set_Visible (State.Cards (Used), True);
                     if State.Expanded = Index then
                        for Number in 1 .. Row.Lint.Suggestion_Count loop
                           Set_Layout (State.Actions (Number), Position =>
                             (Left => Card_Wide - 64.0,
                              Top => Row_Top + Grammar_Cards.Action_Top
                                (State.Cards (Used), Number, Card_Wide), others => <>));
                           Widgets.Set_Accessible_Name (State.Actions (Number), "Apply: " &
                             (if Harper.Replacements.Length (Row.Lint.Suggestions (Number).Text) = 0 then "remove text"
                              else Harper.Replacements.To_String (Row.Lint.Suggestions (Number).Text)));
                           Widgets.Set_Visible (State.Actions (Number), True);
                        end loop;
                     end if;
                  end if;
                  Row_Top := Row_Top + Height + 8.0;
               end;
            end if;
         end;
      end loop;
      for Index in Used + 1 .. State.Cards'Last loop
         Widgets.Set_Visible (State.Cards (Index), False);
      end loop;
      Buttons.Set_Label (Item.Page_View.Grammar_Count, Image (Fixable));
      Set_Layout (Item.Page_View.Grammar_Count, Width => Float'Max (36.0, 12.0 + Float (Image (Fixable)'Length) * 8.0));
      Buttons.Set_Kind (Item.Page_View.Grammar_Count, (if Fixable = 0 then Buttons.Normal else Buttons.Warning));
      Widgets.Set_Accessible_Name (Item.Page_View.Grammar_Count, "Fixable grammar suggestions: " & Image (Fixable));
      Labels.Set_Text (State.Heading, Labels.Fitted ("Grammar Suggestions (" & Image (Total) & ")"));
      Widgets.Set_Visible (State.Empty, Total = 0);
      Set_Layout (State.Content, Height => Float'Max (40.0, Row_Top));
      Set_Layout (State.Popout, Width => Wide, Height => High,
                  Position => (Left => Left, Top => Top, others => <>));
      State.Dirty := False;
      Widgets.Request_Layout (State.Popout);
      if State.Showing then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Pomarine.Widgets.Scrollers.Scroll_To (State.Scroll, Offset);
         if Pomarine.Widgets.Scrollers.Offset (State.Scroll) /= Offset then
            State.Dirty := True;
            Refresh (Item);
         end if;
      end if;
   end Refresh;

   procedure Toggle (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source, Event);
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if State.Showing then
         Close (Item);
      elsif Item.Nav.Shown = Project and then Item.Toolbar.Mode = Write then
         Pomarine.Widgets.Scrollers.Scroll_To (State.Scroll, 0.0);
         State.Showing := True;
         State.Dirty := True;
         Refresh (Item);
         Widgets.Set_Visible (State.Popout, True);
         Widgets.Raise_To_Front (State.Popout);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Toggle;

   procedure Expand (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if Event.Index in State.Bindings'Range then
         declare
            Index : constant Natural := State.Bindings (Event.Index);
         begin
            if Index /= 0 and then Valid (Item, State.Rows (Index)) then
               State.Expanded := (if State.Expanded = Index then 0 else Index);
               State.Dirty := True;
               Refresh (Item);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         end;
      end if;
   end Expand;

   procedure Reset (Item : in out Session) is
   begin
      Close (Item);
      for Row of Item.Grammar_Checks.Rows loop
         Row.Token := 0;
      end loop;
      for Card of Item.Grammar_Checks.Cards loop
         Widgets.Set_Visible (Card, False);
      end loop;
      Item.Grammar_Checks.Expanded := 0;
      Item.Grammar_Checks.Dirty := True;
      for Each of Item.Grammar_Checks.Documents loop
         Each := (others => <>);
      end loop;
      for Each of Item.Docs.Pages loop
         Areas.Clear_Highlights (Editors.Area (Each.Text).all);
         Widgets.Invalidate (Each.Text);
      end loop;
      --  Running tasks own their input. Their old tokens are discarded
      --  when polled; never reset the monotonically increasing token.
   end Reset;

   function Advance (Doc : Docs.Document; From : Texts.Position; Bytes : Natural) return Texts.Position is
      At_Point : Texts.Position := From;
      Left     : Natural := Bytes;
   begin
      loop
         declare
            Remaining : constant Natural := Docs.Byte_Length (Doc, At_Point.Paragraph) - At_Point.Index + 1;
         begin
            if Left <= Remaining then
               At_Point.Index := At_Point.Index + Left;
               return At_Point;
            end if;
            pragma Assert (At_Point.Paragraph < Docs.Count (Doc));
            Left := Left - Remaining - 1;
            At_Point := (At_Point.Paragraph + 1, 1);
         end;
      end loop;
   end Advance;

   procedure Apply (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if State.Expanded = 0 or else not Valid (Item, State.Rows (State.Expanded)) then
         return;
      end if;
      declare
         Row : Grammar_Row renames State.Rows (State.Expanded);
         Lint : Harper.Diagnostic renames Row.Lint;
         Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Row.Rank).Text).all;
         Doc : Docs.Document renames Areas.Document (Area).all;
      begin
         if Event.Index in 1 .. Lint.Suggestion_Count and then not Areas.Is_Composing (Area)
           and then not Areas.Is_Read_Only (Area)
         then
            declare
               Fix : Harper.Suggestion renames Lint.Suggestions (Event.Index);
               From : constant Texts.Position := Advance (Doc, Row.First, Fix.Location.First);
               To : constant Texts.Position := Advance (Doc, Row.First, Fix.Location.Last);
               Replacement : constant String := Harper.Replacements.To_String (Fix.Text);
            begin
               Areas.Replace_Range (Area, From, To, Replacement);
               Widgets.Invalidate (Item.Docs.Pages (Row.Rank).Text);
               Widgets.Focus (Item.Page_View.Grammar_Count);
               State.Expanded := 0;
               Update (Item, SDL3.Events.Ticks);
            end;
         end if;
      end;
   end Apply;

   procedure Chunk
     (Doc : Docs.Document; From : Texts.Position; Buffer : out String;
      Length : out Natural; Next_Position : out Texts.Position; Last : out Boolean)
     with Pre => Buffer'First = 1 and then Buffer'Length >= 4 and then Docs.Is_Position (Doc, From),
          Post => Length <= Buffer'Length and then Docs.Is_Position (Doc, Next_Position)
                  and then (Last or else From < Next_Position)
                  and then Last = (Next_Position = Docs.Text_End (Doc))
   is
      At_Point : Texts.Position := From;
   begin
      Length := 0;
      while Length < Buffer'Length loop
         declare
            Available : constant Natural := Docs.Byte_Length (Doc, At_Point.Paragraph) - At_Point.Index + 1;
            Room      : constant Natural := Buffer'Length - Length;
            Take      : Natural := Natural'Min (Available, Room);
         begin
            --  Prefer whole paragraphs; only split an oversized one.
            exit when Available > Room and then Length > 0;
            while not Docs.Is_Boundary (Doc, At_Point.Paragraph, At_Point.Index + Take) loop
               Take := Take - 1;
            end loop;
            if Available > Take then
               declare
                  Part : constant String := Docs.Slice (Doc, At_Point.Paragraph, At_Point.Index, At_Point.Index + Take);
               begin
                  for Index in reverse Part'Range loop
                     if Part (Index) in ' ' | ASCII.HT then
                        Take := Index - Part'First + 1;
                        exit;
                     end if;
                  end loop;
               end;
            end if;
            Buffer (Length + 1 .. Length + Take) :=
              Docs.Slice (Doc, At_Point.Paragraph, At_Point.Index, At_Point.Index + Take);
            Length := Length + Take;
            At_Point.Index := At_Point.Index + Take;
            exit when Take < Available or else At_Point.Paragraph = Docs.Count (Doc);
            exit when Length = Buffer'Length;
            Length := Length + 1;
            Buffer (Length) := ASCII.LF;
            At_Point := (At_Point.Paragraph + 1, 1);
         end;
      end loop;
      Next_Position := At_Point;
      Last := At_Point = Docs.Text_End (Doc);
      pragma Assert (Last or else From < Next_Position);
   end Chunk;

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      State : Grammar_State renames Item.Grammar_Checks;
      On    : constant Boolean := Pomarine.Widgets.Switches.Is_On (Item.Page_View.Grammar_Switch);
   begin
      if On /= State.Enabled then
         State.Enabled := On;
         Reset (Item);
      end if;

      --  Observe versions before collecting results: an edit, reload or
      --  page reordering must invalidate the previous generation first.
      if Active (Item) then
         for Rank in 1 .. Item.Reading.Write_Count loop
            declare
               Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Rank).Text).all;
               Doc  : Docs.Document renames Areas.Document (Area).all;
               Seen : Grammar_Document renames State.Documents (Rank);
               Fresh : constant Boolean := Seen.Serial /= Docs.Serial (Doc);
            begin
               if Fresh or else Seen.Seen /= Docs.Current (Doc) then
                  State.Serial := State.Serial + 1;
                  Seen := (Serial => Docs.Serial (Doc), Seen => Docs.Current (Doc), Token => State.Serial,
                           Due => Now + (if Fresh then 0 else Idle_Delay), others => <>);
                  Areas.Clear_Highlights (Area);
                  Widgets.Invalidate (Item.Docs.Pages (Rank).Text);
               end if;
            end;
         end loop;
      end if;

      for Index in State.Rows'Range loop
         if State.Rows (Index).Token /= 0 and then not Valid (Item, State.Rows (Index)) then
            State.Rows (Index).Token := 0;
            if State.Expanded = Index then
               State.Expanded := 0;
            end if;
            State.Dirty := True;
         end if;
      end loop;
      if Item.Nav.Shown /= Project or else Item.Toolbar.Mode /= Write then
         Close (Item);
      end if;

      for Worker of State.Workers loop
         if Worker.Busy then
            declare
               Result : Harper.Check_Result;
               Ready  : Boolean;
               Seen   : Grammar_Document renames State.Documents (Worker.Rank);
            begin
               Harper.Poll (Worker.Checker, Result, Ready);
               if Ready then
                  Worker.Busy := False;
                  if Active (Item) and then Worker.Rank <= Item.Reading.Write_Count
                    and then Worker.Token = Seen.Token
                  then
                     Seen.Busy := False;
                     Seen.Cursor := Worker.Next_Position;
                     Seen.Finished := Worker.Last or else Result.Status /= Harper.Success;
                     if Result.Status = Harper.Success then
                        declare
                           Editor : Editors.Editor renames Item.Docs.Pages (Worker.Rank).Text;
                           Area : Areas.Text_Area renames Editors.Area (Editor).all;
                           Doc  : Docs.Document renames Areas.Document (Area).all;
                        begin
                           for Index in 1 .. Result.Count loop
                              declare
                                 Lint : Harper.Diagnostic renames Result.Lints (Index);
                                 Ink  : constant Pomarine.Themes.Color := Colors (Lint.Kind);
                              begin
                                 if Seen.Retained < Areas.Max_Highlights then
                                    for Row of State.Rows loop
                                       if Row.Token = 0 then
                                          Row.Rank := Worker.Rank;
                                          Row.Token := Worker.Token;
                                          Row.First := Worker.First;
                                          Row.Lint := Lint;
                                          Seen.Retained := Seen.Retained + 1;
                                          State.Dirty := True;
                                          exit;
                                       end if;
                                    end loop;
                                 end if;
                                 if Lint.Location.First < Lint.Location.Last
                                   and then Areas.Highlight_Count (Area) < Areas.Max_Highlights
                                 then
                                    Areas.Add_Highlight
                                      (Area, Advance (Doc, Worker.First, Lint.Location.First),
                                       Advance (Doc, Worker.First, Lint.Location.Last),
                                       (Ink with delta Alpha => 24), Ink);
                                 end if;
                              end;
                           end loop;
                           Widgets.Invalidate (Editor);
                        end;
                     end if;
                  elsif Worker.Token = Seen.Token then
                     --  Mode changed while checking. Retry on returning.
                     Seen.Busy := False;
                  end if;
               end if;
            end;
         end if;
      end loop;

      Refresh (Item);
      if not Active (Item) then
         return;
      end if;
      for Worker of State.Workers loop
         if not Worker.Busy then
            for Rank in 1 .. Item.Reading.Write_Count loop
               declare
                  Seen : Grammar_Document renames State.Documents (Rank);
               begin
                  if not Seen.Busy and then not Seen.Finished and then Now >= Seen.Due then
                     declare
                        Doc : Docs.Document renames Areas.Document (Editors.Area (Item.Docs.Pages (Rank).Text).all).all;
                        Buffer : String (1 .. Harper.Max_Text);
                        Length : Natural;
                        Accepted : Boolean;
                     begin
                        Chunk (Doc, Seen.Cursor, Buffer, Length, Worker.Next_Position, Worker.Last);
                        Harper.Submit (Worker.Checker, Buffer (1 .. Length), Seen.Token, Accepted);
                        if Accepted then
                           Worker.Rank := Rank;
                           Worker.Token := Seen.Token;
                           Worker.First := Seen.Cursor;
                           Worker.Busy := True;
                           Seen.Busy := True;
                        end if;
                     end;
                     exit;
                  end if;
               end;
            end loop;
         end if;
      end loop;
   end Update;

   function Until_Update (Item : Session; Now : SDL3.Events.Milliseconds) return Integer is
      Wait : Integer := -1;
      Available : Boolean := False;
   begin
      for Worker of Item.Grammar_Checks.Workers loop
         if Worker.Busy then
            Wait := 20;
         else
            Available := True;
         end if;
      end loop;
      if Active (Item) and then Available then
         for Rank in 1 .. Item.Reading.Write_Count loop
            declare
               Seen : Grammar_Document renames Item.Grammar_Checks.Documents (Rank);
            begin
               if not Seen.Busy and then not Seen.Finished then
                  declare
                     Due : constant Integer := Integer (SDL3.Events.Milliseconds'Max (1, Seen.Due - Now));
                  begin
                     Wait := (if Wait < 0 then Due else Integer'Min (Wait, Due));
                  end;
               end if;
            end;
         end loop;
      end if;
      return Wait;
   end Until_Update;

end Viewer.Grammar;
