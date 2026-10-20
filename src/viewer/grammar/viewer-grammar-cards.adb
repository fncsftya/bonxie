with Harper;
with Grammar_Cards;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Editors;
with Texts.Documents;
with Viewer.Grammar.Basics;

package body Viewer.Grammar.Cards is

   package Docs renames Texts.Documents;
   package Areas renames Pomarine.Text_Areas;
   package Editors renames Pomarine.Widgets.Editors;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;

   use type Harper.Request_Id;

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
            if Basics.Valid (Item, Row) then
               Total := Total + 1;
               if Row.Lint.Suggestion_Count > 0 then
                  Fixable := Fixable + 1;
               end if;
               declare
                  Height : Float := 40.0;
               begin
                  if State.Expanded = Index then
                     Grammar_Cards.Set_Diagnostic (State.Measure_Card, Row.Lint,
                       Labels.Text (Item.Docs.Pages (Row.Rank).Heading), Basics.Colors (Row.Lint.Kind));
                     Grammar_Cards.Set_Expanded (State.Measure_Card, True);
                     Height := Grammar_Cards.Height_For (State.Measure_Card, Card_Wide);
                  end if;
                  if Row_Top + Height >= Offset and then Row_Top <= Offset + High then
                     pragma Assert (Used < State.Cards'Length);
                     Used := Used + 1;
                     State.Bindings (Used) := Index;
                     Grammar_Cards.Set_Diagnostic (State.Cards (Used), Row.Lint,
                       Labels.Text (Item.Docs.Pages (Row.Rank).Heading), Basics.Colors (Row.Lint.Kind));
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
      Buttons.Set_Label (Item.Page_View.Grammar_Count, Basics.Image (Fixable));
      Set_Layout
        (Item.Page_View.Grammar_Count,
         Width => Float'Max (36.0, 12.0 + Float (Basics.Image (Fixable)'Length) * 8.0));
      Buttons.Set_Kind (Item.Page_View.Grammar_Count, (if Fixable = 0 then Buttons.Normal else Buttons.Warning));
      Widgets.Set_Accessible_Name
        (Item.Page_View.Grammar_Count, "Fixable grammar suggestions: " & Basics.Image (Fixable));
      Labels.Set_Text (State.Heading, Labels.Fitted ("Grammar Suggestions (" & Basics.Image (Total) & ")"));
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
      if Index not in State.Rows'Range or else not Basics.Valid (Item, State.Rows (Index)) then
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
               Update (Item, SDL3.Events.Ticks);
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
            if Choice.Row /= 0 and then Choice.Suggestion /= 0
              and then Choice.Token = State.Rows (Choice.Row).Token
            then
               Apply_Fix (Item, Choice.Row, Choice.Suggestion, Inline => True);
            end if;
         end;
      end if;
   end Inline_Chosen;

end Viewer.Grammar.Cards;
