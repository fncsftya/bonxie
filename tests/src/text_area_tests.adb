with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with SDL3.Events;
with SDL3.Windows.Renderers;
with Texts.Documents;
with Goldens;
with Typeset.Samples;
with UI.Clipboards;
with UI.Text_Areas;
with UI.Themes;

package body Text_Area_Tests is

   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Text_Areas renames UI.Text_Areas;
   package Docs renames Texts.Documents;

   Colors : constant UI.Themes.Theme := UI.Themes.Light;

   Sample : constant String := Typeset.Samples.Document (200);

   function UTF_8 (Text : Wide_Wide_String) return String is
     (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));

   --  A text area in a target of its own, drawn in software

   Density : constant Float := 2.0;
   Width   : constant := 360;
   Height  : constant := 200;
   Margin  : constant := 12;
   --  In points: the target, and the space around the text area in it.

   type Fixture is limited record
      Target : Renderers.Renderer;
      Doc    : aliased Docs.Document;
      Area   : Text_Areas.Text_Area;  --  after Target and Doc
      Board  : UI.Clipboards.Memory_Clipboard;
   end record;

   procedure Open
     (Item    : in out Fixture;
      Content : String;
      Focus   : Boolean := True;
      Zoom    : Float := 1.0) is
   begin
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Width) * Density),
         Positive (Float (Height) * Density));
      Text_Areas.Configure
        (Item.Area, "Georgia", Size => 18.0, Measure => 640.0,
         Spacing => 8.0);
      Docs.Load (Item.Doc, Content);
      Text_Areas.Place
        (Item.Area,
         Left    => Float (Margin) * Density,
         Top     => Float (Margin) * Density,
         Width   => Float (Width - 2 * Margin) * Density,
         Height  => Float (Height - 2 * Margin) * Density,
         Density => Density,
         Zoom    => Zoom);
      Text_Areas.Attach (Item.Area, Item.Doc'Unchecked_Access);
      Text_Areas.Set_Focus (Item.Area, Focus);
   end Open;

   procedure Check (Item : in out Fixture; Name : String) is
      Drawn : Images.Image;
   begin
      Renderers.Clear (Item.Target, Colors.Background);
      Text_Areas.Draw (Item.Area, Item.Target, Colors);
      Images.Read (Drawn, Item.Target);
      Goldens.Check (Name, Drawn);
   end Check;

   --  Events, as SDL would give them

   procedure Send
     (Item  : in out Fixture;
      Event : Events.Event;
      Taken : Boolean := True)
   is
      Handled : Boolean;
   begin
      Text_Areas.Handle (Item.Area, Event, Item.Board, Handled);
      pragma Assert
        (Handled = Taken, "the text area did not take an event as it should");
   end Send;

   procedure Press
     (Item    : in out Fixture;
      Code    : Events.Key_Code;
      Times   : Positive := 1;
      Command : Boolean := False;
      Option  : Boolean := False;
      Shift   : Boolean := False) is
   begin
      for K in 1 .. Times loop
         Send (Item,
               (Kind => Events.Key_Down, Key => Code, Command => Command,
                Option => Option, Shift => Shift, others => <>));
      end loop;
   end Press;

   procedure Type_In (Item : in out Fixture; Text : String) is
   begin
      Send (Item, Events.Text_Event (Text));
   end Type_In;

   procedure Click
     (Item   : in out Fixture;
      X, Y   : Float;
      Clicks : Positive := 1;
      Shift  : Boolean := False) is
   begin
      Send (Item,
            (Kind => Events.Mouse_Down, Button => 1, Clicks => Clicks,
             Shift => Shift, Mouse_X => X, Mouse_Y => Y, others => <>));
      Send (Item,
            (Kind => Events.Mouse_Up, Button => 1, Mouse_X => X,
             Mouse_Y => Y, others => <>),
            Taken => False);
   end Click;
   --  At X, Y points.

   procedure Check_Selection
     (Name : String; Item : Fixture; Expected : String) is
   begin
      Goldens.Check_Text
        (Name, Expected, Text_Areas.Selected_Text (Item.Area));
   end Check_Selection;

   procedure Check_Text (Name : String; Item : Fixture; Expected : String) is
   begin
      Goldens.Check_Text (Name, Expected, Docs.Whole (Item.Doc));
   end Check_Text;

   --  The tests

   procedure Empty is
      Item : Fixture;
   begin
      Open (Item, "", Focus => False);
      Check (Item, "textarea-empty");
   end Empty;

   procedure Focused is
      Item : Fixture;
   begin
      --  The caret at the start, and the outline in the accent.
      Open (Item, "");
      Check (Item, "textarea-focused");
   end Focused;

   procedure Typing is
      Item : Fixture;
      First  : constant String := "Bonxies nest on moorland.";
      Second : constant String :=
        "They spend the winter at sea, far out over the Atlantic, and "
        & "come back to Shetland in the spring.";
   begin
      Open (Item, "");
      Type_In (Item, First);
      Press (Item, Events.Key_Return);
      Type_In (Item, Second);
      Goldens.Check_Text
        ("textarea-typing-text", First & ASCII.LF & Second,
         Docs.Whole (Item.Doc));
      Check (Item, "textarea-typing");
   end Typing;

   procedure Joining is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Press (Item, Events.Key_Down_Arrow);  --  to the second's start
      Press (Item, Events.Key_Backspace);   --  joins them
      Goldens.Check_Text
        ("textarea-joining-text", "Great skuaBonxie",
         Docs.Whole (Item.Doc));
      Press (Item, Events.Key_Backspace);
      Press (Item, Events.Key_Delete);
      Goldens.Check_Text
        ("textarea-deleting-text", "Great skuonxie",
         Docs.Whole (Item.Doc));
      Check (Item, "textarea-joining");
   end Joining;

   procedure Clusters is
      Item : Fixture;
   begin
      --  An emoji with a skin tone, and one with a variation selector,
      --  are each a character to move over and delete.
      Open (Item, UTF_8 ("Thumbs 👍🏽 up, mic 🎙️ on"));
      Press (Item, Events.Key_Right_Arrow, Times => 7);
      Press (Item, Events.Key_Delete);
      Goldens.Check_Text
        ("textarea-clusters-forward", UTF_8 ("Thumbs  up, mic 🎙️ on"),
         Docs.Whole (Item.Doc));

      Press (Item, Events.Key_Right_Arrow, Command => True);
      Press (Item, Events.Key_Left_Arrow, Times => 3);
      Press (Item, Events.Key_Backspace);
      Goldens.Check_Text
        ("textarea-clusters-backward", "Thumbs  up, mic  on",
         Docs.Whole (Item.Doc));

      Press (Item, Events.Key_Left_Arrow);
      Type_In (Item, UTF_8 ("🐦"));
      Check (Item, "textarea-clusters");
   end Clusters;

   procedure Up_And_Down is
      Item : Fixture;
   begin
      --  Across the lines of a paragraph and between paragraphs, as
      --  near as can be to where the caret started across.
      Open (Item, Sample);
      Press (Item, Events.Key_Right_Arrow, Times => 12);
      Press (Item, Events.Key_Down_Arrow, Times => 5);
      Press (Item, Events.Key_Up_Arrow);
      Check (Item, "textarea-up-down");
   end Up_And_Down;

   procedure Text_End is
      Item : Fixture;
   begin
      --  Scrolled just far enough to show the caret.
      Open (Item, Sample);
      Press (Item, Events.Key_Down_Arrow, Command => True);
      Check (Item, "textarea-end");

      Press (Item, Events.Key_Up_Arrow, Command => True);
      Check (Item, "textarea-start");
   end Text_End;

   procedure Scrolled is
      Item : Fixture;
   begin
      --  The caret stays at the start, out of view.
      Open (Item, Sample);
      Press (Item, Events.Key_Page_Down, Times => 2);
      Send (Item,
            (Kind => Events.Mouse_Wheel, Wheel_Y => -1.0,
             Mouse_X => Float (Width / 2), Mouse_Y => Float (Height / 2),
             others => <>));
      Check (Item, "textarea-scrolled");

      --  Typing brings it back.
      Type_In (Item, "Skua: ");
      Check (Item, "textarea-scrolled-back");
   end Scrolled;

   procedure Clicked is
      Item : Fixture;
   begin
      Open (Item, Sample, Focus => False);
      Click (Item, 150.0, 70.0);
      Goldens.Check_Text
        ("textarea-click-focuses", "TRUE",
         Text_Areas.Is_Focused (Item.Area)'Image);
      Check (Item, "textarea-clicked");

      --  Past the end of a line: before the space it breaks after, not
      --  at the start of the next line.
      Click (Item, 330.0, 80.0);
      Check (Item, "textarea-clicked-end");
   end Clicked;

   procedure Escape is
      Item : Fixture;
   begin
      Open (Item, Sample);
      Press (Item, Events.Key_Escape);
      Goldens.Check_Text
        ("textarea-escape-unfocuses", "FALSE",
         Text_Areas.Is_Focused (Item.Area)'Image);
   end Escape;

   procedure Zoomed is
      Item : Fixture;
   begin
      --  The lines wrap to the narrower width.
      Open (Item, Sample, Zoom => 1.5);
      Press (Item, Events.Key_Down_Arrow, Times => 2);
      Check (Item, "textarea-zoomed");
   end Zoomed;

   procedure Selecting_Keys is
      Item : Fixture;
   begin
      Open (Item, Sample);
      --  By words, then on by lines.
      Press (Item, Events.Key_Right_Arrow, Times => 3,
             Option => True, Shift => True);
      Check_Selection ("textarea-select-words-text", Item, "gu ea jekh");
      Press (Item, Events.Key_Down_Arrow, Times => 2, Shift => True);
      Check (Item, "textarea-select-keys");

      --  A character back goes to the start, and drops the selection.
      Press (Item, Events.Key_Left_Arrow);
      Goldens.Check_Text
        ("textarea-collapse-start", "FALSE",
         Text_Areas.Has_Selection (Item.Area)'Image);
      Goldens.Check_Text
        ("textarea-collapse-start-index", " 1",
         Text_Areas.Caret (Item.Area).Index'Image);
   end Selecting_Keys;

   procedure Select_All_And_Type is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Press (Item, Events.Key_A, Command => True);
      Type_In (Item, "Skua");
      Check_Text ("textarea-select-all-type-text", Item, "Skua");
   end Select_All_And_Type;

   procedure Copy_And_Paste is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Click (Item, 90.0, 35.0, Clicks => 2);  --  on "skua"
      Check_Selection ("textarea-double-click-text", Item, "skua");
      Press (Item, Events.Key_C, Command => True);
      Press (Item, Events.Key_Down_Arrow, Command => True);
      Type_In (Item, " ");
      Press (Item, Events.Key_V, Command => True);
      Check_Text
        ("textarea-paste-text", Item,
         "Great skua" & ASCII.LF & "Bonxie skua");

      --  Lines from elsewhere, with CR LF ends, become paragraphs.
      Item.Board.Set_Text ("Stercorarius" & ASCII.CR & ASCII.LF & "skua");
      Press (Item, Events.Key_Return);
      Press (Item, Events.Key_V, Command => True);
      Check_Text
        ("textarea-paste-lines-text", Item,
         "Great skua" & ASCII.LF & "Bonxie skua" & ASCII.LF
         & "Stercorarius" & ASCII.LF & "skua");
      Check (Item, "textarea-paste");
   end Copy_And_Paste;

   procedure Cut_And_Undo is
      Item : Fixture;
      Source : constant String :=
        "one two" & ASCII.LF & "three four" & ASCII.LF & "five";
   begin
      Open (Item, Source);
      Text_Areas.Select_Range (Item.Area, (1, 5), (3, 1));
      Check (Item, "textarea-selection-paragraphs");

      Press (Item, Events.Key_X, Command => True);
      Check_Text ("textarea-cut-text", Item, "one five");
      Goldens.Check_Text
        ("textarea-cut-board", "two" & ASCII.LF & "three four" & ASCII.LF,
         Item.Board.Text);

      --  Back, with what was cut selected; and again.
      Press (Item, Events.Key_Z, Command => True);
      Check_Text ("textarea-undo-cut-text", Item, Source);
      Check_Selection
        ("textarea-undo-cut-selection", Item,
         "two" & ASCII.LF & "three four" & ASCII.LF);
      Goldens.Check_Text
        ("textarea-undo-cut-state", " 0",
         Docs.State (Item.Doc)'Image);
      Press (Item, Events.Key_Z, Command => True, Shift => True);
      Check_Text ("textarea-redo-cut-text", Item, "one five");
   end Cut_And_Undo;

   procedure Undo_Typing is
      Item : Fixture;
   begin
      Open (Item, "Skuas");
      Press (Item, Events.Key_Right_Arrow, Command => True);

      --  Typing in a row is undone together, and so is deleting.
      for C of String'(" nest on moors") loop
         Type_In (Item, [C]);
      end loop;
      Press (Item, Events.Key_Backspace, Times => 5);
      Check_Text ("textarea-typed-text", Item, "Skuas nest on ");
      Press (Item, Events.Key_Z, Command => True);
      Check_Text ("textarea-undo-deleting-text", Item, "Skuas nest on moors");
      Press (Item, Events.Key_Z, Command => True);
      Check_Text ("textarea-undo-typing-text", Item, "Skuas");
      Goldens.Check_Text
        ("textarea-undo-typing-state", " 0",
         Docs.State (Item.Doc)'Image);

      --  Nothing more to undo; then all to redo, and a new edit ends
      --  that.
      Press (Item, Events.Key_Z, Command => True);
      Check_Text ("textarea-undo-nothing-text", Item, "Skuas");
      Press (Item, Events.Key_Z, Times => 2, Command => True, Shift => True);
      Check_Text ("textarea-redo-text", Item, "Skuas nest on ");
      Type_In (Item, "!");
      Press (Item, Events.Key_Z, Command => True, Shift => True);
      Check_Text ("textarea-redo-ended-text", Item, "Skuas nest on !");
   end Undo_Typing;

   procedure Words is
      Item : Fixture;
   begin
      Open (Item, "The great skua, or bonxie.");
      Press (Item, Events.Key_Right_Arrow, Times => 2, Option => True);
      Goldens.Check_Text
        ("textarea-word-right", " 10",
         Text_Areas.Caret (Item.Area).Index'Image);
      Press (Item, Events.Key_Backspace, Option => True);
      Check_Text ("textarea-word-delete-back", Item, "The  skua, or bonxie.");
      Press (Item, Events.Key_Delete, Option => True);
      Check_Text ("textarea-word-delete-forward", Item, "The , or bonxie.");
      Press (Item, Events.Key_Left_Arrow, Option => True);
      Goldens.Check_Text
        ("textarea-word-left", " 1",
         Text_Areas.Caret (Item.Area).Index'Image);

      --  Command: to the line's ends.
      Press (Item, Events.Key_Right_Arrow, Times => 4);
      Press (Item, Events.Key_Backspace, Command => True);
      Check_Text ("textarea-line-delete-back", Item, ", or bonxie.");
      Press (Item, Events.Key_Delete, Command => True);
      Check_Text ("textarea-line-delete-forward", Item, "");
   end Words;

   procedure Dragged is
      Item : Fixture;
   begin
      Open (Item, Sample, Focus => False);
      Send (Item,
            (Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
             Mouse_X => 60.0, Mouse_Y => 40.0, others => <>));
      Send (Item,
            (Kind => Events.Mouse_Move, Left_Held => True,
             Mouse_X => 150.0, Mouse_Y => 60.0, others => <>));
      Send (Item,
            (Kind => Events.Mouse_Move, Left_Held => True,
             Mouse_X => 250.0, Mouse_Y => 90.0, others => <>));
      Send (Item,
            (Kind => Events.Mouse_Up, Button => 1,
             Mouse_X => 250.0, Mouse_Y => 90.0, others => <>),
            Taken => False);
      Check (Item, "textarea-dragged");

      --  Let go, moving no longer selects.
      Send (Item,
            (Kind => Events.Mouse_Move, Mouse_X => 300.0, Mouse_Y => 150.0,
             others => <>),
            Taken => False);

      --  Shift and a click extend it; three clicks select a paragraph.
      Click (Item, 100.0, 140.0, Shift => True);
      Check (Item, "textarea-shift-clicked");
      Click (Item, 100.0, 40.0, Clicks => 3);
      Goldens.Check_Text
        ("textarea-triple-click", Typeset.Samples.Document (1),
         Text_Areas.Selected_Text (Item.Area));
   end Dragged;

   procedure Inactive_Selection is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Press (Item, Events.Key_A, Command => True);
      Press (Item, Events.Key_Escape);
      Check (Item, "textarea-inactive-selection");
   end Inactive_Selection;

   procedure Blinking is
      Item    : Fixture;
      Changed : Boolean;
   begin
      Open (Item, "Bonxie");
      Text_Areas.Tick (Item.Area, 400, Changed);
      Goldens.Check_Text ("textarea-blink-shown", "FALSE", Changed'Image);
      Goldens.Check_Text
        ("textarea-blink-wait", " 100",
         Text_Areas.Until_Blink (Item.Area)'Image);

      Text_Areas.Tick (Item.Area, 600, Changed);
      Goldens.Check_Text ("textarea-blink-hides", "TRUE", Changed'Image);
      Check (Item, "textarea-blink-off");

      --  Typing shows it again, for a period from then.
      Send (Item, (Events.Text_Event ("!") with delta Time => 700));
      Text_Areas.Tick (Item.Area, 1100, Changed);
      Goldens.Check_Text
        ("textarea-blink-typing", "TRUE",
         Text_Areas.Is_Caret_Shown (Item.Area)'Image);
      Text_Areas.Tick (Item.Area, 1250, Changed);
      Goldens.Check_Text
        ("textarea-blink-typing-hides", "FALSE",
         Text_Areas.Is_Caret_Shown (Item.Area)'Image);
   end Blinking;

   procedure Composing is
      Item : Fixture;
   begin
      Open (Item, "Skua ");
      Press (Item, Events.Key_Right_Arrow, Command => True);
      Send (Item, Events.Editing_Event (UTF_8 ("に"), 1));
      Send (Item, Events.Editing_Event (UTF_8 ("にほん"), 3));
      Send (Item, Events.Editing_Event (UTF_8 ("日本"), 1));
      Check (Item, "textarea-composing");

      --  Keys go to the input method meanwhile.
      Send (Item,
            (Kind => Events.Key_Down, Key => Events.Key_Backspace,
             others => <>),
            Taken => False);
      Send (Item, Events.Text_Event (UTF_8 ("日本")));
      Check_Text ("textarea-composed-text", Item, UTF_8 ("Skua 日本"));
      Goldens.Check_Text
        ("textarea-composed-ends", "FALSE",
         Text_Areas.Is_Composing (Item.Area)'Image);

      --  Undone as typing; and given up, it leaves nothing.
      Press (Item, Events.Key_Z, Command => True);
      Check_Text ("textarea-composed-undo", Item, "Skua ");
      Send (Item, Events.Editing_Event ("e", 1));
      Send (Item, Events.Editing_Event ("", 0));
      Check_Text ("textarea-composing-cancelled", Item, "Skua ");
   end Composing;

   procedure Two_Views is
      Wide_Points : constant := 560;
      Target  : Renderers.Renderer;
      Doc     : aliased Docs.Document;
      Narrow  : Text_Areas.Text_Area;  --  after Target and Doc
      Broad   : Text_Areas.Text_Area;
      Board   : UI.Clipboards.Memory_Clipboard;
      Drawn   : Images.Image;
      Handled : Boolean;
   begin
      --  One document, two views of different widths: each has its own
      --  layout, caret and selection, and follows the other's edits.
      Renderers.Create_Offscreen
        (Target,
         Positive (Float (Wide_Points) * Density),
         Positive (Float (Height) * Density));
      Docs.Load
        (Doc,
         "Bonxies nest on moorland in Shetland and Orkney." & ASCII.LF
         & "They spend the winter at sea." & ASCII.LF & "Skua");
      Text_Areas.Configure
        (Narrow, "Georgia", Size => 18.0, Measure => 640.0, Spacing => 8.0);
      Text_Areas.Configure
        (Broad, "Georgia", Size => 18.0, Measure => 640.0, Spacing => 8.0);
      Text_Areas.Place
        (Narrow, Float (Margin) * Density, Float (Margin) * Density,
         180.0 * Density, Float (Height - 2 * Margin) * Density, Density);
      Text_Areas.Place
        (Broad, Float (2 * Margin + 180) * Density,
         Float (Margin) * Density,
         Float (Wide_Points - 3 * Margin - 180) * Density,
         Float (Height - 2 * Margin) * Density, Density);
      Text_Areas.Attach (Narrow, Doc'Unchecked_Access);
      Text_Areas.Attach (Broad, Doc'Unchecked_Access);

      Text_Areas.Select_Range (Broad, (3, 1), (3, 5));
      Text_Areas.Set_Focus (Narrow, True);
      Text_Areas.Select_Range (Narrow, (1, 8), (1, 8));
      Text_Areas.Handle
        (Narrow, Events.Text_Event (" (great skuas)"), Board, Handled);
      Text_Areas.Handle
        (Narrow,
         (Kind => Events.Key_Down, Key => Events.Key_Return, others => <>),
         Board, Handled);

      Goldens.Check_Text
        ("textarea-two-views-follows", "Skua",
         Text_Areas.Selected_Text (Broad));
      Goldens.Check_Text
        ("textarea-two-views-moved", " 4",
         Text_Areas.Caret (Broad).Paragraph'Image);

      Renderers.Clear (Target, Colors.Background);
      Text_Areas.Draw (Narrow, Target, Colors);
      Text_Areas.Draw (Broad, Target, Colors);
      Images.Read (Drawn, Target);
      Goldens.Check ("textarea-two-views", Drawn);

      --  One history: undone from the other view.
      Text_Areas.Undo (Broad);
      Text_Areas.Undo (Broad);
      Goldens.Check_Text
        ("textarea-two-views-undone",
         "Bonxies nest on moorland in Shetland and Orkney." & ASCII.LF
         & "They spend the winter at sea." & ASCII.LF & "Skua",
         Docs.Whole (Doc));
   end Two_Views;

   procedure Long_Paragraph is
      Item     : Fixture;
      Sentence : constant String := "The bonxie nests on the moor. ";
      Long     : String (1 .. 3_000 * Sentence'Length);
   begin
      --  Longer than is broken into lines all at once: only as far as
      --  is shown, until more is wanted.
      for K in 0 .. 2_999 loop
         Long (K * Sentence'Length + 1 .. (K + 1) * Sentence'Length) :=
           Sentence;
      end loop;
      Open (Item, Long & ASCII.LF & "After it.");
      Text_Areas.Select_Range
        (Item.Area, (1, 45_001), (1, 45_001));
      Type_In (Item, "SKUA ");
      Check (Item, "textarea-long-paragraph");
      Goldens.Check_Text
        ("textarea-long-paragraph-text", "moor. SKUA The",
         Docs.Slice (Item.Doc, 1, 44_995, 45_009));

      Press (Item, Events.Key_Down_Arrow, Command => True);
      Check (Item, "textarea-long-paragraph-end");
   end Long_Paragraph;

   --  Where the caret is drawn is kept while nothing it depends on
   --  changes, and is as if worked out afresh after anything does.

   procedure Caret_Box_Kept is
      A, B : Fixture;

      procedure Box (Item : in out Fixture; X, Y : out Float) is
         Wide, High : Float;
      begin
         Text_Areas.Caret_Box (Item.Area, X, Y, Wide, High);
      end Box;

      function Measures (Item : Fixture) return String is
        (Natural'Image (Text_Areas.Caret_Measures (Item.Area)));

      procedure Narrow (Item : in out Fixture) is
      begin
         Text_Areas.Place
           (Item.Area,
            Left    => Float (Margin) * Density,
            Top     => Float (Margin) * Density,
            Width   => Float (Width - 2 * Margin - 150) * Density,
            Height  => Float (Height - 2 * Margin) * Density,
            Density => Density);
      end Narrow;

      procedure To_End (Item : in out Fixture) is
      begin
         Press (Item, Events.Key_Down_Arrow, Command => True);
      end To_End;

      procedure Same
        (Name : String; One, Other : in out Fixture) is
         X1, Y1, X2, Y2 : Float;
      begin
         Box (One, X1, Y1);
         Box (Other, X2, Y2);
         Goldens.Check_Text (Name, "TRUE",
                             Boolean'Image (X1 = X2 and then Y1 = Y2));
      end Same;

      Phrase  : constant String := "Great skua, bonxie, arctic skua. ";
      Long    : constant String := Phrase & Phrase & Phrase & Phrase & Phrase;
      X, Y, X_Then, Y_Then : Float;
      Blinked : Boolean;
   begin
      Open (A, Long);
      To_End (A);
      Box (A, X_Then, Y_Then);
      Goldens.Check_Text ("textarea-caret-box-first", " 1", Measures (A));

      --  Again, and with the time passing, it is not worked out again.
      Box (A, X, Y);
      Text_Areas.Tick (A.Area, 600, Blinked);
      Box (A, X, Y);
      Goldens.Check_Text ("textarea-caret-box-kept", " 1", Measures (A));
      Goldens.Check_Text
        ("textarea-caret-box-same", "TRUE",
         Boolean'Image (X = X_Then and then Y = Y_Then));

      --  Typing moves it, and it is worked out.
      Type_In (A, "!");
      Open (B, Long & "!");
      To_End (B);
      Same ("textarea-caret-box-typed", A, B);
      Goldens.Check_Text
        ("textarea-caret-box-typed-count", " 2", Measures (A));

      --  The lines wrapping differently moves it.
      Narrow (A);
      Narrow (B);
      Same ("textarea-caret-box-narrowed", A, B);
      Goldens.Check_Text
        ("textarea-caret-box-narrowed-count", " 3", Measures (A));

      --  Moving the caret does.
      Press (A, Events.Key_Left_Arrow, Times => 5);
      Press (B, Events.Key_Left_Arrow, Times => 5);
      Same ("textarea-caret-box-moved", A, B);

      --  And so does an edit made through another view of the document,
      --  which the text area has not seen until it is asked.
      Docs.Replace (A.Doc, (1, 1), (1, 1), "Skua. ");
      Docs.Replace (B.Doc, (1, 1), (1, 1), "Skua. ");
      Same ("textarea-caret-box-edited", A, B);
      Goldens.Check_Text
        ("textarea-caret-box-edited-count", " 5", Measures (A));
      Box (A, X, Y);
      Goldens.Check_Text
        ("textarea-caret-box-edited-kept", " 5", Measures (A));

      --  Even when the caret stays at the same place in the paragraph and
      --  the text before it is as long, but wider.
      Docs.Replace (A.Doc, (1, 1), (1, 7), "WWWWWW");
      Docs.Replace (B.Doc, (1, 1), (1, 7), "WWWWWW");
      Same ("textarea-caret-box-widened", A, B);
      Goldens.Check_Text
        ("textarea-caret-box-widened-count", " 6", Measures (A));
   end Caret_Box_Kept;

end Text_Area_Tests;
