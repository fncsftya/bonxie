with Pomarine.Boxes;
with Pomarine.Line_Texts;

package body Grammar_Cards is

   package Widgets renames Pomarine.Widgets;
   package Themes renames Pomarine.Themes;
   package Lines renames Pomarine.Line_Texts;
   use Widgets;
   use type Pomarine.Semantics.Action;

   Header : constant := 40.0;
   Line_High : constant := 18.0;

   function Kind_Name (Kind : Harper.Lint_Kind) return String is
     (case Kind is
         when Harper.Agreement => "Agreement", when Harper.Boundary_Error => "Boundary Error",
         when Harper.Capitalization => "Capitalization", when Harper.Eggcorn => "Eggcorn",
         when Harper.Enhancement => "Enhancement", when Harper.Formatting => "Formatting",
         when Harper.Grammar => "Grammar", when Harper.Malapropism => "Malapropism",
         when Harper.Miscellaneous => "Miscellaneous", when Harper.Nonstandard => "Nonstandard",
         when Harper.Punctuation => "Punctuation", when Harper.Readability => "Readability",
         when Harper.Redundancy => "Redundancy", when Harper.Regionalism => "Regionalism",
         when Harper.Repetition => "Repetition", when Harper.Spelling => "Spelling",
         when Harper.Style => "Style", when Harper.Typo => "Typo", when Harper.Usage => "Usage",
         when Harper.Word_Choice => "Word Choice", when Harper.Word_Order => "Word Order");

   function Diagnostic (Item : Card) return Harper.Diagnostic is (Item.Lint);
   function Expanded (Item : Card) return Boolean is (Item.Open);

   procedure Set_Diagnostic
     (Item : in out Card; Value : Harper.Diagnostic; Caption : String; Ink : Themes.Color) is
   begin
      Item.Lint := Value;
      Item.Caption_Length := Natural'Min (Caption'Length, Item.Caption'Length);
      --  Do not cut a UTF-8 character in a long document title.
      while Item.Caption_Length > 0 and then Item.Caption_Length < Caption'Length
        and then Character'Pos (Caption (Caption'First + Item.Caption_Length)) in 16#80# .. 16#BF#
      loop
         Item.Caption_Length := Item.Caption_Length - 1;
      end loop;
      Item.Caption (1 .. Item.Caption_Length) := Caption (Caption'First .. Caption'First + Item.Caption_Length - 1);
      Item.Ink := Ink;
      Item.Open := False;
      Item.Down := False;
      Set_Accessible_Help (Item, Harper.Messages.To_String (Value.Message));
      Invalidate (Item);
   end Set_Diagnostic;

   procedure Set_Expanded (Item : in out Card; To : Boolean) is
   begin
      Item.Open := To;
      Invalidate (Item);
   end Set_Expanded;

   function Next_Line (Item : Card; Text : String; First : Positive; Width : Float) return Positive is
      Last : Positive := First;
      Space : Natural := 0;
      Pixels : constant Float := Density (Item);
   begin
      while Last <= Text'Last loop
         if Text (Last) = ASCII.LF then
            return Last + 1;
         end if;
         declare
            After : Positive := Last + 1;
         begin
            while After <= Text'Last and then Character'Pos (Text (After)) in 16#80# .. 16#BF# loop
               After := After + 1;
            end loop;
            if Last > First and then Text_Lines (Item) /= null
              and then Lines.Width (Text_Lines (Item).all, Text (First .. After - 1), Pixels) > Width * Pixels
            then
               return (if Space > First then Space + 1 else Last);
            end if;
            if Text (Last) = ' ' then
               Space := Last;
            end if;
            Last := After;
         end;
      end loop;
      return Text'Last + 1;
   end Next_Line;

   function Text_Height (Item : Card; Text : String; Width : Float) return Float is
      First : Positive := Text'First;
      High : Float := 0.0;
   begin
      while First <= Text'Last loop
         First := Next_Line (Item, Text, First, Width);
         High := High + Line_High;
      end loop;
      return Float'Max (Line_High, High);
   end Text_Height;

   function Suggestion_Text (Item : Card; Number : Positive) return String is
      Text : constant String := Harper.Replacements.To_String (Item.Lint.Suggestions (Number).Text);
   begin
      return (if Text'Length = 0 then "Remove selected text" else Text);
   end Suggestion_Text;

   function Action_Top (Item : Card; Number : Positive; Width : Float) return Float is
      Top : Float := Header + Text_Height (Item, Item.Caption (1 .. Item.Caption_Length), Width - 24.0) + 6.0
        + Text_Height (Item, Harper.Messages.To_String (Item.Lint.Message), Width - 24.0) + 12.0;
   begin
      for Each in 1 .. Number - 1 loop
         Top := Top + Float'Max (36.0, Text_Height (Item, Suggestion_Text (Item, Each), Width - 100.0) + 8.0);
      end loop;
      return Top;
   end Action_Top;

   function Height_For (Item : Card; Width : Float) return Float is
   begin
      if not Item.Open then
         return Header;
      elsif Item.Lint.Suggestion_Count = 0 then
         return Header + 14.0 + Text_Height (Item, Item.Caption (1 .. Item.Caption_Length), Width - 24.0)
           + Text_Height (Item, Harper.Messages.To_String (Item.Lint.Message), Width - 24.0);
      else
         declare
            Last : constant Positive := Item.Lint.Suggestion_Count;
         begin
            return Action_Top (Item, Last, Width)
              + Float'Max (36.0, Text_Height (Item, Suggestion_Text (Item, Last), Width - 100.0) + 8.0) + 8.0;
         end;
      end if;
   end Height_For;

   overriding procedure Draw
     (Item : in out Card; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Wide : constant Float := Width_Of (Item) / Pixels;
      Left : constant Float := Left_Of (Item);
      Top : constant Float := Top_Of (Item);

      procedure Text_Block (Text : String; Y, Width : Float; Ink : Themes.Color) is
         First : Positive := Text'First;
         Row : Float := Y;
      begin
         while First <= Text'Last loop
            declare
               After : constant Positive := Next_Line (Item, Text, First, Width);
               Last : Natural := After - 1;
            begin
               while Last >= First and then Text (Last) in ' ' | ASCII.LF loop
                  Last := Last - 1;
               end loop;
               Lines.Draw (Text_Lines (Item).all, Target, Ink, Text (First .. Last),
                           Left + 12.0 * Pixels, Top + (Row + Line_High / 2.0) * Pixels, Pixels);
               First := After;
               Row := Row + Line_High;
            end;
         end loop;
      end Text_Block;
   begin
      Pomarine.Boxes.Draw_Flat
        (Target, Colors (Themes.Page), Colors (Themes.Border), Left, Top, Width_Of (Item), Height_Of (Item), Pixels,
         Radius => Themes.Large_Radius);
      SDL3.Painters.Fill_Rect (Target, Item.Ink, Left + 12.0 * Pixels, Top + 16.0 * Pixels,
                              8.0 * Pixels, 8.0 * Pixels);
      if Text_Lines (Item) = null then
         return;
      end if;
      Lines.Draw (Text_Lines (Item).all, Target, Colors (Themes.Foreground), Kind_Name (Item.Lint.Kind),
                  Left + 28.0 * Pixels, Top + 20.0 * Pixels, Pixels, Lines.Strong);
      Lines.Draw (Text_Lines (Item).all, Target, Colors (Themes.Muted), (if Item.Open then "-" else "+"),
                  Left + (Wide - 24.0) * Pixels, Top + 20.0 * Pixels, Pixels);
      if Item.Open then
         Text_Block (Harper.Messages.To_String (Item.Lint.Message),
                     Header + Text_Height (Item, Item.Caption (1 .. Item.Caption_Length), Wide - 24.0) + 6.0,
                     Wide - 24.0, Colors (Themes.Foreground));
         for Number in 1 .. Item.Lint.Suggestion_Count loop
            Text_Block (Suggestion_Text (Item, Number), Action_Top (Item, Number, Wide) + 5.0,
                        Wide - 100.0, Colors (Themes.Foreground));
         end loop;
      end if;
      if Has_Focus (Item) then
         Pomarine.Boxes.Outline (Target, Colors (Themes.Focus), Left, Top,
                                 Width_Of (Item), Header * Pixels, Pixels, Density => Pixels,
                                 Radius => Themes.Large_Radius, Round => Pomarine.Boxes.Top_Corners);
      end if;
   end Draw;

   overriding procedure Handle (Item : in out Card; Event : SDL3.Events.Event; Handled : out Boolean) is
      Over : constant Boolean := Contains (Item, Event.Mouse_X * Density (Item), Event.Mouse_Y * Density (Item))
        and then Event.Mouse_Y * Density (Item) < Top_Of (Item) + Header * Density (Item);
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               if Over then
                  Notify (Item, Click);
               end if;
               Handled := True;
            end if;
         when SDL3.Events.Key_Down =>
            if Has_Focus (Item) and then Event.Key in SDL3.Events.Key_Return | SDL3.Events.Key_Space then
               Notify (Item, Click);
               Handled := True;
            end if;
         when others => null;
      end case;
   end Handle;

   overriding procedure Focus_Changed (Item : in out Card; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding procedure Describe (Item : Card; Facts : in out Pomarine.Semantics.Description) is
   begin
      Facts.Kind := Pomarine.Semantics.Button;
      Pomarine.Semantics.Name_As (Facts, Kind_Name (Item.Lint.Kind) & ": "
                                  & Harper.Messages.To_String (Item.Lint.Message));
      Facts.Has_Expanded := True;
      Facts.Expanded := Item.Open;
      Facts.Focusable := True;
      Facts.Actions (Pomarine.Semantics.Click) := True;
      Facts.Actions (Pomarine.Semantics.Focus) := True;
   end Describe;

   overriding procedure Perform
     (Item : in out Card; Request : Pomarine.Semantics.Request; Done : out Boolean) is
   begin
      Done := True;
      if Request.Doing = Pomarine.Semantics.Click then
         Notify (Item, Click);
      elsif Request.Doing = Pomarine.Semantics.Focus then
         Focus (Item);
      else
         Done := False;
      end if;
   end Perform;

end Grammar_Cards;
