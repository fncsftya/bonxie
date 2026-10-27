package body Nav_VM is

   use type Confirm_VM.Subjects;
   use type Parts.Version_Number;

   function Screen (Self : View_Model) return Screens
   is (Self.Shown);

   function Mode (Self : View_Model) return Modes
   is (Mode_Properties.Get (Self.Viewing));

   function Project_Key (Self : View_Model) return Projects.Id
   is (Self.Current);

   function Name (Self : View_Model) return String
   is (if Outline_VM.Is_Entered (Self.Outline.all) then Outline_VM.Project_Title (Self.Outline.all) else "");

   function Name_Version (Self : View_Model) return Parts.Version_Number
   is (Outline_VM.Title_Version (Self.Outline.all));

   function Is_Listing (Self : View_Model) return Boolean
   is (Self.Listing);

   function Is_Renaming (Self : View_Model) return Boolean
   is (Self.Renaming);

   function Browser_Open (Self : View_Model) return Boolean
   is (Self.Browsing);

   function Browser_Shown (Self : View_Model) return Boolean
   is (Self.Browsing and then Self.Shown = Project);

   function Draft (Self : View_Model) return String
   is (Parts.Get (Self.Typed));

   procedure Set_Draft (Self : in out View_Model; Text : String) is
   begin
      Parts.Set (Self.Typed, Text);
   end Set_Draft;

   function Layer (Self : View_Model) return Layers
   is (if Confirm_VM.Subject (Self.Dialog.all) = Confirm_VM.Model
       then Model_Dialog
       elsif Settings_VM.Is_Showing (Self.Settings.all)
       then Settings_Form
       elsif Confirm_VM.Is_Asking (Self.Dialog.all)
       then Deleting
       elsif Self.Listing
       then Item_List
       else Plain);

   function Takes_Gestures (Self : View_Model) return Boolean
   is (Self.Shown = Project and then Layer (Self) = Plain);

   function Takes_Search (Self : View_Model) return Boolean
   is (Takes_Gestures (Self) and then Mode (Self) in Canvas | Write);

   function Screen_Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Epoch));

   function Mode_Version (Self : View_Model) return Parts.Version_Number
   is (Mode_Properties.Version (Self.Viewing));

   function Layer_Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Overs));

   function Renaming_Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Titles));

   function Browser_Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Browsers));

   overriding
   function Version (Self : View_Model) return Parts.Version_Number
   is (Screen_Version (Self)
       + Mode_Version (Self)
       + Layer_Version (Self)
       + Renaming_Version (Self)
       + Browser_Version (Self)
       + Parts.Version (Self.Typed)
       + Name_Version (Self)
       + Settings_VM.Version (Self.Settings.all)
       + Confirm_VM.Version (Self.Dialog.all));

   procedure Initialize
     (Self     : in out View_Model;
      Kept     : not null access Library'Class;
      Recent   : not null access constant Home_VM.View_Model;
      Written  : not null access Outline_VM.View_Model;
      Settings : not null access Settings_VM.View_Model;
      Dialog   : not null access Confirm_VM.View_Model) is
   begin
      Self.Kept := Kept.all'Unrestricted_Access;
      Self.Recent := Recent.all'Unrestricted_Access;
      Self.Outline := Written.all'Unrestricted_Access;
      Self.Settings := Settings.all'Unrestricted_Access;
      Self.Dialog := Dialog.all'Unrestricted_Access;
      Mode_Properties.Initialize (Self.Viewing, Canvas);
   end Initialize;

   procedure Open (Self : in out View_Model; Which : Projects.Id) is
   begin
      Self.Shown := Project;
      Self.Current := Which;
      Outline_VM.Enter (Self.Outline.all, Which);
      Self.Listing := False;
      Mode_Properties.Set (Self.Viewing, Canvas);
      Parts.Bump (Self.Epoch);
   end Open;

   procedure Restore_Mode (Self : in out View_Model) is
      Kept : constant Natural := Tab (Self.Kept.all, Self.Current);
   begin
      Mode_Properties.Set (Self.Viewing, Modes'Val (Natural'Min (Kept, Modes'Pos (Modes'Last))));
   end Restore_Mode;

   function Takes_Rows (Self : View_Model) return Boolean
   is (Self.Shown = Home and then Layer (Self) = Plain);

   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      In_Project : constant Boolean := Self.Shown = Project;
   begin
      return
        (case What is
           when Start_Project                 => Takes_Rows (Self),
           when Open_Project                  =>
             Takes_Rows (Self)
             and then (if Index = 0
                       then Home_VM.Count (Self.Recent.all) > 0
                       else Index <= Home_VM.Count (Self.Recent.all)),
           when Open_Settings                 => Self.Shown = Home and then Layer (Self) = Plain,
           when Close_Settings                => Layer (Self) = Settings_Form,
           when Leave_Project                 => In_Project,
           when Show_Outline                  => In_Project,
           when Show_Canvas                   => In_Project,
           when Show_Writing                  => In_Project,
           when Show_Publish                  => In_Project,
           when Open_List                     => In_Project,
           when Close_List                    => Self.Listing,
           when Begin_Rename                  => Takes_Gestures (Self) and then not Self.Renaming,
           when Accept_Rename | Cancel_Rename => Self.Renaming,
           when Dismiss                       => Layer (Self) /= Plain,
           when Add_Document                  =>
             Takes_Gestures (Self)
             and then (if Index = 0
                       then Mode (Self) in Canvas | Write
                       else Mode (Self) = Write and then Index <= Outline_VM.Count (Self.Outline.all)),
           when Add_Source                    => Takes_Gestures (Self) and then Mode (Self) = Canvas,
           when Add_Folder                    => Takes_Gestures (Self) and then Mode (Self) = Write,
           when Toggle_Section_Notes          =>
             Takes_Gestures (Self)
             and then Mode (Self) = Write
             and then Index in 1 .. Outline_VM.Count (Self.Outline.all),
           when Toggle_Browser                => Takes_Gestures (Self));
   end Can_Execute;

   procedure Accept_Draft (Self : in out View_Model) is
      Kept : Boolean;
   begin
      --  Nothing but spaces keeps the name there was.
      Outline_VM.Set_Project_Title (Self.Outline.all, Draft (Self), Kept);
      Self.Renaming := False;
      Parts.Bump (Self.Titles);
   end Accept_Draft;

   procedure Show (Self : in out View_Model; View : Modes) is
   begin
      Mode_Properties.Set (Self.Viewing, View);
      Set_Tab (Self.Kept.all, Self.Current, Modes'Pos (View));
   end Show;

   procedure Observe (Self : in out View_Model; Reactions : access Effects'Class) is
   begin
      Self.Reactions := (if Reactions = null then null else Reactions.all'Unrestricted_Access);
   end Observe;

   procedure Run (Self : in out View_Model; What : Command; Index : Natural);

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
   begin
      if Self.Reactions /= null then
         Going_To_Execute (Self.Reactions.all, What, Index);
      end if;
      Run (Self, What, Index);
      if Self.Reactions /= null then
         Executed (Self.Reactions.all, What, Index);
      end if;
   end Execute;

   procedure Run (Self : in out View_Model; What : Command; Index : Natural) is
   begin
      case What is
         when Start_Project                          =>
            Open (Self, Create (Self.Kept.all));

         when Open_Project                           =>
            Open (Self, Home_VM.Key_Of (Self.Recent.all, Index));

         when Open_Settings                          =>
            Settings_VM.Execute (Self.Settings.all, Settings_VM.Open);
            Parts.Bump (Self.Overs);

         when Close_Settings                         =>
            Settings_VM.Execute (Self.Settings.all, Settings_VM.Close);
            Parts.Bump (Self.Overs);

         when Leave_Project                          =>
            if Self.Renaming then
               Accept_Draft (Self);
            end if;
            Self.Shown := Home;
            Self.Current := 0;
            Outline_VM.Leave (Self.Outline.all);
            Mode_Properties.Set (Self.Viewing, Canvas);
            if Self.Listing then
               Self.Listing := False;
               Parts.Bump (Self.Overs);
            end if;
            Parts.Bump (Self.Epoch);

         when Show_Outline                           =>
            Show (Self, Outline);

         when Show_Canvas                            =>
            Show (Self, Canvas);

         when Show_Writing                           =>
            Show (Self, Write);

         when Show_Publish                           =>
            Show (Self, Publish);

         when Open_List                              =>
            if not Self.Listing then
               Self.Listing := True;
               Parts.Bump (Self.Overs);
            end if;

         when Close_List                             =>
            Self.Listing := False;
            Parts.Bump (Self.Overs);

         when Begin_Rename                           =>
            Self.Renaming := True;
            Parts.Set (Self.Typed, Name (Self));
            Parts.Bump (Self.Titles);

         when Accept_Rename                          =>
            Accept_Draft (Self);

         when Cancel_Rename                          =>
            Self.Renaming := False;
            Parts.Bump (Self.Titles);

         when Toggle_Section_Notes                   =>
            Outline_VM.Execute (Self.Outline.all, Outline_VM.Toggle_Notes, Index);

         when Toggle_Browser                         =>
            Self.Browsing := not Self.Browsing;
            Parts.Bump (Self.Browsers);

         when Add_Document | Add_Source | Add_Folder =>
            --  Creation needs the surface's geometry and focus; Executed supplies that effect.
            null;

         when Dismiss                                =>
            case Layer (Self) is
               when Plain                   =>
                  null;

               when Settings_Form           =>
                  Execute (Self, Close_Settings);

               when Model_Dialog | Deleting =>
                  Confirm_VM.Execute (Self.Dialog.all, Confirm_VM.Cancel);

               when Item_List               =>
                  Execute (Self, Close_List);
            end case;
      end case;
   end Run;

end Nav_VM;
