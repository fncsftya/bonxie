package body Editor_VM is
   package Parts renames Pomarine.View_Models;
   use type Parts.Version_Number;
   use type Docs.Document_Access;
   use type Docs.Version;
   use type Texts.Position;

   procedure Initialize (Self : in out View_Model; Document : not null access Docs.Document) is
   begin
      if Self.Document /= Docs.Document_Access (Document) then
         Parts.Bump (Self.Changes);
      end if;
      Self.Document := Docs.Document_Access (Document);
      Reset (Self);
   end Initialize;

   procedure Reset (Self : in out View_Model) is
   begin
      if Self.Live /= Live_State'(others => <>) then
         Self.Live := (others => <>);
         Parts.Bump (Self.Changes);
      end if;
   end Reset;

   function Is_Initialized (Self : View_Model) return Boolean
   is (Self.Document /= null);

   function Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes)
       + (if Is_Initialized (Self) then Parts.Version_Number (Docs.Current (Self.Document.all)) else 0));

   function Has_Live (Self : View_Model) return Boolean
   is (Self.Live.Shown);

   procedure Take_Back_Live (Self : in out View_Model; View : in out Editor'Class) is
      Doc    : Docs.Document renames Self.Document.all;
      Live   : Live_State renames Self.Live;
      Before : constant Live_State := Live;
   begin
      if Live.Shown then
         if Docs.Current (Doc) = Live.Seen then
            Docs.Replace (Doc, Live.From, Live.To, "", Recorded => False);
         else
            Live.Done := Live.Upto;
            Live.Moved := True;
         end if;
      end if;
      Clear_Faint (View);
      Live.Shown := False;
      if Live /= Before then
         Parts.Bump (Self.Changes);
      end if;
   end Take_Back_Live;

   function Unsaid (Self : View_Model; Spoken : String) return String
   is (if Self.Live.Done >= Spoken'Length then "" else Spoken (Spoken'First + Self.Live.Done .. Spoken'Last));

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

   procedure Show (Self : in out View_Model; View : in out Editor'Class; Said : String; Settled : Natural := 0) is
      Doc   : Docs.Document renames Self.Document.all;
      Live  : Live_State renames Self.Live;
      Whole : constant String := One_Line_Feeds (Said);
   begin
      if Live.Shown and then Docs.Current (Doc) /= Live.Seen then
         Take_Back_Live (Self, View);  --  keeps what was shown

      end if;
      if Docs.Current (Doc) /= Live.Version then
         --  Being typed in: nothing is shown until it stops.
         Live.Version := Docs.Current (Doc);
         return;
      end if;
      declare
         Spoken : constant String := Unsaid (Self, Whole);
         Fresh  : constant Natural := (if Settled > Live.Done then Settled - Live.Done else 0);
      begin
         if not Live.Shown then
            if Spoken = "" then
               return;
            end if;
            if Live.Moved or else Focused (View) then
               Live.From := Caret (View);
               Live.Break := False;
            else
               Live.From := Docs.Text_End (Doc);
               Live.Break := Docs.Byte_Length (Doc, Docs.Count (Doc)) /= 0;
            end if;
            Live.To := Live.From;
            Live.Shown := True;
         end if;
         declare
            Shown : constant String := (if Live.Break then [ASCII.LF] else "") & Spoken;
         begin
            Live.Upto := Live.Done + Spoken'Length;
            if Docs.Between (Doc, Live.From, Live.To) /= Shown then
               Docs.Replace (Doc, Live.From, Live.To, Shown, Recorded => False);
               if Caret (View) = Live.From and then Mark (View) = Live.From then
                  --  Typing goes on after what is shown, not before it.
                  Live.To := Texts.End_After (Live.From, Shown);
                  Select_Range (View, Live.To, Live.To);
               else
                  Live.To := Texts.End_After (Live.From, Shown);
               end if;
               Live.Seen := Docs.Current (Doc);
               Live.Version := Live.Seen;
            end if;
            declare
               --  What is not settled starts at a character's beginning.
               Edge : Natural := Natural'Min (Fresh, Spoken'Length);
            begin
               while Edge < Spoken'Length and then Character'Pos (Spoken (Spoken'First + Edge)) in 16#80# .. 16#BF# loop
                  Edge := Edge + 1;
               end loop;
               if Edge < Spoken'Length then
                  Set_Faint
                    (View,
                     Texts.End_After (Live.From, Shown (Shown'First .. Shown'Last - (Spoken'Length - Edge))),
                     Live.To);
               else
                  Clear_Faint (View);
               end if;
            end;
         end;
      end;
   end Show;

   procedure Append (Self : in out View_Model; View : in out Editor'Class; Said : String) is
      Doc   : Docs.Document renames Self.Document.all;
      Live  : Live_State renames Self.Live;
      Whole : constant String := One_Line_Feeds (Said);
   begin
      Take_Back_Live (Self, View);
      declare
         --  What was kept as typed text, while being dictated, is not put in again.
         Spoken   : constant String := Unsaid (Self, Whole);
         At_Caret : constant Boolean := Live.Moved or else Focused (View);
      begin
         Live.Done := 0;
         Live.Moved := False;
         if Spoken = "" then
            return;
         end if;
         if At_Caret then
            --  At the caret, not over what is selected.
            Select_Range (View, Caret (View), Caret (View));
            Insert (View, Spoken);
         else
            declare
               After : constant Texts.Position := Docs.Text_End (Doc);
               --  An empty last paragraph is filled, not left as a gap.
               Blank : constant Boolean := Docs.Byte_Length (Doc, Docs.Count (Doc)) = 0;
            begin
               Docs.Begin_Step (Doc);
               Docs.Replace (Doc, After, After, (if Blank then "" else [ASCII.LF]) & Spoken);
               Docs.End_Step (Doc);
            end;
         end if;
      end;
   end Append;

   procedure Show_Live (Self : in out View_Model; View : in out Editor'Class; Said : String; Settled : Natural := 0) is
      Before : constant Live_State := Self.Live;
   begin
      Show (Self, View, Said, Settled);
      if Self.Live /= Before then
         Parts.Bump (Self.Changes);
      end if;
   end Show_Live;

   procedure Append_Said (Self : in out View_Model; View : in out Editor'Class; Said : String) is
      Before : constant Live_State := Self.Live;
   begin
      Append (Self, View, Said);
      if Self.Live /= Before then
         Parts.Bump (Self.Changes);
      end if;
   end Append_Said;
end Editor_VM;
