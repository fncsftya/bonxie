with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with SDL3;
with SDL3.Events;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with Texts.Documents;
with Typeset.Samples;
with UI.Clipboards;
with UI.Text_Areas;
with UI.Themes;

--  Measures editing in a text area, as the app does it, on documents of
--  several sizes: text_area_bench [paragraphs ...]. Each edit is timed by
--  itself (the model) and with the frame drawn after it, into a hidden
--  window on the GPU.
procedure Text_Area_Bench is
   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Text_Areas renames UI.Text_Areas;
   package Docs renames Texts.Documents;

   use Ada.Real_Time;
   use Ada.Text_IO;

   Colors : constant UI.Themes.Theme := UI.Themes.Light;

   procedure Report (What : String; Millis : Float) is
      Shown : String (1 .. 10);
   begin
      Ada.Float_Text_IO.Put (Shown, Millis, Aft => 3, Exp => 0);
      Put_Line ("  " & What & (1 .. Integer'Max (1, 44 - What'Length) => ' ')
                & Shown & " ms");
   end Report;

   function Key
     (Code : Events.Key_Code; Command, Shift : Boolean := False)
      return Events.Event is
     ((Kind => Events.Key_Down, Key => Code, Command => Command,
       Shift => Shift, others => <>));

   Win    : SDL3.Windows.Window;
   Target : Renderers.Renderer;  --  after Win: it is destroyed first

   procedure Measure (Text : String) is
      Paragraphs : Positive := 1;
      Doc   : aliased Docs.Document;
      Area  : Text_Areas.Text_Area;  --  after Target and Doc
      Board : UI.Clipboards.Memory_Clipboard;
      Width, Height : Natural;
      Density : constant Float := SDL3.Windows.Pixel_Density (Win);

      Longest, Longest_Length : Natural := 0;
      Longest_Middle : Positive := 1;
      --  The longest paragraph, its length in bytes, and a character
      --  boundary half way along it

      procedure Send (Event : Events.Event) is
         Handled : Boolean;
      begin
         Text_Areas.Handle (Area, Event, Board, Handled);
      end Send;

      procedure Draw is
      begin
         Renderers.Clear (Target, Colors.Background);
         Text_Areas.Draw (Area, Target, Colors);
      end Draw;

      function Each
        (Times : Positive; Action : not null access procedure;
         Drawn : Boolean := False) return Float
      is
         Spent : Duration := 0.0;
      begin
         --  Present waits for the display, even without vsync: it is not
         --  timed.
         for K in 1 .. Times loop
            declare
               Started : constant Time := Clock;
            begin
               Action.all;
               if Drawn then
                  Draw;
               end if;
               Spent := Spent + To_Duration (Clock - Started);
            end;
            if Drawn then
               Renderers.Present (Target);
            end if;
         end loop;
         return Float (Spent) * 1000.0 / Float (Times);
      end Each;

      procedure Both (What : String; Times : Positive;
                      Action : not null access procedure;
                      Set_Up : access procedure := null) is
         Model : Float;
      begin
         if Set_Up /= null then
            Set_Up.all;
         end if;
         Model := Each (Times, Action);
         if Set_Up /= null then
            Set_Up.all;
         end if;
         Report (What & ", model", Model);
         Report (What & ", drawn", Each (Times, Action, Drawn => True));
      end Both;

      procedure At_Middle is
         Count : Positive;
      begin
         --  Edits may have joined or split paragraphs.
         Send (Key (Events.Key_Down_Arrow, Command => True));
         Count := Text_Areas.Caret (Area).Paragraph;
         Text_Areas.Select_Range
           (Area, ((Count + 1) / 2, 1), ((Count + 1) / 2, 1));
      end At_Middle;

      procedure In_Longest is
      begin
         if Text_Areas.Is_Position (Area, (Longest, Longest_Middle)) then
            Text_Areas.Select_Range
              (Area, (Longest, Longest_Middle), (Longest, Longest_Middle));
         end if;
      end In_Longest;

      procedure Type_Character is
      begin
         Send (Events.Text_Event ("x"));
      end Type_Character;

      procedure Backspace is
      begin
         Send (Key (Events.Key_Backspace));
      end Backspace;

      procedure Return_Key is
      begin
         Send (Key (Events.Key_Return));
      end Return_Key;

      procedure Down is
      begin
         Send (Key (Events.Key_Down_Arrow));
      end Down;

      procedure Right is
      begin
         Send (Key (Events.Key_Right_Arrow));
      end Right;

      procedure Shift_Down is
      begin
         Send (Key (Events.Key_Down_Arrow, Shift => True));
      end Shift_Down;

      procedure Nothing is null;

      procedure Load is
      begin
         Docs.Load (Doc, Text);
         Text_Areas.Attach (Area, Doc'Unchecked_Access);
      end Load;

      procedure Select_All_Copy is
      begin
         Send (Key (Events.Key_A, Command => True));
         Send (Key (Events.Key_C, Command => True));
      end Select_All_Copy;

      procedure Whole_Text is
         Got : constant String := Docs.Whole (Doc);
      begin
         pragma Assert (Got'Length > 0);
      end Whole_Text;

      procedure To_End is
      begin
         Send (Key (Events.Key_Down_Arrow, Command => True));
         Send (Key (Events.Key_Up_Arrow, Command => True));
      end To_End;

      procedure Delete_All is
      begin
         Send (Key (Events.Key_A, Command => True));
         Send (Key (Events.Key_Backspace));
      end Delete_All;

      procedure Paste is
      begin
         Send (Key (Events.Key_V, Command => True));
      end Paste;

      procedure Undo is
      begin
         Send (Key (Events.Key_Z, Command => True));
      end Undo;

      Started : Time;
   begin
      --  The longest paragraph
      declare
         Para  : Positive := 1;
         Since : Natural := 0;
         Start, Longest_Start : Positive := Text'First;
      begin
         for I in Text'Range loop
            if Text (I) = ASCII.LF then
               if Since > Longest_Length then
                  Longest := Para;
                  Longest_Length := Since;
                  Longest_Start := Start;
               end if;
               Para := Para + 1;
               Since := 0;
               Start := I + 1;
            else
               Since := Since + 1;
            end if;
         end loop;
         Paragraphs := Para;
         Longest_Middle := Natural'Max (1, Longest_Length / 2);
         while Character'Pos (Text (Longest_Start + Longest_Middle - 1))
               in 16#80# .. 16#BF#
         loop
            Longest_Middle := Longest_Middle - 1;
         end loop;
      end;

      Put_Line (Paragraphs'Image & " paragraphs,"
                & Natural'Image (Text'Length / 1024) & " KB; the longest"
                & Natural'Image (Longest_Length / 1024) & " KB");

      Renderers.Output_Size (Target, Width, Height);
      Started := Clock;
      Docs.Load (Doc, Text);
      Text_Areas.Configure (Area, "Georgia", 18.0, 640.0, 8.0);
      Text_Areas.Place
        (Area, 32.0, 32.0, Float (Width) - 64.0, Float (Height) - 128.0,
         Density);
      Text_Areas.Attach (Area, Doc'Unchecked_Access);
      Text_Areas.Set_Focus (Area, True);
      Report ("configure and load", Float
                (To_Duration (Clock - Started)) * 1000.0);
      Report ("first frame", Each (1, Nothing'Access, Drawn => True));
      Report ("frame, nothing changed", Each (50, Nothing'Access, True));

      Both ("typing, mid-document, each", 100, Type_Character'Access,
            At_Middle'Access);
      Both ("backspace, mid-document, each", 100, Backspace'Access,
            At_Middle'Access);
      Both ("typing, in the longest paragraph, each", 100,
            Type_Character'Access, In_Longest'Access);
      Both ("arrow right, in the longest paragraph, each", 100,
            Right'Access, In_Longest'Access);
      Both ("return (new paragraph), mid-document, each", 50,
            Return_Key'Access, At_Middle'Access);
      Both ("arrow down, mid-document, each", 100, Down'Access,
            At_Middle'Access);
      Both ("shift-arrow down, growing a selection, each", 30,
            Shift_Down'Access, At_Middle'Access);
      Report ("command-down and -up (to the ends and back)",
              Each (5, To_End'Access, Drawn => True));
      Report ("select all and copy", Each (1, Select_All_Copy'Access));
      Report ("all the text, as to save it", Each (5, Whole_Text'Access));
      Report ("select all and delete", Each (1, Delete_All'Access));
      Report ("paste it all back", Each (1, Paste'Access));
      Report ("undo that paste", Each (1, Undo'Access));
      Report ("load again", Each (1, Load'Access));
   end Measure;

   function Short_Lines (Count : Positive) return String is
      Line : constant String := "A short paragraph, as in a list or a script.";
      Result : String (1 .. Count * (Line'Length + 1));
   begin
      for K in 0 .. Count - 1 loop
         Result (K * (Line'Length + 1) + 1 .. (K + 1) * (Line'Length + 1)) :=
           Line & ASCII.LF;
      end loop;
      return Result (1 .. Result'Last - 1);
   end Short_Lines;
   --  Count paragraphs of a line each.

   function One_Long (Bytes : Positive) return String is
      Sentence : constant String := "The bonxie nests on the moor. ";
   begin
      return Result : String (1 .. Bytes) do
         for K in Result'Range loop
            Result (K) := Sentence ((K - 1) mod Sentence'Length + 1);
         end loop;
      end return;
   end One_Long;
   --  A paragraph of Bytes, of sentences.

   Sizes : constant array (1 .. 3) of Positive := [20, 1_000, 10_000];
begin
   SDL3.Initialize;
   SDL3.Windows.Create
     (Win, "bench", 1000, 800, High_Density => True, Hidden => True);
   Renderers.Create (Target, Win, VSync => False);
   if Ada.Command_Line.Argument_Count > 0
     and then Ada.Command_Line.Argument (1) = "profile-load"
   then
      --  Loading many short paragraphs, for a profiler to watch.
      declare
         Doc_Text : constant String := Short_Lines (100_000);
         Doc   : aliased Docs.Document;
         Area  : Text_Areas.Text_Area;
      begin
         Text_Areas.Configure (Area, "Georgia", 18.0, 640.0, 8.0);
         Text_Areas.Place (Area, 32.0, 32.0, 1900.0, 1400.0, 2.0);
         for K in 1 .. 1_000 loop
            Docs.Load (Doc, Doc_Text);
            Text_Areas.Attach (Area, Doc'Unchecked_Access);
         end loop;
      end;
   elsif Ada.Command_Line.Argument_Count > 0
     and then Ada.Command_Line.Argument (1) = "profile"
   then
      --  Typing in a long paragraph, for a profiler to watch.
      declare
         Doc_Text : constant String := One_Long (1_000_000);
         Doc   : aliased Docs.Document;
         Area  : Text_Areas.Text_Area;
         Board : UI.Clipboards.Memory_Clipboard;
         Handled : Boolean;
      begin
         Docs.Load (Doc, Doc_Text);
         Text_Areas.Configure (Area, "Georgia", 18.0, 640.0, 8.0);
         Text_Areas.Place (Area, 32.0, 32.0, 1900.0, 1400.0, 2.0);
         Text_Areas.Attach (Area, Doc'Unchecked_Access);
         Text_Areas.Set_Focus (Area, True);
         Text_Areas.Select_Range (Area, (1, 500_000), (1, 500_000));
         for K in 1 .. 2_000 loop
            Text_Areas.Handle
              (Area, Events.Text_Event ("x"), Board, Handled);
            Renderers.Clear (Target, Colors.Background);
            Text_Areas.Draw (Area, Target, Colors);
         end loop;
      end;
   elsif Ada.Command_Line.Argument_Count > 0 then
      for K in 1 .. Ada.Command_Line.Argument_Count loop
         Measure
           (Typeset.Samples.Document
              (Positive'Value (Ada.Command_Line.Argument (K))));
      end loop;
   else
      for Size of Sizes loop
         Measure (Typeset.Samples.Document (Size));
      end loop;
      Put_Line ("short paragraphs:");
      Measure (Short_Lines (100_000));
      Put_Line ("one long paragraph, then a short one:");
      Measure (One_Long (1_000_000) & ASCII.LF & "End.");
   end if;
   SDL3.Shutdown;
end Text_Area_Bench;
