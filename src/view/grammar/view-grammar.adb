with View.Menu_Commands;
with Pomarine.UI.Menus;
with Pomarine.UI;
with Grammar_Rules;
with Grammar_VM;
with Grammar_UI;
with Harper;
with Pomarine.Widgets.Buttons;
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
with Pomarine.Widgets.Text_Fields;
with View.Style;
with Texts.Documents;
with View.Grammar.Basics;
with View.Grammar.Cards;

package body View.Grammar is
   function Inspect
     (Item : Session; What : Grammar_VM.Card_Command; Index : Natural) return Grammar_VM.Card_State is
     (Cards.State_Of (Item, What, Index));

   procedure Perform (Item : in out Session; What : Grammar_VM.Card_Command; Index : Natural) is
   begin
      Cards.Run (Item, What, Index);
   end Perform;

   procedure Choose_Inline (Item : in out Session; Row : Positive) is
   begin
      Cards.Choose_Row (Item, Row);
   end Choose_Inline;

   package Docs renames Texts.Documents;
   package Areas renames Pomarine.Text_Areas;
   package Editors renames Pomarine.Widgets.Editors;
   package UI renames Pomarine.UI;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Menu_Rows renames Pomarine.UI.Menus;
   package Menus renames Pomarine.Widgets.Menus;
   package Panels renames Pomarine.Widgets.Panels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   use type Widgets.Widget_Access;
   use type Widgets.Node_Id;
   use type Pomarine.Events.Event_Kind;
   use type Docs.Version;
   use type Harper.Request_Id;
   use type Harper.Check_Status;
   use type Pomarine.Events.Milliseconds;
   use type Texts.Position;

   Entry_Width : constant := 288.0;

   Suggestion_Room : constant := 61;
   --  Of the inline menu's choices, those for fixes: three are kept for the line and the two rules' commands.

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

   procedure Entry_Ended (Item : in out Session; Accepted : Boolean) is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if Widgets.Has_Focus (State.Entry_Field) or else Widgets.Has_Focus (State.Entry_Ok)
        or else Widgets.Has_Focus (State.Entry_Cancel)
      then
         Widgets.Focus (Item.Page_View.Grammar_Count);
      end if;
      if Accepted then
         Cards.Rules_Changed (Item);
      end if;
   end Entry_Ended;

   procedure Close_Entry (Item : in out Session) is
   begin
      if Grammar_VM.Can_Execute (Item.Grammar_Model.Model, Grammar_VM.Cancel_Entry) then
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Cancel_Entry);
      end if;
      UI.Synchronize (Item.Forms (Grammar_Region).Screen.all);
   end Close_Entry;

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
         if Widgets.Has_Focus (State.Add_Rule) or else Widgets.Has_Focus (State.Ignore_Text) then
            Widgets.Focus (Item.Page_View.Grammar_Count);
         end if;
      end if;
      Close_Entry (Item);
      Widgets.Set_Visible (State.Add_Rule, False);
      Widgets.Set_Visible (State.Ignore_Text, False);
      State.Showing := False;
      Widgets.Set_Visible (State.Popout, False);
   end Close;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Item.Grammar_Checks.Showing
        and then not Widgets.Contains (Item.Grammar_Checks.Popout, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (Item.Page_View.Grammar_Count, X * Pixels, Y * Pixels)
        and then not (Grammar_VM.Is_Entering (Item.Grammar_Model.Model)
                      and then Widgets.Contains (Item.Grammar_Checks.Entry_Panel, X * Pixels, Y * Pixels))
      then
         --  The form that makes a rule is over the content, and part of the list.
         Close (Item);
      end if;
   end Pressed;

   procedure Before_Event (Item : in out Session; Event : Pomarine.Events.Event) is
      State : Grammar_State renames Item.Grammar_Checks;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Event.Kind in Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up | Pomarine.Events.Mouse_Move |
        Pomarine.Events.Mouse_Wheel | Pomarine.Events.Pinch
      then
         State.Pointer_Known := True;
         State.Pointer_X := Event.Mouse_X;
         State.Pointer_Y := Event.Mouse_Y;
         if Event.Kind = Pomarine.Events.Mouse_Move then
            State.Pointer_Held := Event.Left_Held;
         elsif Event.Kind in Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up and then Event.Button = 1 then
            State.Pointer_Held := Event.Kind = Pomarine.Events.Mouse_Down;
         end if;
      end if;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
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
                     for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
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
         when Pomarine.Events.Mouse_Move =>
            if abs (Event.Mouse_X - State.Press_X) > 4.0 or else abs (Event.Mouse_Y - State.Press_Y) > 4.0 then
               State.Press_Rank := 0;
            end if;
         when Pomarine.Events.Key_Down | Pomarine.Events.Text_Input | Pomarine.Events.Text_Editing
            | Pomarine.Events.Pinch =>
            Close_Inline (Item);
         when Pomarine.Events.Mouse_Wheel =>
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
      Item.Grammar_Reactions.Owner := Item'Unchecked_Access;
      Grammar_VM.Observe (Item.Grammar_Model.Model, Item.Grammar_Reactions'Access);
      Grammar_VM.Attach_Cards (Item.Grammar_Model.Model, Item.Grammar_Reactions'Access);
      Text_Fields.Set_Shared (State.Entry_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure (State.Entry_Field, Pomarine.Line_Texts.Interface_Font, View.Style.Edit_Size);
      Text_Fields.Attach (State.Entry_Field, State.Entry_Doc'Unchecked_Access);
      Open (Item.Forms (Grammar_Region), Item.Root.Widgets'Unchecked_Access, Grammar_Region);
      declare
         Form : UI.View renames Item.Forms (Grammar_Region).Screen.all;
         Bound : constant Grammar_UI.Controls.Context'Class := Grammar_UI.Controls.Bind
           (Form, Item.Grammar_Model.Model'Access);
         Prompt : constant UI.Label_Handle := Bound.Borrow_Label (State.Entry_Prompt, Grammar_UI.Prompt);
         Field : constant UI.Field_Handle := Bound.Borrow_Field
           (State.Entry_Field, State.Entry_Doc, Grammar_UI.Correction);
         Accept_Button : constant UI.Button_Handle := Bound.Borrow_Button (State.Entry_Ok, Grammar_VM.Accept_Entry);
         Cancel_Button : constant UI.Button_Handle := Bound.Borrow_Button (State.Entry_Cancel, Grammar_VM.Cancel_Entry);

         Rows : UI.Layout_Array (1 .. 1 + State.Cards'Length + State.Actions'Length + 3);
         Last : Natural := 0;

         procedure Add (Row : UI.Layout) is
         begin
            Last := Last + 1;
            Rows (Last) := Row;
         end Add;

         procedure Add_Footer_Button
           (Part : in out Buttons.Button; Caption : String; Wide : Float; Command : Grammar_VM.Card_Command)
         is
            Control : constant UI.Button_Handle := Bound.Borrow_Button (Part, Command);
         begin
            Buttons.Configure (Part, Buttons.Looks (Caption, Focusable => True));
            Add (UI.Styled (UI.Place (Control),
                            (Place => Absolute, Width => Layouts.Length_Of (Wide), Height => 28.0, others => <>)));
         end Add_Footer_Button;
      begin
         declare
            Toggle : constant UI.Widget_Handle := Bound.Borrow_Widget (Item.Page_View.Grammar_Count);
         begin
            Bound.On_Event (Toggle, Widgets.Click, Grammar_VM.Toggle_Cards);
         end;
         --  The cards of the suggestions, the buttons that apply them, and the ones of what is chosen in a
         --  card, are put by hand, over each other (Absolute), in the content of the scroller.
         Add (UI.Styled
                (UI.Put (Form, State.Empty),
                 (Place => Absolute, Position => (Top | Left => 8.0, others => <>), Height => 24.0, Width => 300.0,
                  others => <>)));
         for Index in State.Cards'Range loop
            declare
               Card : constant UI.Widget_Handle := Bound.Borrow_Widget (State.Cards (Index));
            begin
               Bound.On_Event (Card, Widgets.Click, Grammar_VM.Expand_Card, Index);
               Add (UI.Styled (UI.Place (Card), (Place => Absolute, Width => 320.0, Height => 40.0, others => <>)));
            end;
         end loop;
         for Number in State.Actions'Range loop
            declare
               Action : constant UI.Button_Handle :=
                 Bound.Borrow_Button (State.Actions (Number), Grammar_VM.Apply_Fix, Number);
            begin
               Buttons.Configure (State.Actions (Number), Buttons.Looks ("Apply", Buttons.Primary, Focusable => True));
               Add (UI.Styled (UI.Place (Action), (Place => Absolute, Width => 56.0, Height => 28.0, others => <>)));
            end;
         end loop;
         Add_Footer_Button (State.Add_Rule, "Add rule", 76.0, Grammar_VM.Edit_Rule);
         Add_Footer_Button (State.Ignore_Text, "Ignore", 60.0, Grammar_VM.Ignore_Text);
         Add (UI.Put (Form, State.Measure_Card));

         declare
            Scrolled : constant UI.Layout :=
              UI.Styled
                (UI.Put_In
                   (Form, State.Scroll,
                    [UI.Styled
                       (UI.Put_In (Form, State.Content, Rows),
                        (Height => 40.0, Flow => Column, Shrink => 0.0, others => <>))]),
                 (Grow => 1.0, Height => 0.0, others => <>));
            Heading : constant UI.Layout :=
              UI.Styled (UI.Put (Form, State.Heading), (Height => 32.0, Shrink => 0.0, others => <>));
            Popout : constant UI.Layout :=
              UI.Styled
                (UI.Put_In (Form, State.Popout, [Heading, Scrolled]),
                 (Place => Absolute, Width => 360.0, Height => 520.0, Flow => Column, Outlined => On,
                  Shadowed => On, Padding => (others => 8.0), others => <>));
            Inline : constant UI.Layout :=
              Menu_Commands.Place (Item, Form, State.Inline_Menu, Menu_VM.Grammar_Menu,
                                   (Place => Absolute, Width => 200.0, others => <>));

            Buttons_Row : constant UI.Layout :=
              UI.Styled
                (UI.Put_In
                   (Form, State.Entry_Row,
                    [UI.Place (Accept_Button, Width => 76.0, Height => 28.0, Exact => True),
                     UI.Place (Cancel_Button, Width => 64.0, Height => 28.0, Exact => True)],
                    Flow => Layouts.Row),
                 (Height => 28.0, Shrink => 0.0, Flow => Layouts.Row, Gap => 8.0, Spread => Between, others => <>));
            Entry_Box : constant UI.Layout :=
              UI.Styled
                (UI.Put_In
                   (Form, State.Entry_Panel,
                    [UI.Place (Prompt, Height => 22.0, Shrink => 0.0, Exact => True),
                     UI.Place (Field, Height => 36.0, Shrink => 0.0, Exact => True),
                     Buttons_Row]),
                 (Place => Absolute, Width => Layouts.Length_Of (Entry_Width), Height => 124.0, Flow => Column,
                  Outlined => On,
                  Shadowed => On, Padding => (others => 8.0), Gap => 6.0, others => <>));
         begin
            Buttons.Configure (State.Entry_Ok, Buttons.Looks ("Add rule", Buttons.Primary, Focusable => True));
            Buttons.Configure (State.Entry_Cancel, Buttons.Looks ("Cancel", Focusable => True));
            Bound.On_Event (UI.Any (Field), Widgets.Submit, Grammar_VM.Accept_Entry);
            Bound.Show_When (Entry_Box, Grammar_UI.Entering);
            UI.Mount_Into (Form, Content_Panel (Item).all, Popout);
            UI.Mount_Into (Form, Content_Panel (Item).all, Inline);
            UI.Mount_Into (Form, Content_Panel (Item).all, Entry_Box);
         end;
      end;

      Panels.Set_Fill (State.Popout, Pomarine.Themes.Background);
      Panels.Set_Border (State.Popout, Pomarine.Themes.Border);
      Panels.Set_Shadow (State.Popout, Pomarine.Themes.Shadow);
      Panels.Set_Radius (State.Popout, Pomarine.Themes.Large_Radius);
      Labels.Set_Text (State.Heading, "Grammar Suggestions");
      Labels.Set_Style (State.Heading, Pomarine.Line_Texts.Heading);
      Labels.Set_Text (State.Empty, "No grammar suggestions");
      for Index in State.Cards'Range loop
         Widgets.Set_Visible (State.Cards (Index), False);
      end loop;
      for Number in State.Actions'Range loop
         Widgets.Set_Visible (State.Actions (Number), False);
      end loop;
      Widgets.Set_Visible (State.Add_Rule, False);
      Widgets.Set_Visible (State.Ignore_Text, False);
      Widgets.Set_Visible (State.Measure_Card, False);
      Widgets.Set_Visible (State.Popout, False);
      Widgets.Set_Visible (State.Inline_Menu, False);
      Panels.Set_Fill (State.Entry_Panel, Pomarine.Themes.Background);
      Panels.Set_Border (State.Entry_Panel, Pomarine.Themes.Border);
      Panels.Set_Shadow (State.Entry_Panel, Pomarine.Themes.Shadow);
      Panels.Set_Radius (State.Entry_Panel, Pomarine.Themes.Large_Radius);
   end Build;

   procedure Recheck (Item : in out Session) is
   begin
      Close_Inline (Item);
      for Row of Item.Grammar_Checks.Rows loop
         Row.Token := 0;
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
   end Recheck;

   procedure Reset (Item : in out Session) is
   begin
      Close (Item);
      Grammar_VM.Forget (Item.Grammar_Model.Model);
      for Card of Item.Grammar_Checks.Cards loop
         Widgets.Set_Visible (Card, False);
      end loop;
      Recheck (Item);
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
      for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
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

   procedure Released (Item : in out Session; Event : Pomarine.Events.Event) is
      State : Grammar_State renames Item.Grammar_Checks;
      Rank : constant Natural := State.Press_Rank;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Event.Kind /= Pomarine.Events.Mouse_Up then
         return;
      end if;
      State.Press_Rank := 0;
      if not Basics.Active (Item) or else Event.Button /= 1 or else Rank = 0
        or else Rank > Trees.Page_Count (Item.Docs.Ordering)
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
         Parent_Left : constant Float := Widgets.Left_Of (Content_Panel (Item).all) / Pixels;
         Parent_Top : constant Float := Widgets.Top_Of (Content_Panel (Item).all) / Pixels;
         Parent_Wide : constant Float := Widgets.Width_Of (Content_Panel (Item).all) / Pixels;
         Parent_High : constant Float := Widgets.Height_Of (Content_Panel (Item).all) / Pixels;
         Content : Menu_Rows.Content;
         use Layouts;
      begin
         if Hit = null or else Widgets.Id_Of (Hit.all) /= Widgets.Id_Of (Item.Docs.Pages (Rank).Text)
           or else Areas.Has_Selection (Area) or else Areas.Is_Composing (Area)
         then
            return;
         end if;
         Close_Inline (Item);

         for Pass in 1 .. 2 loop
            for Index in 1 .. State.Rows.Count loop
               declare
                  Mark : Grammar_Row renames State.Rows (Index);
               begin
                  --  Those the project's rules made come first.
                  if Mark.Rank = Rank and then Basics.Valid (Item, Mark)
                    and then Mark.Lint.Custom = (Pass = 1)
                    and then Mark.Lint.Location.First < Mark.Lint.Location.Last
                    and then Areas.Is_Over_Range
                      (Area, Basics.Advance (Doc, Mark.First, Mark.Lint.Location.First),
                       Basics.Advance (Doc, Mark.First, Mark.Lint.Location.Last),
                       Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
                  then
                     if First_Match = 0 then
                        First_Match := Index;
                     end if;
                     for Number in 1 .. Mark.Lint.Suggestion_Count loop
                        exit when State.Inline_Count = Suggestion_Room;
                        declare
                           Replacement : constant String :=
                             Harper.Replacements.To_String (Mark.Lint.Suggestions (Number).Text);
                           Label : String := (if Replacement'Length = 0 then "Delete" else Replacement);
                        begin
                           for C of Label loop
                              if C in ASCII.LF | ASCII.CR | ASCII.HT then
                                 C := ' ';
                              end if;
                           end loop;
                           Content.Append (Menu_Rows.Row (Menus.Action, Label));
                           State.Inline_Count := State.Inline_Count + 1;
                           State.Inline_Choices (State.Inline_Count) :=
                             (Command => Apply_Suggestion, Row => Index, Suggestion => Number, Token => Mark.Token);
                           Wide := Float'Max (Wide,
                             Pomarine.Line_Texts.Width (Item.Host.Lines, Label, Pixels) / Pixels + 40.0);
                        end;
                     end loop;
                  end if;
               end;
               exit when State.Inline_Count = Suggestion_Room;
            end loop;
         end loop;
         if First_Match = 0 then
            return;
         elsif State.Inline_Count = 0 then
            Content.Append (Menu_Rows.Row (Menus.Note, "No suggested fixes"));
            State.Inline_Count := 1;
            State.Inline_Choices (1) := (Command => Nothing, Row => First_Match, Suggestion => 0,
                                         Token => State.Rows (First_Match).Token);
            Wide := 180.0;
         end if;
         --  The rules for the text under the pointer, after a line, as the card's buttons are.
         declare
            Token : constant Harper.Request_Id := State.Rows (First_Match).Token;
            Made  : constant Boolean := State.Rows (First_Match).Lint.Custom;

            procedure Add_Command (Label : String; Which : Choice_Command) is
            begin
               Content.Append (Menu_Rows.Row (Menus.Action, Label));
               State.Inline_Count := State.Inline_Count + 1;
               State.Inline_Choices (State.Inline_Count) :=
                 (Command => Which, Row => First_Match, Suggestion => 0, Token => Token);
            end Add_Command;
         begin
            Content.Append (Menu_Rows.Row (Menus.Separator));
            State.Inline_Count := State.Inline_Count + 1;
            State.Inline_Choices (State.Inline_Count) :=
              (Command => Nothing, Row => First_Match, Suggestion => 0, Token => Token);
            Add_Command ((if Made then "Remove rule" else "Add rule"), (if Made then Remove_Rule else Add_Rule));
            Add_Command ("Ignore", Ignore_Text);
         end;
         Menu_Rows.Set_Content (State.Inline_Menu, Content);
         Wide := Float'Max (80.0, Float'Min (Float'Min (Wide, 380.0), Parent_Wide - 16.0));
         Menus.Set_Max_Height (State.Inline_Menu, Float'Max (40.0, Float'Min (240.0, Parent_High - 16.0)));
         declare
            High : constant Float := Menus.Shown_Height (State.Inline_Menu);
            Left : constant Float := Float'Max (8.0, Float'Min (Event.Mouse_X - Parent_Left, Parent_Wide - Wide - 8.0));
            Below : constant Float := Event.Mouse_Y - Parent_Top + 14.0;
            Top : constant Float := Float'Max (8.0,
              (if Below + High <= Parent_High - 8.0 then Below else Event.Mouse_Y - Parent_Top - High - 8.0));
         begin
            Set_Layout (State.Inline_Menu, Width => Layouts.Length_Of (Wide),
                        Position => (Left => Layouts.Length_Of (Left), Top => Layouts.Length_Of (Top), others => <>));
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

   --  Chunks join paragraphs with LF, so Harper may flag a span running
   --  across a paragraph break; such a diagnostic cannot be shown or applied.
   procedure Drop_Cross_Paragraph (Chunk_Text : String; Result : in out Harper.Check_Result) is
      Kept : Natural := 0;
   begin
      for Index in 1 .. Result.Count loop
         declare
            Lint   : constant Harper.Diagnostic := Result.Lints (Index);
            Across : Boolean := False;
         begin
            for At_Byte in Lint.Location.First + 1 .. Natural'Min (Lint.Location.Last, Chunk_Text'Length) loop
               if Chunk_Text (Chunk_Text'First + At_Byte - 1) = ASCII.LF then
                  Across := True;
                  exit;
               end if;
            end loop;
            if not Across then
               Kept := Kept + 1;
               Result.Lints (Kept) := Lint;
            end if;
         end;
      end loop;
      Result.Count := Kept;
   end Drop_Cross_Paragraph;

   procedure Update (Item : in out Session; Now : Pomarine.Events.Milliseconds) is
      State : Grammar_State renames Item.Grammar_Checks;
      On    : constant Boolean := Pomarine.Widgets.Switches.Is_On (Item.Page_View.Grammar_Switch);
   begin
      UI.Synchronize (Item.Forms (Grammar_Region).Screen.all);
      if On /= State.Enabled then
         State.Enabled := On;
         Reset (Item);
      end if;

      --  Observe versions before collecting results: an edit, reload or
      --  page reordering must invalidate the previous generation first.
      if Basics.Active (Item) then
         Basics.Load_Rules (Item);
         for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
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
      if Screen (Item) /= Project or else View_Mode (Item) /= Write then
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
                  if Basics.Active (Item) and then Worker.Rank <= Trees.Page_Count (Item.Docs.Ordering)
                    and then Worker.Token = Seen.Token
                  then
                     Seen.Busy := False;
                     Seen.Cursor := Worker.Next_Position;
                     Seen.Finished := Worker.Last or else Result.Status /= Harper.Success;
                     if Result.Status = Harper.Success then
                        Drop_Cross_Paragraph (Worker.Text (1 .. Worker.Length), Result);
                        Grammar_Rules.Apply
                          (Grammar_VM.Current (Item.Grammar_Model.Model).all, Worker.Text (1 .. Worker.Length),
                           Result);
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
            for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
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
                           Worker.Length := Length;
                           Worker.Text (1 .. Length) := Buffer (1 .. Length);
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

   function Until_Update (Item : Session; Now : Pomarine.Events.Milliseconds) return Integer is
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
         for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
            declare
               Seen : Grammar_Document renames Item.Grammar_Checks.Documents (Rank);
            begin
               if not Seen.Busy and then not Seen.Finished then
                  declare
                     Due : constant Integer := Integer (Pomarine.Events.Milliseconds'Max (1, Seen.Due - Now));
                  begin
                     Wait := (if Wait < 0 then Due else Integer'Min (Wait, Due));
                  end;
               end if;
            end;
         end loop;
      end if;
      return Wait;
   end Until_Update;

   function Find (Item : Session; Marked : String; Custom : Boolean := False) return Natural is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      for Index in 1 .. State.Rows.Count loop
         if Basics.Valid (Item, State.Rows (Index)) and then Basics.Flagged (Item, State.Rows (Index)) = Marked
           and then (not Custom or else State.Rows (Index).Lint.Custom)
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Find;

   function Marking (Item : Session; Marked : String) return Natural is
      Total : Natural := 0;
   begin
      for Index in 1 .. Item.Grammar_Checks.Rows.Count loop
         if Basics.Valid (Item, Item.Grammar_Checks.Rows (Index))
           and then Basics.Flagged (Item, Item.Grammar_Checks.Rows (Index)) = Marked
         then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Marking;

   function Made_By_Rule (Item : Session; Marked : String) return Natural is
      Total : Natural := 0;
   begin
      for Index in 1 .. Item.Grammar_Checks.Rows.Count loop
         if Basics.Valid (Item, Item.Grammar_Checks.Rows (Index))
           and then Item.Grammar_Checks.Rows (Index).Lint.Custom
           and then Basics.Flagged (Item, Item.Grammar_Checks.Rows (Index)) = Marked
         then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Made_By_Rule;

   function First_Suggestion (Item : Session; Marked : String) return String is
      Index : constant Natural := Find (Item, Marked);
   begin
      return (if Index /= 0 and then Item.Grammar_Checks.Rows (Index).Lint.Suggestion_Count > 0
              then Harper.Replacements.To_String (Item.Grammar_Checks.Rows (Index).Lint.Suggestions (1).Text)
              else "");
   end First_Suggestion;

   function Rule_Count (Item : Session) return Natural is (Grammar_VM.Count (Item.Grammar_Model.Model));

   procedure Show (Item : in out Session) is
   begin
      if not Item.Grammar_Checks.Showing then
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Toggle_Cards);
      end if;
   end Show;

   function First_Card_Made_By_Rule (Item : Session) return Boolean is
     (Item.Grammar_Checks.Bindings (1) /= 0
      and then Item.Grammar_Checks.Rows (Item.Grammar_Checks.Bindings (1)).Lint.Custom);

   procedure Expand (Item : in out Session; Marked : String) is
      State : Grammar_State renames Item.Grammar_Checks;
      Index : constant Natural := Find (Item, Marked);
   begin
      if Index /= 0 and then State.Expanded /= Index then
         for Card in State.Bindings'Range loop
            if State.Bindings (Card) = Index then
               Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Expand_Card, Card);
               UI.Synchronize (Item.Forms (Grammar_Region).Screen.all);
               Widgets.Revalidate (Item.Root.Widgets);
               return;
            end if;
         end loop;
      end if;
   end Expand;

   procedure Begin_Rule (Item : in out Session; Marked : String) is
      State : Grammar_State renames Item.Grammar_Checks;
      Index : constant Natural := Find (Item, Marked);
   begin
      if Index /= 0 then
         State.Expanded := Index;
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Edit_Rule);
      end if;
   end Begin_Rule;

   procedure Ignore (Item : in out Session; Marked : String) is
      State : Grammar_State renames Item.Grammar_Checks;
      Index : constant Natural := Find (Item, Marked);
   begin
      if Index /= 0 then
         State.Expanded := Index;
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Ignore_Text);
      end if;
   end Ignore;

   procedure Correct (Item : in out Session; Marked, To : String) is
      State : Grammar_State renames Item.Grammar_Checks;
      Index : constant Natural := Find (Item, Marked);
   begin
      if Index /= 0 then
         State.Expanded := Index;
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Edit_Rule);
         if Grammar_VM.Is_Entering (Item.Grammar_Model.Model) then
            Grammar_VM.Set_Correction (Item.Grammar_Model.Model, To);
            if Grammar_VM.Can_Execute (Item.Grammar_Model.Model, Grammar_VM.Accept_Entry) then
               Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Accept_Entry);
               UI.Synchronize (Item.Forms (Grammar_Region).Screen.all);
            end if;
         end if;
      end if;
   end Correct;

   procedure Remove_Rule (Item : in out Session; Marked : String) is
      State : Grammar_State renames Item.Grammar_Checks;
      Index : constant Natural := Find (Item, Marked, Custom => True);
   begin
      if Index /= 0 then
         State.Expanded := Index;
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Edit_Rule);
      end if;
   end Remove_Rule;

end View.Grammar;
