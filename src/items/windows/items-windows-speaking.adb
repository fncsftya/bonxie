with Pomarine.Text_Areas;
with Icon_Set;
with Items.Windows.Metrics;

package body Items.Windows.Speaking is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Editors renames Pomarine.Widgets.Editors;

   use type Docs.Version;
   use type Texts.Position;

   procedure Take_Back_Live (Item : in out Window);
   --  Remove the text shown while listening, or, if the text has been
   --  changed since, keep it as it is.

   procedure Take_Back_Live (Item : in out Window) is
      Doc : Docs.Document renames Item.Content_Doc;
   begin
      if Item.Live_Shown then
         if Docs.Current (Doc) = Item.Live_Seen then
            Docs.Replace
              (Doc, Item.Live_From, Item.Live_To, "", Recorded => False);
         else
            Item.Live_Done := Item.Live_Upto;
            Item.Live_Moved := True;
         end if;
      end if;
      Pomarine.Text_Areas.Clear_Faint (Editors.Area (Item.Body_Text).all);
      Item.Live_Shown := False;
   end Take_Back_Live;

   function Unsaid (Item : Window; Spoken : String) return String is
     (if Item.Live_Done >= Spoken'Length then ""
      else Spoken (Spoken'First + Item.Live_Done .. Spoken'Last));
   --  What of Spoken is not yet in the text for good.

   function One_Line_Feeds (Said : String) return String;
   --  Said as it goes in a note: paragraphs are made by line feeds alone.

   function One_Line_Feeds (Said : String) return String is
   begin
      return Spoken : String := Said do
         for C of Spoken loop
            if C = ASCII.CR then
               C := ' ';
            end if;
         end loop;
      end return;
   end One_Line_Feeds;

   procedure Change
     (Item   : in out Window;
      To     : Dictations;
      Detail : String := "") is
   begin
      if To = Failed then
         Take_Back_Live (Item);
      end if;
      Item.Dictating := To;
      Widgets.Set_Visible (Item.Progress, To = Listening);
      Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, 0.0);
      Buttons.Set_Icon
        (Item.Speak_Button,
         (if To in Preparing | Listening
          then Icon_Set.Stop else Icon_Set.Microphone));
      Buttons.Set_Label
        (Item.Speak_Button,
         (if To in Preparing | Listening then "Stop" else "Dictate"));
      case To is
         when Silent =>
            Labels.Set_Text (Item.Status, "");
         when Preparing =>
            Labels.Set_Text (Item.Status, "Getting ready...");
         when Listening =>
            Labels.Set_Text (Item.Status, "Listening...");
         when Transcribing =>
            Labels.Set_Text (Item.Status, "Transcribing...");
         when Failed =>
            Labels.Set_Text
              (Item.Status, Labels.Fitted ("Could not dictate: " & Detail));
      end case;
   end Change;

   procedure Show_Level (Item : in out Window; To : Float) is
      Stepped : constant Float :=
        Float'Rounding (To * Metrics.Level_Steps) / Metrics.Level_Steps;
   begin
      if Item.Dictating = Listening
        and then Pomarine.Widgets.Progress_Bars.Value (Item.Progress) /= Stepped
      then
         Pomarine.Widgets.Progress_Bars.Set_Value (Item.Progress, Stepped);
      end if;
   end Show_Level;

   procedure Show_Live (Item : in out Window; Said : String; Settled : Natural := 0) is
      Area   : Pomarine.Text_Areas.Text_Area
        renames Editors.Area (Item.Body_Text).all;
      Doc    : Docs.Document renames Item.Content_Doc;
      Whole  : constant String := One_Line_Feeds (Said);
   begin
      if Item.Live_Shown and then Docs.Current (Doc) /= Item.Live_Seen then
         Take_Back_Live (Item);  --  keeps what was shown
      end if;
      if Docs.Current (Doc) /= Item.Live_Version then
         --  Being typed in: nothing is shown until it stops.
         Item.Live_Version := Docs.Current (Doc);
         return;
      end if;
      declare
         Spoken : constant String := Unsaid (Item, Whole);
         Fresh  : constant Natural :=
           (if Settled > Item.Live_Done then Settled - Item.Live_Done else 0);
      begin
         if not Item.Live_Shown then
            if Spoken = "" then
               return;
            end if;
            if Item.Live_Moved or else Widgets.Has_Focus (Item.Body_Text) then
               Item.Live_From := Pomarine.Text_Areas.Caret (Area);
               Item.Live_Break := False;
            else
               Item.Live_From := Docs.Text_End (Doc);
               Item.Live_Break := Docs.Byte_Length (Doc, Docs.Count (Doc)) /= 0;
            end if;
            Item.Live_To := Item.Live_From;
            Item.Live_Shown := True;
         end if;
         declare
            Shown : constant String :=
              (if Item.Live_Break then [ASCII.LF] else "") & Spoken;
         begin
            Item.Live_Upto := Item.Live_Done + Spoken'Length;
            if Docs.Between (Doc, Item.Live_From, Item.Live_To) /= Shown then
               Docs.Replace
                 (Doc, Item.Live_From, Item.Live_To, Shown, Recorded => False);
               if Pomarine.Text_Areas.Caret (Area) = Item.Live_From
                 and then Pomarine.Text_Areas.Mark (Area) = Item.Live_From
               then
                  --  Typing goes on after what is shown, not before it.
                  Item.Live_To := Texts.End_After (Item.Live_From, Shown);
                  Pomarine.Text_Areas.Select_Range (Area, Item.Live_To, Item.Live_To);
               else
                  Item.Live_To := Texts.End_After (Item.Live_From, Shown);
               end if;
               Item.Live_Seen := Docs.Current (Doc);
               Item.Live_Version := Item.Live_Seen;
            end if;
            declare
               --  What is not settled starts at a character's beginning.
               Edge : Natural := Natural'Min (Fresh, Spoken'Length);
            begin
               while Edge < Spoken'Length
                 and then Character'Pos (Spoken (Spoken'First + Edge)) in 16#80# .. 16#BF#
               loop
                  Edge := Edge + 1;
               end loop;
               if Edge < Spoken'Length then
                  Pomarine.Text_Areas.Set_Faint
                    (Area,
                     Texts.End_After
                       (Item.Live_From, Shown (Shown'First .. Shown'Last - (Spoken'Length - Edge))),
                     Item.Live_To);
               else
                  Pomarine.Text_Areas.Clear_Faint (Area);
               end if;
            end;
         end;
      end;
   end Show_Live;

   procedure Append_Said (Item : in out Window; Said : String) is
      Area   : Pomarine.Text_Areas.Text_Area renames Editors.Area (Item.Body_Text).all;
      Doc    : Docs.Document renames Item.Content_Doc;
      Whole  : constant String := One_Line_Feeds (Said);
   begin
      Take_Back_Live (Item);
      declare
         --  What was kept as typed text, while being dictated, is not put in again.
         Spoken   : constant String := Unsaid (Item, Whole);
         At_Caret : constant Boolean := Item.Live_Moved or else Widgets.Has_Focus (Item.Body_Text);
      begin
         Item.Live_Done := 0;
         Item.Live_Moved := False;
         if Spoken = "" then
            return;
         end if;
         if At_Caret then
            --  At the caret, not over what is selected.
            Pomarine.Text_Areas.Select_Range
              (Area, Pomarine.Text_Areas.Caret (Area), Pomarine.Text_Areas.Caret (Area));
            Pomarine.Text_Areas.Insert (Area, Spoken);
         else
            declare
               After : constant Texts.Position := Docs.Text_End (Doc);
               --  An empty last paragraph is filled, not left as a gap.
               Blank : constant Boolean :=
                 Docs.Byte_Length (Doc, Docs.Count (Doc)) = 0;
            begin
               Docs.Begin_Step (Doc);
               Docs.Replace
                 (Doc, After, After, (if Blank then "" else [ASCII.LF]) & Spoken);
               Docs.End_Step (Doc);
            end;
         end if;
      end;
   end Append_Said;

end Items.Windows.Speaking;
