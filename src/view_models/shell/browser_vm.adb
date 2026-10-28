package body Browser_VM is

   package VM renames Pomarine.View_Models;
   package Strings renames Ada.Strings.Unbounded;

   overriding
   function Parts_Version (Self : Model) return VM.Version_Number
   is (VM.Version (Self.Draft));

   procedure Initialize (Self : in out Model; Shown : not null access Page'Class; Config : String := "") is
   begin
      Self.Shown := Shown.all'Unrestricted_Access;
      Self.Config := Strings.To_Unbounded_String (Config);
      if Config /= "" then
         Favourites.Load (Config, Self.Saved);
      end if;
   end Initialize;

   function Capture_File (Self : Model) return String
   is (if Strings.Length (Self.Config) = 0 then "" else Strings.To_String (Self.Config) & "/capture.png");

   function Favourite_Count (Self : Model) return Natural
   is (Self.Saved.Count);

   function Favourite_Address (Self : Model; Index : Positive) return String
   is (Strings.To_String (Self.Saved (Index).Address));

   function Favourite_Title (Self : Model; Index : Positive) return String
   is (if Strings.Length (Self.Saved (Index).Title) > 0
       then Strings.To_String (Self.Saved (Index).Title)
       else Favourite_Address (Self, Index));

   function Favourite_Colour (Self : Model; Index : Positive) return Natural
   is (if Self.Saved (Index).Colour in 0 .. 16#FFFFFF#
       then Self.Saved (Index).Colour
       else Favourites.Colour_Of (Favourite_Address (Self, Index)));

   function Favourites_Version (Self : Model) return VM.Version_Number
   is (VM.Value (Self.Listed));

   function Is_Favourite (Self : Model) return Boolean
   is (Self.Started and then Favourites.Index_Of (Self.Saved, Strings.To_String (Self.Where)) > 0);

   function Status (Self : Model) return String
   is (case Self.Taking is
         when Idle    => "",
         when Working => "Capturing the page...",
         when Done    => "Captured",
         when Failed  => Strings.To_String (Self.Note));

   function Capture_State (Self : Model) return Capture_States
   is (Self.Taking);

   function Capture_Title (Self : Model) return String
   is (if Strings.Length (Self.Name) > 0 then Strings.To_String (Self.Name) else Strings.To_String (Self.Taken));

   function Capture_Address (Self : Model) return String
   is (Strings.To_String (Self.Taken));

   procedure Finish_Capture (Self : in out Model) is
   begin
      if Self.Shown /= null then
         Self.Shown.Reset_Capture;
      end if;
      Self.Taking := Idle;
      Mark_Changed (Self);
   end Finish_Capture;

   function Address_Draft (Self : Model) return String
   is (VM.Get (Self.Draft));

   procedure Set_Address_Draft (Self : in out Model; Text : String) is
   begin
      VM.Set (Self.Draft, Text);
   end Set_Address_Draft;

   function Has_Started (Self : Model) return Boolean
   is (Self.Started);

   function Address_Of (Text : String) return String is
      function Begins (Prefix : String) return Boolean
      is (Text'Length >= Prefix'Length and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);
   begin
      return (if Begins ("http://") or else Begins ("https://") then Text else "https://" & Text);
   end Address_Of;

   procedure Refresh (Self : in out Model) is
      Behind : Boolean;
      Ahead  : Boolean;
   begin
      if Self.Shown = null or else not Self.Shown.Is_Ready then
         return;
      end if;
      if Self.Started then
         declare
            Where : constant String := Self.Shown.Address;
         begin
            if Where /= "" and then Where /= Strings.To_String (Self.Where) then
               Self.Where := Strings.To_Unbounded_String (Where);
               Set_Address_Draft (Self, Where);
               Mark_Changed (Self);
            end if;
         end;
         Behind := Self.Shown.Can_Go_Back;
         Ahead := Self.Shown.Can_Go_Forward;
         if Behind /= Self.Back_Ok or else Ahead /= Self.Forward_Ok then
            Self.Back_Ok := Behind;
            Self.Forward_Ok := Ahead;
            Mark_Changed (Self);
         end if;
      end if;
      if Self.Taking = Working then
         case Self.Shown.Capture_State is
            when Done   =>
               Self.Taking := Done;
               Self.Name := Strings.To_Unbounded_String (Self.Shown.Capture_Title);
               Mark_Changed (Self);

            when Failed =>
               Self.Taking := Failed;
               Self.Note := Strings.To_Unbounded_String (Self.Shown.Capture_Message);
               Self.Shown.Reset_Capture;
               Mark_Changed (Self);

            when others =>
               null;
         end case;
      end if;
   end Refresh;

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (Self.Shown /= null
       and then Self.Shown.Is_Ready
       and then (case What is
                   when Open_Favourite => Index in 1 .. Self.Saved.Count,
                   when others         =>
                     Index = 0
                     and then (case What is
                                 when Go                 => Address_Draft (Self)'Length > 0,
                                 when Reload | Home | Favourite => Self.Started,
                                 when Back               => Self.Started and then Self.Back_Ok,
                                 when Forward            => Self.Started and then Self.Forward_Ok,
                                 when Capture            =>
                                   Self.Started and then Self.Taking /= Working and then Capture_File (Self) /= "",
                                 when Open_Favourite     => False)));

   procedure Toggle_Favourite (Self : in out Model);
   --  Mark the page, or let it go if it is marked, and keep them.

   procedure Toggle_Favourite (Self : in out Model) is
      Where : constant String := Strings.To_String (Self.Where);
      Found : constant Natural := Favourites.Index_Of (Self.Saved, Where);
      Kept  : Favourites.Lists.List;
   begin
      if Where = "" then
         return;
      end if;
      if Found > 0 then
         for I in 1 .. Self.Saved.Count loop
            if I /= Found then
               Kept.Append (Self.Saved (I));
            end if;
         end loop;
         Self.Saved := Kept;
      else
         Self.Saved.Append
           ((Title   => Strings.To_Unbounded_String (Self.Shown.Title),
             Address => Strings.To_Unbounded_String (Where),
             Colour  => Self.Shown.Theme_Colour));
      end if;
      VM.Bump (Self.Listed);
      if Strings.Length (Self.Config) > 0 then
         Favourites.Save (Strings.To_String (Self.Config), Self.Saved);
      end if;
   end Toggle_Favourite;

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Go             =>
            Self.Started := True;
            Self.Shown.Load (Address_Of (Address_Draft (Self)));

         when Reload         =>
            Self.Shown.Reload;

         when Back           =>
            Self.Shown.Go_Back;

         when Forward        =>
            Self.Shown.Go_Forward;

         when Home           =>
            Self.Started := False;
            Self.Where := Strings.Null_Unbounded_String;
            Set_Address_Draft (Self, "");
            Mark_Changed (Self);

         when Favourite      =>
            Toggle_Favourite (Self);

         when Open_Favourite =>
            Self.Started := True;
            Set_Address_Draft (Self, Favourite_Address (Self, Index));
            Self.Shown.Load (Favourite_Address (Self, Index));

         when Capture        =>
            Self.Taken := Self.Where;
            Self.Name := Strings.Null_Unbounded_String;
            Self.Taking := Working;
            Self.Shown.Start_Capture (Capture_File (Self));
      end case;
   end Perform;

end Browser_VM;
