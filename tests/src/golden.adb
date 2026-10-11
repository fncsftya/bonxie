with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;
with SDL3.Events;
with Files;
with Goldens;
with Text_Area_Tests;
with Typeset.Samples;
with Viewer;

--  Draws the viewer, and a text area by itself, in various setups and
--  compares what they draw with golden images: golden [part of a test's
--  name]. See Goldens.
procedure Golden is

   package Events renames SDL3.Events;
   package Images renames Goldens.Images;

   Filter : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1) else "");

   Sample : constant String := Typeset.Samples.Document (200);

   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   Em_Dash : constant String :=
     Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
       ([Wide_Wide_Character'Val (16#2014#)]);

   Scripts : constant String :=
     Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
       ("Accents: café, naïve, Ångström, smørrebrød." & LF
        & "Emoji keep their colours: 🐦 🌿 🎙️ 👍🏽" & LF
        & "Other scripts: Привет, こんにちは, 日本語のテキスト, مرحبا." & LF
        & "Typography: “quoted”, ‘single’, em—dash, en–dash, ½, …" & LF
        & LF
        & "After an empty paragraph, a long one that wraps across several "
        & "lines of the page, to see the lines break between words and the "
        & "paragraph's spacing after it, before the next. Bonxies are great "
        & "skuas, which nest on moorland in Shetland and Orkney and spend "
        & "the winter at sea.");
   --  In UTF-8, as documents are.

   --  Events

   function Key
     (Code : Events.Key_Code; Command : Boolean := False) return Events.Event
   is ((Kind => Events.Key_Down, Key => Code, Command => Command,
        others => <>));

   --  Shorthands

   Default_Width  : constant := 720;
   Default_Height : constant := 480;
   --  In points: the page, 640 wide, fits with a margin.

   function Wheel (Notches : Float) return Events.Event is
     ((Kind => Events.Mouse_Wheel, Wheel_Y => Notches,
       Mouse_X => Float (Default_Width / 2),
       Mouse_Y => Float (Default_Height / 2), others => <>));
   --  Over the text.

   function Click (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));
   --  At X, Y points.

   procedure Press
     (Item  : in out Viewer.Session;
      Code  : Events.Key_Code;
      Times : Positive := 1;
      Command : Boolean := False;
      Shift : Boolean := False) is
   begin
      for K in 1 .. Times loop
         Viewer.Handle (Item, (Key (Code, Command) with delta Shift => Shift));
      end loop;
   end Press;

   procedure Zoom_In (Item : in out Viewer.Session; Times : Positive) is
   begin
      Press (Item, Events.Key_Equals, Times, Command => True);
   end Zoom_In;

   procedure Zoom_Out (Item : in out Viewer.Session; Times : Positive) is
   begin
      Press (Item, Events.Key_Minus, Times, Command => True);
   end Zoom_Out;

   procedure Show
     (Name    : String;
      Source  : String;
      Width   : Positive := Default_Width;
      Height  : Positive := Default_Height;
      Density : Float := 2.0)
   is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Source, Width, Height, Density);
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Show;

   --  The tests

   procedure Empty is
   begin
      Show ("empty", "");
   end Empty;

   procedure Top_Of_Sample is
   begin
      Show ("sample", Sample);
   end Top_Of_Sample;

   procedure Low_Density is
   begin
      Show ("sample-1x", Sample, Density => 1.0);
   end Low_Density;

   procedure Narrow_Window is
   begin
      --  Narrower than the page, which so starts at the margin.
      Show ("narrow", Sample, Width => 300);
   end Narrow_Window;

   procedure Wide_Window is
   begin
      --  The page in the middle.
      Show ("wide", Sample, Width => 1000, Height => 300);
   end Wide_Window;

   procedure Other_Scripts is
   begin
      Show ("scripts", Scripts);
   end Other_Scripts;

   procedure Scrolled is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Press (Session, Events.Key_Page_Down, Times => 3);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("page-down", Drawn);

      Press (Session, Events.Key_Down_Arrow, Times => 2);
      Viewer.Handle (Session, Wheel (-2.0));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("arrows-and-wheel", Drawn);

      Press (Session, Events.Key_End);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("end", Drawn);
   end Scrolled;

   procedure Back_Home is
      Fresh, Session : Viewer.Session;
      Expected, Drawn : Images.Image;
   begin
      --  Scrolling to the end lays out all between, which changes the
      --  page's height, but not the top of it.
      Viewer.Open (Fresh, Sample, Default_Width, Default_Height);
      Viewer.Render (Fresh, Expected);

      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Press (Session, Events.Key_End);
      Viewer.Render (Session, Drawn);
      Press (Session, Events.Key_Home);
      Viewer.Render (Session, Drawn);
      Goldens.Check_Same ("home-after-end", Expected, Drawn);
   end Back_Home;

   procedure Zoomed is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Zoom_In (Session, 4);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("zooming-in", Drawn);
      --  Glyphs made at a nearby size, scaled.

      Viewer.Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("zoomed-in", Drawn);

      Zoom_Out (Session, 10);
      Viewer.Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("zoomed-out", Drawn);
   end Zoomed;

   procedure Resized is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.Render (Session, Drawn);
      Viewer.Resize (Session, 400, 600);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("resized", Drawn);
   end Resized;

   procedure Atlas_Order (Settled : Boolean) is
      Fresh, Session : Viewer.Session;
      Expected, Drawn : Images.Image;
   begin
      --  The same glyphs, placed in the atlas in another order after
      --  others, must look the same: smoothing them, when scaled, must
      --  not take in their neighbours.
      Viewer.Open (Fresh, Sample, Default_Width, Default_Height);
      Zoom_In (Fresh, 3);
      if Settled then
         Viewer.Settle (Fresh);
      end if;
      Viewer.Render (Fresh, Expected);

      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Zoom_In (Session, 3);
      if Settled then
         Viewer.Settle (Session);
      end if;
      Press (Session, Events.Key_End);
      Viewer.Render (Session, Drawn);
      Press (Session, Events.Key_Page_Up, Times => 5);
      Viewer.Render (Session, Drawn);
      Press (Session, Events.Key_Home);
      Viewer.Render (Session, Drawn);
      Goldens.Check_Same
        ((if Settled then "atlas-order-settled" else "atlas-order-zooming"),
         Expected, Drawn);
   end Atlas_Order;

   procedure Atlas_Order_Settled is
   begin
      Atlas_Order (Settled => True);
   end Atlas_Order_Settled;

   procedure Atlas_Order_Zooming is
   begin
      Atlas_Order (Settled => False);
   end Atlas_Order_Zooming;

   procedure Edited is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      --  The text area has the focus to start with.
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Press (Session, Events.Key_Delete, Times => 3);
      Viewer.Handle (Session, Events.Text_Event ("Skua"));
      Press (Session, Events.Key_Return);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("edited", Drawn);
      Goldens.Check_Text
        ("edited-text",
         "Skua" & ASCII.LF & Sample (Sample'First + 3 .. Sample'Last),
         Viewer.Text (Session));
   end Edited;

   procedure Unfocused is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      --  A click on the toolbar takes the focus from the text area, which
      --  then no longer takes typing.
      Viewer.Open (Session, "Bonxie", Default_Width, Default_Height);
      Viewer.Handle (Session, Click (100.0, Float (Default_Height - 10)));
      Viewer.Handle (Session, Events.Text_Event ("Skua"));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("unfocused", Drawn);
      Goldens.Check_Text ("unfocused-text", "Bonxie", Viewer.Text (Session));

      --  A click in it gives it back.
      Viewer.Handle (Session, Click (200.0, 100.0));
      Viewer.Handle (Session, Events.Text_Event ("Skua"));
      Goldens.Check_Text
        ("refocused-text", "BonxieSkua", Viewer.Text (Session));
   end Unfocused;

   procedure Saved is
      File    : constant String := Goldens.Scratch ("saved.txt");
      Session : Viewer.Session;
   begin
      Viewer.Open
        (Session, "Bonxie", Default_Width, Default_Height,
         File_Name => File);
      Goldens.Check_Text ("saved-title-loaded", "saved.txt",
                          Viewer.Title (Session));
      Press (Session, Events.Key_Down_Arrow, Command => True);
      Viewer.Handle (Session, Events.Text_Event (" skua"));
      Goldens.Check_Text (Name => "saved-title-edited",
                          Expected => "saved.txt " & Em_Dash & " Edited",
                          Actual => Viewer.Title (Session));

      Press (Session, Events.Key_S, Command => True);
      Goldens.Check_Text ("saved-title-saved", "saved.txt",
                          Viewer.Title (Session));
      Goldens.Check_Text ("saved-file", "Bonxie skua", Files.Read (File));

      --  Undone, it is not as saved; redone, it is again.
      Press (Session, Events.Key_Z, Command => True);
      Goldens.Check_Text ("saved-title-undone",
                          "saved.txt " & Em_Dash & " Edited",
                          Viewer.Title (Session));
      Press (Session, Events.Key_Z, Command => True, Shift => True);
      Goldens.Check_Text ("saved-title-redone", "saved.txt",
                          Viewer.Title (Session));
   end Saved;

   procedure Clipboard is
      Session : Viewer.Session;
   begin
      --  Its own clipboard, offscreen.
      Viewer.Open (Session, "Great skua", Default_Width, Default_Height);
      Press (Session, Events.Key_A, Command => True);
      Press (Session, Events.Key_C, Command => True);
      Press (Session, Events.Key_Down_Arrow, Command => True);
      Press (Session, Events.Key_V, Command => True);
      Goldens.Check_Text
        ("clipboard-text", "Great skuaGreat skua", Viewer.Text (Session));
   end Clipboard;

   type Test_Procedure is access procedure;

   Ran : Natural := 0;

   procedure Run (Name : String; Test : not null Test_Procedure) is
   begin
      if Filter = "" or else Ada.Strings.Fixed.Index (Name, Filter) > 0 then
         Test.all;
         Ran := Ran + 1;
      end if;
   end Run;
