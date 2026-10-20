with Harper;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Menus;
with Pomarine.Line_Texts;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Switches;
with Texts.Documents;
with Viewer.Grammar.Basics;
with Viewer.Grammar.Cards;

package body Viewer.Grammar is

   package Docs renames Texts.Documents;
   package Areas renames Pomarine.Text_Areas;
   package Editors renames Pomarine.Widgets.Editors;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Menus renames Pomarine.Widgets.Menus;
   package Panels renames Pomarine.Widgets.Panels;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Widgets.Widget_Access;
   use type Widgets.Node_Id;
   use type SDL3.Events.Event_Kind;
   use type Docs.Version;
   use type Harper.Request_Id;
   use type Harper.Check_Status;
   use type SDL3.Events.Milliseconds;
   use type Texts.Position;

   Row_Chunk : constant := 64;
   --  How many rows are made at once when there is none to take.

   procedure Keep_Row
     (State  : in out Grammar_State;
      Worker : Grammar_Worker;
      Lint   : Harper.Diagnostic;
      Seen   : in out Grammar_Document)
   is
      procedure Take (Row : in out Grammar_Row) is
      begin
         Row.Rank := Worker.Rank;
         Row.Token := Worker.Token;
         Row.First := Worker.First;
         Row.Lint := Lint;
         Seen.Retained := Seen.Retained + 1;
         State.Dirty := True;
      end Take;
   begin
      for Row of State.Rows loop
         if Row.Token = 0 then
            Take (Row);
            return;
         end if;
      end loop;
      State.Rows.Grow (State.Rows.Count + Row_Chunk);
      Take (State.Rows (State.Rows.Count - Row_Chunk + 1));
   end Keep_Row;
   --  Keep the diagnostic in a row that is free, or in one made for it.

   procedure Close_Inline (Item : in out Session) is
   begin
      Item.Grammar_Checks.Inline_Open := False;
      Item.Grammar_Checks.Inline_Count := 0;
      Item.Grammar_Checks.Press_Rank := 0;
      Widgets.Set_Visible (Item.Grammar_Checks.Inline_Menu, False);
   end Close_Inline;

   procedure Close (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      Close_Inline (Item);
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

   procedure Before_Event (Item : in out Session; Event : SDL3.Events.Event) is
      State : Grammar_State renames Item.Grammar_Checks;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Event.Kind in SDL3.Events.Mouse_Down | SDL3.Events.Mouse_Up | SDL3.Events.Mouse_Move |
        SDL3.Events.Mouse_Wheel | SDL3.Events.Pinch
      then
         State.Pointer_Known := True;
         State.Pointer_X := Event.Mouse_X;
         State.Pointer_Y := Event.Mouse_Y;
         if Event.Kind = SDL3.Events.Mouse_Move then
            State.Pointer_Held := Event.Left_Held;
         elsif Event.Kind in SDL3.Events.Mouse_Down | SDL3.Events.Mouse_Up and then Event.Button = 1 then
            State.Pointer_Held := Event.Kind = SDL3.Events.Mouse_Down;
         end if;
      end if;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
            if State.Inline_Open and then not Widgets.Contains
              (State.Inline_Menu, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
            then
               Close_Inline (Item);
            end if;
            State.Press_Rank := 0;
            if Basics.Active (Item) and then Event.Button = 1 and then Event.Clicks <= 1
              and then not Event.Shift and then not Event.Command and then not Event.Option
            then
               declare
                  Hit : constant Widgets.Widget_Access :=
                    Widgets.Hit (Item.Root.Widgets, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels);
               begin
                  if Hit /= null then
                     for Rank in 1 .. Item.Reading.Write_Count loop
                        if Widgets.Id_Of (Hit.all) = Widgets.Id_Of (Item.Docs.Pages (Rank).Text) then
                           State.Press_Rank := Rank;
                           State.Press_X := Event.Mouse_X;
                           State.Press_Y := Event.Mouse_Y;
                           exit;
                        end if;
                     end loop;
                  end if;
               end;
            end if;
         when SDL3.Events.Mouse_Move =>
            if abs (Event.Mouse_X - State.Press_X) > 4.0 or else abs (Event.Mouse_Y - State.Press_Y) > 4.0 then
               State.Press_Rank := 0;
            end if;
         when SDL3.Events.Key_Down | SDL3.Events.Text_Input | SDL3.Events.Text_Editing | SDL3.Events.Pinch =>
            Close_Inline (Item);
         when SDL3.Events.Mouse_Wheel =>
            State.Press_Rank := 0;
            if State.Inline_Open and then not Widgets.Contains
              (State.Inline_Menu, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
            then
               Close_Inline (Item);
            end if;
         when others => null;
      end case;
   end Before_Event;

   procedure Build (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
      use Layouts;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, State.Popout);
      Panels.Set_Fill (State.Popout, Pomarine.Themes.Background);
      Panels.Set_Border (State.Popout, Pomarine.Themes.Border);
      Panels.Set_Shadow (State.Popout, Pomarine.Themes.Shadow);
      Panels.Set_Radius (State.Popout, Pomarine.Themes.Large_Radius);
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
         Hooks.On (State.Cards (Index), Widgets.Click, Item'Unchecked_Access, Cards.Expand'Access);
         Widgets.Set_Visible (State.Cards (Index), False);
      end loop;
      for Number in State.Actions'Range loop
         Widgets.Add (State.Content, State.Actions (Number));
         Buttons.Set_Label (State.Actions (Number), "Apply");
         Buttons.Set_Focusable (State.Actions (Number), True);
         Buttons.Set_Kind (State.Actions (Number), Buttons.Primary);
         Set_Layout (State.Actions (Number), Place => Absolute, Width => 56.0, Height => 28.0);
         Widgets.Set_Tag (State.Actions (Number), Widgets.No_Tag, Number);
         Hooks.On (State.Actions (Number), Widgets.Click, Item'Unchecked_Access, Cards.Apply'Access);
         Widgets.Set_Visible (State.Actions (Number), False);
      end loop;
      Widgets.Add (State.Content, State.Measure_Card);
      Widgets.Set_Visible (State.Measure_Card, False);
      Hooks.On (Item.Page_View.Grammar_Count, Widgets.Click, Item'Unchecked_Access, Cards.Toggle'Access);
      Widgets.Set_Visible (State.Popout, False);
      Widgets.Add (Item.Toolbar.Content_Panel, State.Inline_Menu);
      Set_Layout (State.Inline_Menu, Place => Absolute, Width => 200.0);
      Hooks.On (State.Inline_Menu, Widgets.Choose, Item'Unchecked_Access, Cards.Inline_Chosen'Access);
      Widgets.Set_Visible (State.Inline_Menu, False);
      pragma Assert (Menus.Text_Capacity >= Harper.Max_Replacement);
   end Build;

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

   procedure Update_Cursor (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Hit : Widgets.Widget_Access;
   begin
      State.Over_Diagnostic := False;
      if not Basics.Active (Item) or else not State.Pointer_Known or else State.Pointer_Held then
         return;
      end if;
      Hit := Widgets.Hit (Item.Root.Widgets, State.Pointer_X * Pixels, State.Pointer_Y * Pixels);
      if Hit = null then
         return;
      end if;
      for Rank in 1 .. Item.Reading.Write_Count loop
         if Widgets.Id_Of (Hit.all) = Widgets.Id_Of (Item.Docs.Pages (Rank).Text) then
            declare
               Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Rank).Text).all;
               Doc : Docs.Document renames Areas.Document (Area).all;
            begin
               for Row of State.Rows loop
                  if Row.Rank = Rank and then Basics.Valid (Item, Row)
                    and then Row.Lint.Location.First < Row.Lint.Location.Last
                    and then Areas.Is_Over_Range
                      (Area, Basics.Advance (Doc, Row.First, Row.Lint.Location.First),
                       Basics.Advance (Doc, Row.First, Row.Lint.Location.Last),
                       State.Pointer_X * Pixels, State.Pointer_Y * Pixels)
                  then
                     State.Over_Diagnostic := True;
                     return;
                  end if;
               end loop;
            end;
            return;
         end if;
      end loop;
   end Update_Cursor;

   procedure Released (Item : in out Session; Event : SDL3.Events.Event) is
      State : Grammar_State renames Item.Grammar_Checks;
      Rank : constant Natural := State.Press_Rank;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Event.Kind /= SDL3.Events.Mouse_Up then
         return;
      end if;
      State.Press_Rank := 0;
      if not Basics.Active (Item) or else Event.Button /= 1 or else Rank = 0
        or else Rank > Item.Reading.Write_Count
        or else abs (Event.Mouse_X - State.Press_X) > 4.0 or else abs (Event.Mouse_Y - State.Press_Y) > 4.0
      then
         return;
      end if;
      declare
         Hit : constant Widgets.Widget_Access :=
           Widgets.Hit (Item.Root.Widgets, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels);
         Area : Areas.Text_Area renames Editors.Area (Item.Docs.Pages (Rank).Text).all;
         Doc : Docs.Document renames Areas.Document (Area).all;
         First_Match : Natural := 0;
         Wide : Float := 140.0;
         Parent_Left : constant Float := Widgets.Left_Of (Item.Toolbar.Content_Panel) / Pixels;
         Parent_Top : constant Float := Widgets.Top_Of (Item.Toolbar.Content_Panel) / Pixels;
         Parent_Wide : constant Float := Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels;
         Parent_High : constant Float := Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels;
         use Layouts;
      begin
         if Hit = null or else Widgets.Id_Of (Hit.all) /= Widgets.Id_Of (Item.Docs.Pages (Rank).Text)
           or else Areas.Has_Selection (Area) or else Areas.Is_Composing (Area)
         then
            return;
         end if;
         Close_Inline (Item);
         Menus.Clear (State.Inline_Menu);
         for Index in 1 .. State.Rows.Count loop
            declare
               Row : Grammar_Row renames State.Rows (Index);
            begin
               if Row.Rank = Rank and then Basics.Valid (Item, Row)
                 and then Row.Lint.Location.First < Row.Lint.Location.Last
                 and then Areas.Is_Over_Range
                   (Area, Basics.Advance (Doc, Row.First, Row.Lint.Location.First),
                    Basics.Advance (Doc, Row.First, Row.Lint.Location.Last),
                    Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
               then
                  if First_Match = 0 then
                     First_Match := Index;
                  end if;
                  for Number in 1 .. Row.Lint.Suggestion_Count loop
                     exit when State.Inline_Count = State.Inline_Choices'Length;
                     declare
                        Replacement : constant String :=
                          Harper.Replacements.To_String (Row.Lint.Suggestions (Number).Text);
                        Label : String := (if Replacement'Length = 0 then "Delete" else Replacement);
                     begin
                        for C of Label loop
                           if C in ASCII.LF | ASCII.CR | ASCII.HT then
                              C := ' ';
                           end if;
                        end loop;
                        Menus.Add (State.Inline_Menu, Menus.Action, Label);
                        State.Inline_Count := State.Inline_Count + 1;
                        State.Inline_Choices (State.Inline_Count) := (Index, Number, Row.Token);
                        Wide := Float'Max (Wide,
                          Pomarine.Line_Texts.Width (Item.Host.Lines, Label, Pixels) / Pixels + 40.0);
                     end;
                  end loop;
               end if;
            end;
            exit when State.Inline_Count = State.Inline_Choices'Length;
         end loop;
         if First_Match = 0 then
            return;
         elsif State.Inline_Count = 0 then
            Menus.Add (State.Inline_Menu, Menus.Note, "No suggested fixes");
            State.Inline_Count := 1;
            State.Inline_Choices (1) := (First_Match, 0, State.Rows (First_Match).Token);
            Wide := 180.0;
         end if;
         Wide := Float'Max (80.0, Float'Min (Float'Min (Wide, 380.0), Parent_Wide - 16.0));
         Menus.Set_Max_Height (State.Inline_Menu, Float'Max (40.0, Float'Min (240.0, Parent_High - 16.0)));
         declare
            High : constant Float := Menus.Shown_Height (State.Inline_Menu);
            Left : constant Float := Float'Max (8.0, Float'Min (Event.Mouse_X - Parent_Left, Parent_Wide - Wide - 8.0));
            Below : constant Float := Event.Mouse_Y - Parent_Top + 14.0;
            Top : constant Float := Float'Max (8.0,
              (if Below + High <= Parent_High - 8.0 then Below else Event.Mouse_Y - Parent_Top - High - 8.0));
         begin
            Set_Layout (State.Inline_Menu, Width => Wide,
                        Position => (Left => Left, Top => Top, others => <>));
         end;
         State.Inline_Open := True;
         Widgets.Set_Visible (State.Inline_Menu, True);
         Widgets.Raise_To_Front (State.Inline_Menu);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end;
   end Released;

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
      if Basics.Active (Item) then
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

      for Index in 1 .. State.Rows.Count loop
         if State.Rows (Index).Token /= 0 and then not Basics.Valid (Item, State.Rows (Index)) then
            State.Rows (Index).Token := 0;
            if State.Expanded = Index then
               State.Expanded := 0;
            end if;
            State.Dirty := True;
         end if;
      end loop;
      if State.Inline_Open then
         for Number in 1 .. State.Inline_Count loop
            declare
               Choice : Grammar_Choice renames State.Inline_Choices (Number);
            begin
               if Choice.Row = 0 or else not Basics.Valid (Item, State.Rows (Choice.Row))
                 or else Choice.Token /= State.Rows (Choice.Row).Token
               then
                  Close_Inline (Item);
                  exit;
               end if;
            end;
         end loop;
      end if;
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
                  if Basics.Active (Item) and then Worker.Rank <= Item.Reading.Write_Count
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
                                 Ink  : constant Pomarine.Themes.Color := Basics.Colors (Lint.Kind);
                              begin
                                 if Seen.Retained < Areas.Max_Highlights then
                                    Keep_Row (State, Worker, Lint, Seen);
                                 end if;
                                 if Lint.Location.First < Lint.Location.Last
                                   and then Areas.Highlight_Count (Area) < Areas.Max_Highlights
                                 then
                                    Areas.Add_Highlight
                                      (Area, Basics.Advance (Doc, Worker.First, Lint.Location.First),
                                       Basics.Advance (Doc, Worker.First, Lint.Location.Last),
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

      Cards.Refresh (Item);
      if not Basics.Active (Item) then
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
      if Basics.Active (Item) and then Available then
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
