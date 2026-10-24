with Items.Models;
with Items.Sources;
with Speech.Jobs;
with View.Writing;
with Vision.Jobs;
with Webshot;
with View.Canvas_Items.Basics;
with View.Canvas_Items.Opening;
with View.Canvas_Items.Recognition;

package body View.Canvas_Items.Polling is

   package Windows renames Items.Windows;

   package Models renames Items.Models;

   use type Items.Kinds;
   use type Webshot.States;
   use type Items.Extensions.Text;
   use type Vision.Jobs.States;
   use type Speech.Jobs.States;
   use type Models.Dictations;

   procedure Poll_Dictation (Item : in out Session) is
      Heard : Speech.Transcript;
   begin
      for Which in 1 .. Item.Windows.Count loop
         if Models.Is_Assigned (Item.Models (Which))
           and then Models.Details (Item.Models (Which)).Kind = Items.Note
         then
            declare
               Each : Windows.Window renames Item.Windows (Which);
               procedure Show (To : Models.Dictations) is
               begin
                  if Models.Dictation (Item.Models (Which)) /= To then
                     Windows.Set_Dictation (Each, To);
                  end if;
               end Show;
            begin
               case Speech.Jobs.State (Which) is
                  when Speech.Jobs.Idle =>
                     null;
                  when Speech.Jobs.Starting =>
                     Show (Models.Preparing);
                  when Speech.Jobs.Listening =>
                     Show (Models.Listening);
                     Models.Set_Level (Item.Models (Which), Speech.Jobs.Loudness (Which));
                     Speech.Jobs.Heard_So_Far (Which, Heard);
                     Windows.Set_Live_Dictation
                       (Each, Speech.Image (Heard), Heard.Settled);
                  when Speech.Jobs.Finishing =>
                     Show (Models.Transcribing);
                  when Speech.Jobs.Done =>
                     Speech.Jobs.Take (Which, Heard);
                     Windows.Set_Dictation (Each, Models.Silent);
                     Windows.Add_Dictation (Each, Speech.Image (Heard));
                  when Speech.Jobs.Failed =>
                     Windows.Set_Dictation
                       (Each, Models.Failed, Speech.Jobs.Message (Which));
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
      for Which in 1 .. Item.Windows.Count loop
         if Basics.Is_Source (Item, Which) and then Models.Is_Paged (Item.Models (Which)) then
            --  Which page is being read, of a document one page under
            --  another, as the window is scrolled.
            declare
               Now     : constant Natural := Windows.Document_Page (Item.Windows (Which));
               Details : constant Items.Info := Models.Details (Item.Models (Which));
            begin
               if Now > 0 and then Now /= Details.Page then
                  Models.Set_Pages (Item.Models (Which), Items.Extensions.To_String (Details.Document),
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
                       Models.Details (Item.Models (Which)).Key;
                     Time : constant Projects.Seconds := Basics.Epoch_Now (Item);
                  begin
                     Recognition.Name_From_Page (Item, Which, Webshot.Page_Title (Which));
                     if Models.Details (Item.Models (Which)).Document
                        /= Items.Extensions.Null_Text
                     then
                        Items.Sources.Set_Document (Item.Nav.Store, Key, "", 0);
                        Models.Set_Pages (Item.Models (Which), "", 0, 0);
                     end if;
                     Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
                     Models.Set_Capture (Item.Models (Which), Models.Ready,
                        Items.Sources.Image_File
                          (Item.Nav.Store, Open_Key (Item), Key),
                        At_Time => Time);
                     Writing.Picture_Taken (Item, Which);
                     Projects.Touch (Item.Nav.Store, Open_Key (Item));
                  end;
                  Webshot.Reset (Which);
                  Recognition.Start_Recognition (Item, Which);
               when Webshot.Failed =>
                  Models.Set_Capture (Item.Models (Which), Models.Failed,
                     Detail => Webshot.Message (Which));
                  Webshot.Reset (Which);
               when Webshot.Working =>
                  Models.Set_Progress (Item.Models (Which), Webshot.Progress (Which));
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

end View.Canvas_Items.Polling;
