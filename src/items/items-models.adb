with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Items.Records;
with Items.Sources;

package body Items.Models is

   use type Ada.Calendar.Time;
   use type Pomarine.Events.Milliseconds;

   function Count_Words (Of_Text : String) return Natural is
      Total  : Natural := 0;
      Inside : Boolean := False;
   begin
      for C of Of_Text loop
         if C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
            Inside := False;
         elsif not Inside then
            Inside := True;
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Count_Words;

   function Day (Taken : Projects.Seconds) return String is
      Image : constant String :=
        Ada.Calendar.Formatting.Image
          (Ada.Calendar.Formatting.Time_Of (1970, 1, 1, Time_Zone => 0)
           + Duration (Taken),
           Time_Zone => 0);
      Months : constant array (1 .. 12) of String (1 .. 3) :=
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      Date  : constant Positive := Positive'Value (Image (9 .. 10));
   begin
      return Ada.Strings.Fixed.Trim (Date'Image, Ada.Strings.Both) & " "
        & Months (Positive'Value (Image (6 .. 7))) & " " & Image (1 .. 4);
   end Day;

   function Is_Assigned (Self : Item) return Boolean is (Self.Assigned);

   function Details (Self : Item) return Items.Info is (Self.Fields);

   function Title_Document (Self : in out Item) return Docs.Document_Access is (Self.Title_Doc'Unchecked_Access);

   function Content_Document (Self : in out Item) return Docs.Document_Access is
     (Self.Content_Doc'Unchecked_Access);

   function Text_Document (Self : in out Item) return Docs.Document_Access is (Self.Text_Doc'Unchecked_Access);

   function Text (Self : Item) return String is (Docs.Whole (Self.Content_Doc));

   function Stored_Text (Self : Item) return String is (Docs.Stored (Self.Content_Doc));

   function Shown_Text (Self : Item) return String is (Docs.Whole (Self.Text_Doc));

   function Words (Self : Item) return Natural is (Self.Word_Count);

   function Is_Resizing (Self : Item) return Boolean is (Self.Sizing);

   function Capture (Self : Item) return Captures is (Self.Capturing);

   function Picture_File (Self : Item) return String is (Unbounded.To_String (Self.File));

   function Shows_Picture (Self : Item) return Boolean is
     (Self.Paged or else Unbounded.Length (Self.File) > 0);

   function Is_Unchosen (Self : Item) return Boolean is
     (Self.Fields.Kind = Source and then Self.Fields.Origin = Unchosen);

   function Is_Text_Source (Self : Item) return Boolean is
     (Self.Fields.Kind = Source and then Self.Fields.Origin /= Unchosen
      and then Items.Sources.Is_Text (Items.Extensions.To_String (Self.Fields.Document)));

   function Is_Open_Source (Self : Item) return Boolean is
     (Self.Fields.Kind = Source and then Self.Fields.State = Open);

   function Wants_Pages (Self : Item) return Boolean is
     (Self.Fields.Page > 0 and then Items.Sources.Is_Vector (Items.Extensions.To_String (Self.Fields.Document)));

   function Is_Paged (Self : Item) return Boolean is (Self.Paged);

   function Progress (Self : Item) return Float is (Self.Working);

   function Shows_Progress (Self : Item) return Boolean is
     (if Self.Fields.Kind = Source then Self.Capturing = Busy else Self.Dictating = Listening);

   function Recognized (Self : in out Item) return access Vision.Result is (Self.Found'Unchecked_Access);

   function Recognized_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Words_Found));

   function Picture_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Pictures));

   function Tool (Self : Item) return Tools is (Self.Using_Tool);

   function Marks_To_Show (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Marks_Shown));

   function Kept_Marks (Self : Item) return Items.Marks.Mark_List is (Self.Marks_Kept);

   function Mark_Count (Self : Item) return Natural is (Self.Marks_Kept.Count);

   function Marks_Reported (Self : Item) return Natural is (Self.Marks_Now);

   function Dictation (Self : Item) return Dictations is (Self.Dictating);

   function Editor (Self : in out Item) return access Editor_VM.View_Model is (Self.Editing'Unchecked_Access);

   function Scroll_Pending (Self : Item) return Boolean is (Self.Scroll_Waits);

   function Where_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Wheres));

   function Look_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Looks));

   function Shape_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Shapes));

   function Zoom_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Zooms));

   function Tool_Version (Self : Item) return Parts.Version_Number is (Parts.Value (Self.Choices));

   function Page_Status (Self : Item) return String is
     ("Page" & Self.Fields.Page'Image & " of" & Self.Fields.Page_Count'Image);

   function Status (Self : Item) return String is
   begin
      if Self.Fields.Kind = Note then
         return
           (case Self.Dictating is
               when Silent       => "",
               when Preparing    => "Getting ready...",
               when Listening    => "Listening...",
               when Transcribing => "Transcribing...",
               when Failed       => "Could not dictate: " & Unbounded.To_String (Self.Speech));
      end if;
      return
        (case Self.Capturing is
            when Waiting =>
              (case Self.Fields.Origin is
                  when Unchosen => "Choose where it comes from",
                  when Remote   => "Press Return to capture",
                  when Local    => "Choose a file"),
            when Busy    => "Capturing...",
            when Ready   =>
              (if Self.Fields.Page_Count > 0 then Page_Status (Self)
               else "Captured " & Day (Self.Fields.Captured_At)),
            when Failed  => "Failed: " & Unbounded.To_String (Self.Failure));
   end Status;

   procedure Looked (Self : in out Item) is
   begin
      Parts.Bump (Self.Looks);
   end Looked;

   procedure Shaped (Self : in out Item) is
   begin
      Parts.Bump (Self.Shapes);
   end Shaped;

   procedure Placed (Self : in out Item) is
   begin
      Parts.Bump (Self.Wheres);
   end Placed;

   procedure Clear_Recognized (Self : in out Item) is
   begin
      Self.Found.Count := 0;
      Self.Found.Length := 0;
      Self.Found.Truncated := False;
      Parts.Bump (Self.Words_Found);
   end Clear_Recognized;

   procedure Set_Recognized (Self : in out Item; Found : Vision.Result) is
   begin
      Self.Found := Found;
      Parts.Bump (Self.Words_Found);
   end Set_Recognized;

   procedure Forget_Marks (Self : in out Item) is
   begin
      Self.Marks_Kept := (others => <>);
      Self.Marks_Dirty := False;
      Self.Marks_Now := 0;
      Self.Marks_Saved := 0;
      Parts.Bump (Self.Marks_Shown);
   end Forget_Marks;

   procedure Refresh (Self : in out Item) is
   begin
      if Docs.Current (Self.Title_Doc) /= Self.Title_Version then
         Self.Fields.Title := Projects.Titles.To_Text (Docs.Whole (Self.Title_Doc));
         Self.Title_Version := Docs.Current (Self.Title_Doc);
      end if;
      if Docs.Current (Self.Content_Doc) /= Self.Content_Version then
         Self.Content_Version := Docs.Current (Self.Content_Doc);
         if Self.Fields.Kind = Note then
            Self.Word_Count := Count_Words (Docs.Whole (Self.Content_Doc));
            --  A failure to dictate is told until the text is changed; what is going on is told while it is.
            if Self.Dictating in Silent | Failed then
               Self.Dictating := Silent;
               Looked (Self);
            end if;
         end if;
      end if;
   end Refresh;

   procedure Set_Title_Text (Self : in out Item; To : String) is
   begin
      Docs.Replace (Self.Title_Doc, (Paragraph => 1, Index => 1), Docs.Text_End (Self.Title_Doc), To);
      Refresh (Self);
   end Set_Title_Text;

   procedure Set_Link (Self : in out Item; To : String) is
   begin
      Docs.Replace (Self.Content_Doc, (Paragraph => 1, Index => 1), Docs.Text_End (Self.Content_Doc), To);
      Refresh (Self);
   end Set_Link;

   procedure Hold_Typing (Self : in out Item; To : Boolean) is
   begin
      Self.Held := To;
   end Hold_Typing;

   procedure Move (Self : in out Item; Across, Down : Float) is
   begin
      Self.Fields.Where.Left := Self.Fields.Where.Left + Across;
      Self.Fields.Where.Top := Self.Fields.Where.Top + Down;
      Self.Frame_Dirty := True;
      Placed (Self);
   end Move;

   procedure Resize (Self : in out Item; Across, Down : Float; Still : Boolean) is
   begin
      if not Self.Sizing then
         Self.Raw_Width := Self.Fields.Where.Width;
         Self.Raw_Height := Self.Fields.Where.Height;
      end if;
      Self.Raw_Width := Self.Raw_Width + Across;
      Self.Raw_Height := Self.Raw_Height + Down;
      Self.Fields.Where := Sized
        ((Self.Fields.Where with delta Width => Self.Raw_Width, Height => Self.Raw_Height));
      Self.Frame_Dirty := True;
      Self.Sizing := Still;
      Placed (Self);
   end Resize;

   procedure Select_Tool (Self : in out Item; To : Tools) is
   begin
      if Self.Using_Tool /= To then
         Self.Using_Tool := To;
         Parts.Bump (Self.Choices);
      end if;
   end Select_Tool;

   procedure Set_State (Self : in out Item; To : Items.States) is
   begin
      Self.Fields.State := To;
      if To /= Open then
         Select_Tool (Self, Pointer);
      end if;
      Placed (Self);
   end Set_State;

   procedure Set_Zoom (Self : in out Item; To : Float) is
   begin
      if To /= Self.Fields.Zoom then
         Self.Fields.Zoom := To;
         Self.Zoom_Dirty := True;
         Parts.Bump (Self.Zooms);
      end if;
   end Set_Zoom;

   procedure Set_Capture
     (Self    : in out Item;
      To      : Captures;
      File    : String := "";
      Detail  : String := "";
      At_Time : Projects.Seconds := 0) is
   begin
      Self.Capturing := To;
      if To = Busy then
         Self.Working := 0.0;
      end if;
      case To is
         when Waiting | Busy =>
            null;
         when Ready =>
            Self.Fields.Captured_At := At_Time;
            Clear_Recognized (Self);
            Forget_Marks (Self);
            Self.File := Unbounded.To_Unbounded_String (File);
            Self.Paged := False;
            Parts.Bump (Self.Pictures);
         when Failed =>
            Self.Failure := Unbounded.To_Unbounded_String (Detail);
      end case;
      Shaped (Self);
   end Set_Capture;

   procedure Pages_Opened (Self : in out Item; Ok : Boolean; Message : String := "") is
   begin
      Self.Paged := Ok;
      if not Ok then
         Self.Capturing := Failed;
         Self.Failure := Unbounded.To_Unbounded_String (Message);
         Self.File := Unbounded.Null_Unbounded_String;
      end if;
      Shaped (Self);
   end Pages_Opened;

   procedure Set_Origin (Self : in out Item; To : Items.Origins) is
   begin
      Self.Fields.Origin := To;
      if Self.Fields.Captured_At = 0 then
         Self.Capturing := Waiting;
      end if;
      Looked (Self);
      Shaped (Self);
   end Set_Origin;

   procedure Set_Pages (Self : in out Item; Document : String; Page, Count : Natural) is
   begin
      Self.Fields.Document := Items.Extensions.To_Text (Document);
      Self.Fields.Page := Page;
      Self.Fields.Page_Count := Count;
      Shaped (Self);
   end Set_Pages;

   procedure Show_Text (Self : in out Item; File : String; At_Time : Projects.Seconds) is
   begin
      Self.Fields.Captured_At := At_Time;
      Clear_Recognized (Self);
      Forget_Marks (Self);
      Self.File := Unbounded.Null_Unbounded_String;
      Self.Paged := False;
      Self.Capturing := Ready;
      Docs.Load (Self.Text_Doc, Items.Sources.Read_Text (File));
      Parts.Bump (Self.Pictures);
      Shaped (Self);
   end Show_Text;

   procedure Set_Progress (Self : in out Item; To : Float) is
   begin
      Self.Working := To;
   end Set_Progress;

   procedure Set_Marks (Self : in out Item; Kept : Items.Marks.Mark_List) is
   begin
      Self.Marks_Kept := Kept;
      Self.Marks_Dirty := False;
      Parts.Bump (Self.Marks_Shown);
   end Set_Marks;

   procedure Marks_Shown_As (Self : in out Item; Version : Natural) is
   begin
      Self.Marks_Now := Version;
      Self.Marks_Saved := Version;
      Self.Marks_Dirty := False;
   end Marks_Shown_As;

   procedure Report_Marks (Self : in out Item; Made : Items.Marks.Mark_List; Version : Natural) is
   begin
      Self.Marks_Kept := Made;
      Self.Marks_Now := Version;
      Self.Marks_Dirty := Version /= Self.Marks_Saved;
   end Report_Marks;

   procedure Set_Dictation (Self : in out Item; To : Dictations; Detail : String := "") is
   begin
      Self.Dictating := To;
      Self.Working := 0.0;
      if To = Failed then
         Self.Speech := Unbounded.To_Unbounded_String (Detail);
      end if;
      Looked (Self);
   end Set_Dictation;

   procedure Change_Dictation
     (Self : in out Item; View : in out Editor_VM.Editor'Class; To : Dictations; Detail : String := "") is
   begin
      if To = Failed then
         Editor_VM.Take_Back_Live (Self.Editing, View);
      end if;
      Set_Dictation (Self, To, Detail);
   end Change_Dictation;

   Level_Steps : constant Float := 20.0;
   --  How many sizes of the bar that shows how loud the speech is.

   procedure Set_Level (Self : in out Item; To : Float) is
      Stepped : constant Float := Float'Rounding (To * Level_Steps) / Level_Steps;
   begin
      if Self.Dictating = Listening and then Self.Working /= Stepped then
         Self.Working := Stepped;
      end if;
   end Set_Level;

   procedure Report (Self : in out Item; What : Facts) is
   begin
      --  The size the corner asks for is the size it has, while it is not being dragged.
      if not Self.Sizing then
         Self.Raw_Width := Self.Fields.Where.Width;
         Self.Raw_Height := Self.Fields.Where.Height;
      end if;
      Self.Sizing := What.Sizing;
      Self.Known := What;
   end Report;

   procedure Scrolled (Self : in out Item; Scroll : Float) is
   begin
      Self.Scroll_Waits := False;
      Self.Scroll_Seen := Scroll;
   end Scrolled;

   procedure Assign
     (Self         : in out Item;
      Of_Item      : Items.Info;
      Saved_Text   : String;
      Shown_File   : String := "") is
   begin
      Self.Assigned := True;
      Self.Fields := Of_Item;
      Docs.Load (Self.Title_Doc, Projects.Titles.To_String (Of_Item.Title));
      Docs.Load_Stored (Self.Content_Doc, Saved_Text);
      Docs.Load (Self.Text_Doc, "");
      Self.Dictating := Silent;
      Editor_VM.Initialize (Self.Editing, Self.Content_Doc'Unchecked_Access);
      Self.Title_Saved := Docs.State (Self.Title_Doc);
      Self.Title_Seen := Self.Title_Saved;
      Self.Content_Saved := Docs.State (Self.Content_Doc);
      Self.Content_Seen := Self.Content_Saved;
      Self.Frame_Dirty := False;
      Self.Zoom_Dirty := False;
      Self.Scroll_Seen := Of_Item.Scroll;
      Self.Across_Seen := Of_Item.Scroll_Across;
      Self.Scroll_At := 0;
      Self.Scroll_Waits := False;
      Self.Sizing := False;
      Self.Known := (others => <>);
      Self.Title_Version := 0;
      Self.Content_Version := 0;
      Self.Word_Count := 0;
      Self.Title_Version := Docs.Current (Self.Title_Doc) + 1;
      Self.Content_Version := Docs.Current (Self.Content_Doc) + 1;
      Refresh (Self);
      Clear_Recognized (Self);
      Forget_Marks (Self);
      Self.File := Unbounded.Null_Unbounded_String;
      Self.Failure := Unbounded.Null_Unbounded_String;
      Self.Paged := False;
      Self.Working := 0.0;
      Self.Capturing := Waiting;
      Self.Using_Tool := Pointer;
      Parts.Bump (Self.Pictures);
      if Of_Item.Kind = Source then
         Self.Content_Version := Docs.Current (Self.Content_Doc);
         if Of_Item.Captured_At > 0 and then Shown_File /= "" then
            if Is_Text_Source (Self) then
               Show_Text (Self, Shown_File, Of_Item.Captured_At);
            else
               Set_Capture (Self, Ready, Shown_File, At_Time => Of_Item.Captured_At);
            end if;
         end if;
      else
         Self.Scroll_Waits := Of_Item.Scroll > 0.0;
      end if;
      Self.Fields.State := Of_Item.State;
      Placed (Self);
      Looked (Self);
      Shaped (Self);
   end Assign;

   procedure Release (Self : in out Item) is
   begin
      Clear_Recognized (Self);
      Self.File := Unbounded.Null_Unbounded_String;
      Self.Paged := False;
      Parts.Bump (Self.Pictures);
      Self.Assigned := False;
      Self.Frame_Dirty := False;
      Self.Zoom_Dirty := False;
      Self.Scroll_Waits := False;
      Self.Dictating := Silent;
      Editor_VM.Reset (Self.Editing);
      Forget_Marks (Self);
      Placed (Self);
      Looked (Self);
      Shaped (Self);
   end Release;

   procedure Flush
     (Self  : in out Item;
      Store : in out Projects.Store;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
   is
      Title_Now   : constant Natural := Docs.State (Self.Title_Doc);
      Content_Now : constant Natural := Docs.State (Self.Content_Doc);
      Typing      : constant Boolean := Self.Known.Typing or else Self.Held;
   begin
      Wrote := False;
      Refresh (Self);
      if Title_Now /= Self.Title_Seen or else Content_Now /= Self.Content_Seen then
         Self.Title_Seen := Title_Now;
         Self.Content_Seen := Content_Now;
         Self.Changed_At := Now;
      end if;

      if Self.Frame_Dirty and then not Self.Known.Dragging then
         Items.Records.Set_Frame (Store, Self.Fields.Key, Self.Fields.Where);
         Self.Frame_Dirty := False;
         Wrote := True;
      end if;

      if Self.Zoom_Dirty and then not Self.Known.Zooming then
         Items.Sources.Set_Zoom (Store, Self.Fields.Key, Self.Fields.Zoom);
         Self.Zoom_Dirty := False;
         Wrote := True;
      end if;

      if not Self.Scroll_Waits and then Self.Fields.State = Open then
         declare
            Top    : constant Float := Self.Known.Scroll;
            Across : constant Float := Self.Known.Across;
         begin
            if Top /= Self.Scroll_Seen or else Across /= Self.Across_Seen then
               Self.Scroll_Seen := Top;
               Self.Across_Seen := Across;
               Self.Scroll_At := Now;
            end if;
            if (Top /= Self.Fields.Scroll or else Across /= Self.Fields.Scroll_Across)
              and then (Force or else Now >= Self.Scroll_At + Idle_Delay)
            then
               Items.Records.Set_Scroll (Store, Self.Fields.Key, Top, Across);
               Self.Fields.Scroll := Top;
               Self.Fields.Scroll_Across := Across;
               Wrote := True;
            end if;
         end;
      end if;

      if Self.Fields.Kind = Source and then Self.Marks_Dirty and then not Self.Known.Marking then
         Items.Marks.Save_Marks (Store, Self.Fields.Key, Self.Marks_Kept);
         Self.Marks_Saved := Self.Marks_Now;
         Self.Marks_Dirty := False;
         Wrote := True;
      end if;

      if (Title_Now /= Self.Title_Saved or else Content_Now /= Self.Content_Saved)
        and then (Force or else not Typing or else Now >= Self.Changed_At + Idle_Delay)
      then
         if Title_Now /= Self.Title_Saved then
            Items.Records.Set_Title (Store, Self.Fields.Key, Projects.Titles.To_String (Self.Fields.Title));
            Self.Title_Saved := Title_Now;
         end if;
         if Content_Now /= Self.Content_Saved then
            Items.Records.Set_Content (Store, Self.Fields.Key, Docs.Stored (Self.Content_Doc));
            Self.Content_Saved := Content_Now;
         end if;
         Wrote := True;
      end if;
   end Flush;

end Items.Models;
