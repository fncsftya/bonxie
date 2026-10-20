with Items.Sources;
with Speech.Jobs;
with Viewer.Writing;
with Vision.Jobs;
with Webshot;
with Viewer.Canvas_Items.Basics;
with Viewer.Canvas_Items.Opening;
with Viewer.Canvas_Items.Recognition;

package body Viewer.Canvas_Items.Polling is

   package Windows renames Items.Windows;

   use type Items.Kinds;
   use type Webshot.States;
   use type Items.Extensions.Bounded_String;
   use type Vision.Jobs.States;
   use type Speech.Jobs.States;
   use type Windows.Dictations;

   procedure Poll_Dictation (Item : in out Session) is
      Heard : Speech.Transcript;
   begin
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Windows.Details (Item.Windows (Which)).Kind = Items.Note
         then
            declare
               Each : Windows.Window renames Item.Windows (Which);
               procedure Show (To : Windows.Dictations) is
               begin
                  if Windows.Dictation (Each) /= To then
                     Windows.Set_Dictation (Each, To);
                  end if;
               end Show;
            begin
               case Speech.Jobs.State (Which) is
                  when Speech.Jobs.Idle =>
                     null;
                  when Speech.Jobs.Starting =>
                     Show (Windows.Preparing);
                  when Speech.Jobs.Listening =>
                     Show (Windows.Listening);
                     Windows.Set_Level (Each, Speech.Jobs.Loudness (Which));
                     Speech.Jobs.Heard_So_Far (Which, Heard);
                     Windows.Set_Live_Dictation
                       (Each, Speech.Image (Heard), Heard.Settled);
                  when Speech.Jobs.Finishing =>
                     Show (Windows.Transcribing);
                  when Speech.Jobs.Done =>
                     Speech.Jobs.Take (Which, Heard);
                     Windows.Set_Dictation (Each, Windows.Silent);
                     Windows.Add_Dictation (Each, Speech.Image (Heard));
                  when Speech.Jobs.Failed =>
                     Windows.Set_Dictation
                       (Each, Windows.Failed, Speech.Jobs.Message (Which));
                     Speech.Jobs.Reset (Which);
               end case;
            end;
         end if;
      end loop;
   end Poll_Dictation;

   procedure Poll_Captures (Item : in out Session) is
   begin
      Opening.Poll_Pick (Item);
      Opening.Poll_Download (Item);
      for Which in Items.Slot loop
         if Basics.Is_Source (Item, Which) and then Windows.Is_Paged (Item.Windows (Which)) then
            --  Which page is being read, of a document one page under
            --  another, as the window is scrolled.
            declare
               Now     : constant Natural := Windows.Document_Page (Item.Windows (Which));
               Details : constant Items.Info := Windows.Details (Item.Windows (Which));
            begin
               if Now > 0 and then Now /= Details.Page then
                  Windows.Set_Pages
                    (Item.Windows (Which), Items.Extensions.To_String (Details.Document),
                     Now, Details.Page_Count);
                  Items.Sources.Set_Page (Item.Nav.Store, Details.Key, Now);
                  Writing.Page_Turned (Item, Which);
               end if;
            end;
         end if;
         if Basics.Is_Source (Item, Which) then
            case Webshot.State (Which) is
               when Webshot.Done =>
                  declare
                     Key  : constant Items.Id :=
                       Windows.Details (Item.Windows (Which)).Key;
                     Time : constant Projects.Seconds := Basics.Epoch_Now (Item);
                  begin
                     Recognition.Name_From_Page (Item, Which, Webshot.Page_Title (Which));
                     if Windows.Details (Item.Windows (Which)).Document
                        /= Items.Extensions.Null_Bounded_String
                     then
                        Items.Sources.Set_Document (Item.Nav.Store, Key, "", 0);
                        Windows.Set_Pages (Item.Windows (Which), "", 0, 0);
                     end if;
                     Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
                     Windows.Set_Capture
                       (Item.Windows (Which), Windows.Ready,
                        Items.Sources.Image_File
                          (Item.Nav.Store, Item.Opened.Current, Key),
                        At_Time => Time);
                     Writing.Picture_Taken (Item, Which);
                     Projects.Touch (Item.Nav.Store, Item.Opened.Current);
                  end;
                  Webshot.Reset (Which);
                  Recognition.Start_Recognition (Item, Which);
               when Webshot.Failed =>
                  Windows.Set_Capture
                    (Item.Windows (Which), Windows.Failed,
                     Detail => Webshot.Message (Which));
                  Webshot.Reset (Which);
               when Webshot.Working =>
                  Windows.Set_Progress
                    (Item.Windows (Which), Webshot.Progress (Which));
               when Webshot.Idle | Webshot.Looked =>
                  null;  --  a picture of the top is only asked for by what finds sources
            end case;
            case Vision.Jobs.State (Which) is
               when Vision.Jobs.Done =>
                  Recognition.Keep_Recognition (Item, Which);
               when Vision.Jobs.Failed =>
                  --  The picture still shows, just not as text.
                  Vision.Jobs.Reset (Which);
               when Vision.Jobs.Idle | Vision.Jobs.Working =>
                  null;
            end case;
         end if;
      end loop;
   end Poll_Captures;

end Viewer.Canvas_Items.Polling;