begin
   Run ("empty", Empty'Access);
   Run ("sample", Top_Of_Sample'Access);
   Run ("sample-1x", Low_Density'Access);
   Run ("narrow", Narrow_Window'Access);
   Run ("wide", Wide_Window'Access);
   Run ("scripts", Other_Scripts'Access);
   Run ("scrolled", Scrolled'Access);
   Run ("home-after-end", Back_Home'Access);
   Run ("zoomed", Zoomed'Access);
   Run ("resized", Resized'Access);
   Run ("atlas-order-settled", Atlas_Order_Settled'Access);
   Run ("atlas-order-zooming", Atlas_Order_Zooming'Access);
   Run ("edited", Edited'Access);
   Run ("unfocused", Unfocused'Access);
   Run ("saved", Saved'Access);
   Run ("clipboard", Clipboard'Access);

   Run ("textarea-empty", Text_Area_Tests.Empty'Access);
   Run ("textarea-focused", Text_Area_Tests.Focused'Access);
   Run ("textarea-typing", Text_Area_Tests.Typing'Access);
   Run ("textarea-joining", Text_Area_Tests.Joining'Access);
   Run ("textarea-clusters", Text_Area_Tests.Clusters'Access);
   Run ("textarea-up-down", Text_Area_Tests.Up_And_Down'Access);
   Run ("textarea-end", Text_Area_Tests.Text_End'Access);
   Run ("textarea-scrolled", Text_Area_Tests.Scrolled'Access);
   Run ("textarea-clicked", Text_Area_Tests.Clicked'Access);
   Run ("textarea-escape", Text_Area_Tests.Escape'Access);
   Run ("textarea-zoomed", Text_Area_Tests.Zoomed'Access);
   Run ("textarea-select-keys", Text_Area_Tests.Selecting_Keys'Access);
   Run ("textarea-select-all", Text_Area_Tests.Select_All_And_Type'Access);
   Run ("textarea-paste", Text_Area_Tests.Copy_And_Paste'Access);
   Run ("textarea-cut-undo", Text_Area_Tests.Cut_And_Undo'Access);
   Run ("textarea-undo-typing", Text_Area_Tests.Undo_Typing'Access);
   Run ("textarea-words", Text_Area_Tests.Words'Access);
   Run ("textarea-dragged", Text_Area_Tests.Dragged'Access);
   Run ("textarea-inactive-selection",
        Text_Area_Tests.Inactive_Selection'Access);
   Run ("textarea-blink", Text_Area_Tests.Blinking'Access);
   Run ("textarea-composing", Text_Area_Tests.Composing'Access);

   Ada.Text_IO.Put_Line
     (Ran'Image & " tests:" & Natural'Image (Goldens.Passed)
      & " checks passed," & Natural'Image (Goldens.Failed) & " failed");
   if Ran = 0 or else Goldens.Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Golden;
