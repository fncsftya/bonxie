with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;
with SDL3.Events;
with Goldens;
with Typeset.Samples;
with Viewer;

--  Draws the viewer in various setups and compares what it draws with
--  golden images: golden [part of a test's name]. See Goldens.
procedure Golden is

   package Events renames SDL3.Events;
   package Images renames Goldens.Images;

   Filter : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1) else "");

   Sample : constant String := Typeset.Samples.Document (200);

   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

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

   function Wheel (Notches : Float) return Events.Event is
     ((Kind => Events.Mouse_Wheel, Wheel_Y => Notches, others => <>));

   procedure Press
     (Item  : in out Viewer.Session;
      Code  : Events.Key_Code;
      Times : Positive := 1;
      Command : Boolean := False) is
   begin
      for K in 1 .. Times loop
         Viewer.Handle (Item, Key (Code, Command));
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

   --  Shorthands

   Default_Width  : constant := 720;
   Default_Height : constant := 480;
   --  In points: the page, 640 wide, fits with a margin.

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

   Ada.Text_IO.Put_Line
     (Ran'Image & " tests:" & Natural'Image (Goldens.Passed)
      & " checks passed," & Natural'Image (Goldens.Failed) & " failed");
   if Ran = 0 or else Goldens.Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Golden;
