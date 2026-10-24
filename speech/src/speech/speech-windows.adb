package body Speech.Windows
  with SPARK_Mode
is

   pragma Warnings
     (Off, "attribute ""Valid"" is assumed to return True",
      Reason => "GNATprove cannot see a NaN; windows_test (run) does");

   function Clean (Audio : Samples; Index : Integer) return Float is
     (if not Audio (Index)'Valid then 0.0
      elsif Usable (Audio (Index)) then Audio (Index)
      elsif Audio (Index) > 1.0 then 1.0
      else -1.0);

   procedure Clear (Of_Window : in out Window) is
   begin
      Of_Window.Start := 0;
      Of_Window.Held := 0;
      Of_Window.Last := 0;
   end Clear;

   procedure Append
     (Of_Window : in out Window;
      Audio     : Samples;
      Taken     : out Natural)
   is
      Before : constant Natural := Of_Window.Held;
   begin
      Taken := Natural'Min (Audio'Length, Capacity - Before);
      for K in 1 .. Taken loop
         pragma Loop_Invariant (Taken <= Audio'Length);
         pragma Loop_Invariant
           (for all J in 1 .. Before => Of_Window.Data (J) = Of_Window.Data'Loop_Entry (J));
         pragma Loop_Invariant
           (for all I in 1 .. K - 1 =>
              Of_Window.Data (Before + I) = Clean (Audio, Audio'First + I - 1));
         Of_Window.Data (Before + K) := Clean (Audio, Audio'First + K - 1);
      end loop;
      Of_Window.Held := Before + Taken;
   end Append;

   function Due (Of_Window : Window; Hop : Positive) return Boolean is
     (Next (Of_Window) - Of_Window.Last >= Sample_Index (Hop));

   function Full (Of_Window : Window; Room : Positive) return Boolean is
     (Capacity - Of_Window.Held < Room);

   procedure Mark_Decoded (Of_Window : in out Window) is
   begin
      Of_Window.Last := Next (Of_Window);
   end Mark_Decoded;

   procedure Drop_Before (Of_Window : in out Window; Place : Sample_Index) is
      Shift : constant Natural := Natural (Place - Of_Window.Start);
      Kept  : constant Natural := Of_Window.Held - Shift;
   begin
      for J in 1 .. Kept loop
         Of_Window.Data (J) := Of_Window.Data (J + Shift);
         pragma Loop_Invariant
           (for all I in 1 .. J => Of_Window.Data (I) = Of_Window.Data'Loop_Entry (I + Shift));
      end loop;
      Of_Window.Start := Place;
      Of_Window.Held := Kept;
      if Of_Window.Last < Place then
         Of_Window.Last := Place;
      end if;
   end Drop_Before;

   procedure Make_Room (Of_Window : in out Window; Room : Positive) is
   begin
      if Full (Of_Window, Room) then
         Drop_Before (Of_Window, Next (Of_Window));
      end if;
   end Make_Room;

   procedure Repair (Starts, Ends : in out Offsets; Total : Natural) is
   begin
      for Word in Ends'Range loop
         pragma Loop_Invariant (Ordered (Starts (1 .. Word - 1), Ends (1 .. Word - 1), Total));
         declare
            Stop : constant Natural :=
              (if Word = 1 then Natural'Min (Ends (Word), Total)
               else Natural'Max (Natural'Min (Ends (Word), Total), Ends (Word - 1)));
         begin
            Ends (Word) := Stop;
            Starts (Word) := Natural'Min (Starts (Word), Stop);
         end;
      end loop;
   end Repair;

   function Settled
     (Ends : Offsets; From : Positive; Total, Guard : Natural) return Natural
   is
      Found : Natural := From - 1;
   begin
      while Found < Ends'Length and then Is_Settled (Ends (Found + 1), Total, Guard) loop
         pragma Loop_Variant (Increases => Found);
         pragma Loop_Invariant (Found in From - 1 .. Ends'Length);
         pragma Loop_Invariant
           (for all Word in From .. Found => Is_Settled (Ends (Word), Total, Guard));
         Found := Found + 1;
      end loop;
      return Found;
   end Settled;

   function Passed (Starts, Ends : Offsets; Boundary : Natural) return Natural is
      Found : Natural := 0;
   begin
      while Found < Ends'Length and then Starts (Found + 1) / 2 + Ends (Found + 1) / 2 <= Boundary loop
         pragma Loop_Variant (Increases => Found);
         pragma Loop_Invariant (Found <= Ends'Length);
         pragma Loop_Invariant
           (for all Word in 1 .. Found => Starts (Word) / 2 + Ends (Word) / 2 <= Boundary);
         Found := Found + 1;
      end loop;
      return Found;
   end Passed;

   function Cut_Place
     (Of_Window : Window; Ends : Offsets; Word : Positive) return Sample_Index is
     (Of_Window.Start + Sample_Index (Ends (Word)));

   procedure Append_Text (Into : in out Transcript; Words : String) is
      Room : constant Natural := Text_Capacity - Into.Length;
      Used : constant Natural := Natural'Min (Room, Words'Length);
      Was  : constant Natural := Into.Length;
   begin
      for K in 1 .. Used loop
         Into.Text (Was + K) := Words (Words'First + K - 1);
         pragma Loop_Invariant (Into.Length = Was);
         pragma Loop_Invariant
           (for all J in 1 .. Was => Into.Text (J) = Into.Text'Loop_Entry (J));
      end loop;
      Into.Length := Was + Used;
      if Used < Words'Length then
         Into.Truncated := True;
      end if;
   end Append_Text;

end Speech.Windows;
