with Grammar_Rules;
with Grammar_VM;
with Harper;
with Pomarine.Widgets.Text_Fields;
with Grammar_Cards;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Editors;
with Texts.Documents;
with View.Grammar.Basics;

package body View.Grammar.Cards is

   package Docs renames Texts.Documents;
   package Areas renames Pomarine.Text_Areas;
   package Editors renames Pomarine.Widgets.Editors;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   Entry_Width : constant := 288.0;

   use type Harper.Request_Id;

   procedure Refresh (Item : in out Session) is
      State : Grammar_State renames Item.Grammar_Checks;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Parent_Left : constant Float := Widgets.Left_Of (Content_Panel (Item).all) / Pixels;
      Parent_Top : constant Float := Widgets.Top_Of (Content_Panel (Item).all) / Pixels;
      Parent_Wide : constant Float := Widgets.Width_Of (Content_Panel (Item).all) / Pixels;
      Parent_High : constant Float := Widgets.Height_Of (Content_Panel (Item).all) / Pixels;
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
      Widgets.Set_Visible (State.Add_Rule, False);
      Widgets.Set_Visible (State.Ignore_Text, False);
      State.Bindings := [others => 0];
      for Pass in 1 .. 2 loop
         for Index in 1 .. State.Rows.Count loop
            declare
               Mark : Grammar_Row renames State.Rows (Index);
            begin
               --  Those the project's rules made come first.
               if Basics.Valid (Item, Mark) and then Mark.Lint.Custom = (Pass = 1) then
                  Total := Total + 1;
                  if Mark.Lint.Suggestion_Count > 0 then
                     Fixable := Fixable + 1;
                  end if;
                  declare
                     Height : Float := 40.0;
                  begin
                     if State.Expanded = Index then
                        Grammar_Cards.Set_Diagnostic (State.Measure_Card, Mark.Lint,
                          Labels.Text (Item.Docs.Pages (Mark.Rank).Heading), Basics.Colors (Mark.Lint.Kind));
                        Grammar_Cards.Set_Expanded (State.Measure_Card, True);
                        Height := Grammar_Cards.Height_For (State.Measure_Card, Card_Wide);
                     end if;
                     if Row_Top + Height >= Offset and then Row_Top <= Offset + High then
                        pragma Assert (Used < State.Cards'Length);
                        Used := Used + 1;
                        State.Bindings (Used) := Index;
                        Grammar_Cards.Set_Diagnostic (State.Cards (Used), Mark.Lint,
                          Labels.Text (Item.Docs.Pages (Mark.Rank).Heading), Basics.Colors (Mark.Lint.Kind));
                        Grammar_Cards.Set_Expanded (State.Cards (Used), State.Expanded = Index);
                        Set_Layout (State.Cards (Used), Width => Card_Wide, Height => Height,
                                    Position => (Left => 4.0, Top => Row_Top, others => <>));
                        Widgets.Set_Visible (State.Cards (Used), True);
                        if State.Expanded = Index then
                           for Number in 1 .. Mark.Lint.Suggestion_Count loop
                              Set_Layout (State.Actions (Number), Position =>
                                (Left => Card_Wide - 64.0,
                                 Top => Row_Top + Grammar_Cards.Action_Top
                                   (State.Cards (Used), Number, Card_Wide), others => <>));
                              Widgets.Set_Accessible_Name (State.Actions (Number), "Apply: " &
                                (if Harper.Replacements.Length (Mark.Lint.Suggestions (Number).Text) = 0
                                 then "remove text"
                                 else Harper.Replacements.To_String (Mark.Lint.Suggestions (Number).Text)));
                              Widgets.Set_Visible (State.Actions (Number), True);
                           end loop;
                           declare
                              Foot : constant Float :=
                                Row_Top + Grammar_Cards.Footer_Top (State.Cards (Used), Card_Wide) + 8.0;
                              Wide_Rule : constant Float := (if Mark.Lint.Custom then 92.0 else 76.0);
                           begin
                              Buttons.Set_Label
                                (State.Add_Rule, (if Mark.Lint.Custom then "Remove rule" else "Add rule"));
                              Set_Layout (State.Add_Rule, Width => Wide_Rule,
                                          Position => (Left => 16.0, Top => Foot, others => <>));
                              Set_Layout (State.Ignore_Text, Width => 60.0,
                                          Position => (Left => 24.0 + Wide_Rule, Top => Foot, others => <>));
                              Widgets.Set_Visible (State.Add_Rule, True);
                              Widgets.Set_Visible (State.Ignore_Text, True);
                           end;
                        end if;
                     end if;
                     Row_Top := Row_Top + Height + 8.0;
                  end;
               end if;
            end;
         end loop;
      end loop;
      for Index in Used + 1 .. State.Cards'Last loop
         Widgets.Set_Visible (State.Cards (Index), False);
      end loop;
      Buttons.Set_Label (Item.Page_View.Grammar_Count, Basics.Image (Fixable));
      Set_Layout
        (Item.Page_View.Grammar_Count,
         Width => Float'Max (36.0, 12.0 + Float (Basics.Image (Fixable)'Length) * 8.0));
      Buttons.Set_Kind (Item.Page_View.Grammar_Count, (if Fixable = 0 then Buttons.Normal else Buttons.Warning));
      Widgets.Set_Accessible_Name
        (Item.Page_View.Grammar_Count, "Fixable grammar suggestions: " & Basics.Image (Fixable));
      Labels.Set_Text (State.Heading, "Grammar Suggestions (" & Basics.Image (Total) & ")");
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
      elsif Screen (Item) = Project and then View_Mode (Item) = Write then
         Close_Inline (Item);
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
            if Index /= 0 and then Basics.Valid (Item, State.Rows (Index)) then
               State.Expanded := (if State.Expanded = Index then 0 else Index);
               State.Dirty := True;
               Refresh (Item);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         end;
      end if;
   end Expand;

   procedure Apply_Fix (Item : in out Session; Index, Number : Positive; Inline : Boolean);

   procedure Apply_Fix (Item : in out Session; Index, Number : Positive; Inline : Boolean) is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if Index not in 1 .. State.Rows.Count or else not Basics.Valid (Item, State.Rows (Index)) then
         return;
      end if;
      declare
         Row : Grammar_Row renames State.Rows (Index);
         Lint : Harper.Diagnostic renames Row.Lint;
         Editor : Editors.Editor renames Item.Docs.Pages (Row.Rank).Text;
         Area : Areas.Text_Area renames Editors.Area (Editor).all;
         Doc : Docs.Document renames Areas.Document (Area).all;
      begin
         if Number in 1 .. Lint.Suggestion_Count and then not Areas.Is_Composing (Area)
           and then not Areas.Is_Read_Only (Area)
         then
            declare
               Fix : Harper.Suggestion renames Lint.Suggestions (Number);
               From : constant Texts.Position := Basics.Advance (Doc, Row.First, Fix.Location.First);
               To : constant Texts.Position := Basics.Advance (Doc, Row.First, Fix.Location.Last);
               Replacement : constant String := Harper.Replacements.To_String (Fix.Text);
            begin
               Areas.Replace_Range (Area, From, To, Replacement);
               Widgets.Invalidate (Editor);
               if Inline then
                  Widgets.Focus (Editor);
               else
                  Widgets.Focus (Item.Page_View.Grammar_Count);
               end if;
               State.Expanded := 0;
               Update (Item, Pomarine.Events.Ticks);
            end;
         end if;
      end;
   end Apply_Fix;

   procedure Apply (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
   begin
      if Item.Grammar_Checks.Expanded /= 0 and then Event.Index > 0 then
         Apply_Fix (Item, Item.Grammar_Checks.Expanded, Event.Index, Inline => False);
      end if;
   end Apply;

   procedure Rules_Changed (Item : in out Session) is
   begin
      Basics.Load_Rules (Item);
      Recheck (Item);
      Update (Item, Pomarine.Events.Ticks);
   end Rules_Changed;

   procedure Ignore_Row (Item : in out Session; Index : Natural) is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if Index in 1 .. State.Rows.Count and then Basics.Valid (Item, State.Rows (Index)) then
         declare
            Marked : constant String := Basics.Flagged (Item, State.Rows (Index));
         begin
            if Marked'Length > 0 then
               Grammar_VM.Ignore
                 (Item.Grammar_Model.Model, Grammar_Rules.Kind_Code (State.Rows (Index).Lint.Kind), Marked);
               Widgets.Focus (Item.Page_View.Grammar_Count);
               Rules_Changed (Item);
            end if;
         end;
      end if;
   end Ignore_Row;

   procedure Remove_Row_Rule (Item : in out Session; Index : Natural) is
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if Index in 1 .. State.Rows.Count and then Basics.Valid (Item, State.Rows (Index))
        and then State.Rows (Index).Lint.Custom
      then
         declare
            Marked  : constant String := Basics.Flagged (Item, State.Rows (Index));
            Removed : Boolean;
         begin
            Grammar_VM.Remove_Correction (Item.Grammar_Model.Model, Marked, Removed);
            if Removed then
               Widgets.Focus (Item.Page_View.Grammar_Count);
               Rules_Changed (Item);
            end if;
         end;
      end if;
   end Remove_Row_Rule;

   procedure Begin_Entry (Item : in out Session; Index : Natural) is
      State : Grammar_State renames Item.Grammar_Checks;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Parent_Left : constant Float := Widgets.Left_Of (Content_Panel (Item).all) / Pixels;
      Parent_Top : constant Float := Widgets.Top_Of (Content_Panel (Item).all) / Pixels;
      Parent_Wide : constant Float := Widgets.Width_Of (Content_Panel (Item).all) / Pixels;
      Parent_High : constant Float := Widgets.Height_Of (Content_Panel (Item).all) / Pixels;
      use Layouts;
   begin
      if Index not in 1 .. State.Rows.Count or else not Basics.Valid (Item, State.Rows (Index)) then
         return;
      end if;
      declare
         Mark   : Grammar_Row renames State.Rows (Index);
         Marked : constant String := Basics.Flagged (Item, Mark);
         Wide   : constant Float := Float'Min (Entry_Width, Parent_Wide - 16.0);
      begin
         if Marked'Length = 0 then
            return;
         end if;
         Close_Inline (Item);
         --  Begin with the first fix Harper has, which is often what is wanted.
         Grammar_VM.Begin_Entry
           (Item.Grammar_Model.Model, Marked, Grammar_Rules.Kind_Code (Mark.Lint.Kind),
            (if Mark.Lint.Suggestion_Count > 0
             then Harper.Replacements.To_String (Mark.Lint.Suggestions (1).Text) else Marked));
         Docs.Load (State.Entry_Doc, Grammar_VM.Correction (Item.Grammar_Model.Model));
         Labels.Set_Text (State.Entry_Prompt, Grammar_VM.Prompt (Item.Grammar_Model.Model));
         Set_Layout (State.Entry_Panel, Width => Wide, Position =>
           (Left => Float'Max (8.0, Float'Min (State.Pointer_X - Parent_Left - Wide / 2.0, Parent_Wide - Wide - 8.0)),
            Top => Float'Max (8.0, Float'Min (State.Pointer_Y - Parent_Top + 12.0, Parent_High - 132.0)),
            others => <>));
         Widgets.Set_Visible (State.Entry_Panel, True);
         Widgets.Raise_To_Front (State.Entry_Panel);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (State.Entry_Field).all);
         Widgets.Focus (State.Entry_Field);
      end;
   end Begin_Entry;

   procedure Rule_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if State.Expanded in 1 .. State.Rows.Count and then Basics.Valid (Item, State.Rows (State.Expanded)) then
         if State.Rows (State.Expanded).Lint.Custom then
            Remove_Row_Rule (Item, State.Expanded);
         else
            Begin_Entry (Item, State.Expanded);
         end if;
      end if;
   end Rule_Clicked;

   procedure Ignore_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Ignore_Row (Item, Item.Grammar_Checks.Expanded);
   end Ignore_Clicked;

   procedure Entry_Accepted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if not Grammar_VM.Is_Entering (Item.Grammar_Model.Model) then
         return;
      end if;
      --  What was typed is the correction. One that changes nothing, or is longer than a suggestion can
      --  be, is not a rule.
      Grammar_VM.Set_Correction (Item.Grammar_Model.Model, Docs.Whole (State.Entry_Doc));
      if Grammar_VM.Can_Execute (Item.Grammar_Model.Model, Grammar_VM.Accept_Entry) then
         Grammar_VM.Execute (Item.Grammar_Model.Model, Grammar_VM.Accept_Entry);
         Close_Entry (Item);
         Rules_Changed (Item);
      end if;
   end Entry_Accepted;

   procedure Entry_Cancelled
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Close_Entry (Item);
   end Entry_Cancelled;

   procedure Inline_Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      State : Grammar_State renames Item.Grammar_Checks;
   begin
      if State.Inline_Open and then Event.Row in 1 .. State.Inline_Count then
         declare
            Choice : constant Grammar_Choice := State.Inline_Choices (Event.Row);
         begin
            Close_Inline (Item);
            if Choice.Row /= 0 and then Choice.Token = State.Rows (Choice.Row).Token then
               case Choice.Command is
                  when Nothing => null;
                  when Apply_Suggestion =>
                     if Choice.Suggestion /= 0 then
                        Apply_Fix (Item, Choice.Row, Choice.Suggestion, Inline => True);
                     end if;
                  when Add_Rule => Begin_Entry (Item, Choice.Row);
                  when Ignore_Text => Ignore_Row (Item, Choice.Row);
                  when Remove_Rule => Remove_Row_Rule (Item, Choice.Row);
               end case;
            end if;
         end;
      end if;
   end Inline_Chosen;

end View.Grammar.Cards;
