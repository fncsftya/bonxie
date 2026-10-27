package body Publish_VM is
   use type Nav_VM.Modes;
   use type Parts.Version_Number;
   use type Pomarine.Events.Milliseconds;
   Copied_For : constant Pomarine.Events.Milliseconds := 2_500;

   procedure Initialize
     (Self       : in out View_Model;
      Navigation : not null access Nav_VM.View_Model;
      Platform   : access Effects'Class := null;
      Files      : access Store'Class := null) is
   begin
      Self.Navigation := Navigation.all'Unchecked_Access;
      Self.Platform := (if Platform = null then null else Platform.all'Unchecked_Access);
      Self.Files := (if Files = null then null else Files.all'Unchecked_Access);
   end Initialize;

   function Section_Headings (Self : View_Model) return Boolean
   is (Self.Sections);
   function Document_Headings (Self : View_Model) return Boolean
   is (Self.Documents);
   function Markdown (Self : View_Model) return Boolean
   is (Self.Chosen);
   function Format_Open (Self : View_Model) return Boolean
   is (Self.Opened);
   function Content_Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Content));
   overriding
   function Version (Self : View_Model) return Parts.Version_Number
   is (Content_Version (Self) + Parts.Value (Self.Menu) + Parts.Value (Self.Status));

   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
   begin
      if What = Close_Format then
         return Index = 0 and then Self.Opened;
      end if;
      return
        Self.Navigation /= null
        and then Nav_VM.Takes_Gestures (Self.Navigation.all)
        and then Nav_VM.Mode (Self.Navigation.all) = Nav_VM.Publish
        and then (if What = Choose_Markdown then Index = 1 and then Self.Opened else Index = 0)
        and then (case What is
                    when Export =>
                      Self.Chosen
                      and then not Self.Pending
                      and then Self.Platform /= null
                      and then Self.Files /= null
                      and then Export_Available (Self.Platform.all),
                    when Copy   =>
                      Self.Chosen and then Self.Platform /= null and then Copy_Available (Self.Platform.all),
                    when others => True);
   end Can_Execute;

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
   begin
      pragma Assert (Can_Execute (Self, What, Index));
      case What is
         when Toggle_Section_Headings      =>
            Self.Sections := not Self.Sections;
            Parts.Bump (Self.Content);

         when Toggle_Document_Headings     =>
            Self.Documents := not Self.Documents;
            Parts.Bump (Self.Content);

         when Toggle_Format | Close_Format =>
            Self.Opened := not Self.Opened;
            Parts.Bump (Self.Menu);

         when Export                       =>
            Self.Snapshot := Long_Texts.To_Text (Markdown_Text (Self.Platform.all));
            Ask_Export (Self.Platform.all);
            Self.Pending := True;
            Parts.Bump (Self.Status);

         when Copy                         =>
            declare
               Succeeded : Boolean;
            begin
               Copy_Text (Self.Platform.all, Markdown_Text (Self.Platform.all), Succeeded);
               if Succeeded then
                  declare
                     Now        : constant Pomarine.Events.Milliseconds := Clock (Self.Platform.all);
                     Until_Time : constant Pomarine.Events.Milliseconds :=
                       Now + Pomarine.Events.Milliseconds'Min (Copied_For, Pomarine.Events.Milliseconds'Last - Now);
                  begin
                     if not Self.Copied or else Self.Copied_Until /= Until_Time then
                        Self.Copied := True;
                        Self.Copied_Until := Until_Time;
                        Parts.Bump (Self.Status);
                     end if;
                  end;
               end if;
            end;

         when Choose_Markdown              =>
            if not Self.Chosen then
               Self.Chosen := True;
               Parts.Bump (Self.Content);
            end if;
            Self.Opened := False;
            Parts.Bump (Self.Menu);
      end case;
   end Execute;
   function Export_Pending (Self : View_Model) return Boolean
   is (Self.Pending);
   function Copy_Caption (Self : View_Model) return String
   is (if Self.Copied then "Copied" else "Copy to Clipboard");
   function Copy_Remaining (Self : View_Model) return Integer is
   begin
      if not Self.Copied then
         return -1;
      end if;
      return
        Integer
          (Pomarine.Events.Milliseconds'Min
             (Pomarine.Events.Milliseconds (Integer'Last),
              Pomarine.Events.Milliseconds'Max (0, Self.Copied_Until - Clock (Self.Platform.all))));
   end Copy_Remaining;

   function File_Name (Path : String) return String
   is (if (for some I in reverse Path'Range => Path (I) = '.' and then (for all J in I .. Path'Last => Path (J) /= '/'))
       then Path
       else Path & ".md");

   procedure Poll (Self : in out View_Model) is
   begin
      if Self.Copied and then Clock (Self.Platform.all) >= Self.Copied_Until then
         Self.Copied := False;
         Self.Copied_Until := 0;
         Parts.Bump (Self.Status);
      end if;
      if Self.Pending then
         declare
            State : Export_States;
            Path  : Long_Texts.Text;
         begin
            Export_Result (Self.Platform.all, State, Path);
            if State /= Waiting then
               Self.Pending := False;
               Parts.Bump (Self.Status);
               if State = Chosen and then Long_Texts.Length (Path) > 0 then
                  begin
                     Save
                       (Self.Files.all, File_Name (Long_Texts.To_String (Path)), Long_Texts.To_String (Self.Snapshot));
                  exception
                     when others =>
                        null; --  A failed write must release the pending request for another attempt.
                  end;
               end if;
               Self.Snapshot := Long_Texts.Null_Text;
            end if;
         end;
      end if;
   end Poll;
end Publish_VM;
