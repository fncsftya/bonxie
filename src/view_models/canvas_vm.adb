with Projects;

package body Canvas_VM is

   package Models renames Items.Models;

   use type Items.Id;
   use type Items.Models.Camera;
   use type Items.Models.Tools;
   use type Items.States;
   use type Items.Kinds;
   use type Items.Links.Strokes;
   use type Items.Links.Endings;
   use type Parts.Version_Number;

   function Is_Entered (Self : View_Model) return Boolean is (Self.Entered);

   function Is_Item (Self : View_Model; Slot : Items.Slot) return Boolean is
     (Self.Models /= null and then Slot <= Self.Models.Count and then Models.Is_Assigned (Self.Models.all (Slot)));

   function Count (Self : View_Model) return Natural is
      Found : Natural := 0;
   begin
      if Self.Models /= null then
         for Each in 1 .. Self.Models.Count loop
            if Models.Is_Assigned (Self.Models.all (Each)) then
               Found := Found + 1;
            end if;
         end loop;
      end if;
      return Found;
   end Count;

   function Key_Of (Self : View_Model; Slot : Items.Slot) return Items.Id is
     (Models.Details (Self.Models.all (Slot)).Key);

   procedure Order (Self : View_Model; Into : in out Slot_Lists.List) is
   begin
      Into.Clear;
      if Self.Models = null then
         return;
      end if;
      for Which in 1 .. Self.Models.Count loop
         if Models.Is_Assigned (Self.Models.all (Which)) then
            --  Inserted among those before it by when they were made, which the ids give.
            declare
               Key      : constant Items.Id := Key_Of (Self, Which);
               At_Index : Natural := Into.Count;
            begin
               Into.Append (Which);
               while At_Index >= 1 and then Key_Of (Self, Into (At_Index)) > Key loop
                  Into (At_Index + 1) := Into (At_Index);
                  At_Index := At_Index - 1;
               end loop;
               Into (At_Index + 1) := Which;
            end;
         end if;
      end loop;
   end Order;

   function Made (Self : View_Model) return Natural is (Self.Last_Made);

   function Source_Rank (Self : View_Model; Slot : Items.Slot) return Natural is
      Key  : constant Items.Id := Key_Of (Self, Slot);
      Rank : Natural := 0;
   begin
      if Models.Details (Self.Models.all (Slot)).Kind /= Items.Source then
         return 0;
      end if;
      for Each in 1 .. Self.Models.Count loop
         if Models.Is_Assigned (Self.Models.all (Each))
           and then Models.Details (Self.Models.all (Each)).Kind = Items.Source
           and then Key_Of (Self, Each) <= Key
         then
            Rank := Rank + 1;
         end if;
      end loop;
      return Rank;
   end Source_Rank;

   function Items_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Shown));

   function Raised (Self : View_Model) return Natural is (Self.Front);

   function Raised_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Fronts));

   function Camera (Self : View_Model) return Items.Models.Camera is (Self.Looking);

   function Shown_Camera (Self : in out View_Model) return access constant Items.Models.Camera is
     (Self.Looking'Unchecked_Access);

   function Camera_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Looks));

   function Viewport_Width (Self : View_Model) return Float is (Self.Width);

   function Viewport_Height (Self : View_Model) return Float is (Self.Height);

   function Middle (Self : View_Model; Across : Boolean) return Float is
     (if Across then (Self.Width / 2.0 - Self.Looking.Origin_X) / Self.Looking.Zoom
      else (Self.Height / 2.0 - Self.Looking.Origin_Y) / Self.Looking.Zoom);

   function Steering (Self : View_Model) return Steer is (Self.Asked);

   function Steering_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Asks));

   function Link_Count (Self : View_Model) return Natural is (Self.Link_Set.Count);

   function Link_At (Self : View_Model; Number : Positive) return Items.Links.Link is (Self.Link_Set (Number));

   function Link_Number (Self : View_Model; Key : Items.Id) return Natural is
   begin
      if Key = 0 then
         return 0;
      end if;
      for Each in 1 .. Self.Link_Set.Count loop
         if Self.Link_Set (Each).Key = Key then
            return Each;
         end if;
      end loop;
      return 0;
   end Link_Number;

   function Slot_Of (Self : View_Model; Key : Items.Id) return Natural is
   begin
      if Self.Models /= null then
         for Each in 1 .. Self.Models.Count loop
            if Models.Is_Assigned (Self.Models.all (Each)) and then Key_Of (Self, Each) = Key then
               return Each;
            end if;
         end loop;
      end if;
      return 0;
   end Slot_Of;

   function Selected_Link (Self : View_Model) return Items.Id is (Self.Chosen);

   function Link_From (Self : View_Model) return Natural is (Self.From);

   function Link_From_Side (Self : View_Model) return Items.Links.Sides is (Self.From_Side);

   function Is_Moving_Link (Self : View_Model) return Boolean is (Self.Moving);

   function Links_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Joined));

   overriding function Version (Self : View_Model) return Parts.Version_Number is
     (Items_Version (Self) + Camera_Version (Self) + Steering_Version (Self) + Raised_Version (Self)
      + Links_Version (Self));

   procedure Initialize
     (Self   : in out View_Model;
      Kept   : not null access Library'Class;
      Room   : not null access Surface'Class;
      Slots  : not null access Items.Models.Tables.Table) is
   begin
      Self.Kept := Kept.all'Unrestricted_Access;
      Self.Room := Room.all'Unrestricted_Access;
      Self.Models := Slots.all'Unrestricted_Access;
   end Initialize;

   procedure Touch (Self : in out View_Model) is
   begin
      Touch (Self.Kept.all);
   end Touch;

   procedure Reload_Links (Self : in out View_Model) is
   begin
      Load_Links (Self.Kept.all, Self.Link_Set);
      if Link_Number (Self, Self.Chosen) = 0 then
         Self.Chosen := 0;
      end if;
      Parts.Bump (Self.Joined);
   end Reload_Links;

   procedure Enter (Self : in out View_Model) is
      Found : Items.Info_List;
   begin
      Load (Self.Kept.all, Found);
      if Found.Count > 0 then
         Make_Room (Self.Room.all, Found.Count);
      end if;
      for I in 1 .. Found.Count loop
         Models.Assign
           (Self.Models.all (I), Found (I), Stored_Content (Self.Kept.all, Found (I).Key),
            Shown_File (Self.Kept.all, Found (I)));
         if Found (I).Kind = Items.Source then
            declare
               Kept : Items.Marks.Mark_List;
            begin
               Load_Marks (Self.Kept.all, Found (I).Key, Kept);
               Models.Set_Marks (Self.Models.all (I), Kept);
            end;
         end if;
      end loop;
      Self.Entered := True;
      Self.Last_Made := 0;
      Self.Chosen := 0;
      Self.From := 0;
      Self.Moving := False;
      Reload_Links (Self);
      Parts.Bump (Self.Shown);
   end Enter;

   procedure Leave (Self : in out View_Model) is
   begin
      for Each in 1 .. Self.Models.Count loop
         if Models.Is_Assigned (Self.Models.all (Each)) then
            Models.Release (Self.Models.all (Each));
         end if;
      end loop;
      Self.Entered := False;
      Self.Last_Made := 0;
      Self.Chosen := 0;
      Self.From := 0;
      Self.Moving := False;
      Self.Link_Set.Count := 0;
      Parts.Bump (Self.Joined);
      Parts.Bump (Self.Shown);
   end Leave;

   procedure Set_Camera (Self : in out View_Model; To : Items.Models.Camera) is
   begin
      if To /= Self.Looking then
         Self.Looking := To;
         Parts.Bump (Self.Looks);
      end if;
   end Set_Camera;

   procedure Set_Viewport (Self : in out View_Model; Width, Height : Float) is
   begin
      Self.Width := Width;
      Self.Height := Height;
   end Set_Viewport;

   procedure Ask (Self : in out View_Model; To : Steer) is
   begin
      Self.Asked := To;
      Parts.Bump (Self.Asks);
   end Ask;

   procedure Centre_On (Self : in out View_Model; X, Y : Float) is
   begin
      Ask (Self, (Zoom => 0.0, Centre_X => X, Centre_Y => Y));
   end Centre_On;

   procedure Centre_On_Items (Self : in out View_Model) is
      Any : Boolean := False;
      Left, Top, Right, Bottom : Float := 0.0;
   begin
      for Each in 1 .. Self.Models.Count loop
         if Models.Is_Assigned (Self.Models.all (Each))
           and then Models.Details (Self.Models.all (Each)).State = Items.Open
         then
            declare
               Where : constant Items.Frame := Models.Details (Self.Models.all (Each)).Where;
            begin
               if Any then
                  Left   := Float'Min (Left, Where.Left);
                  Top    := Float'Min (Top, Where.Top);
                  Right  := Float'Max (Right, Where.Left + Where.Width);
                  Bottom := Float'Max (Bottom, Where.Top + Where.Height);
               else
                  Any    := True;
                  Left   := Where.Left;
                  Top    := Where.Top;
                  Right  := Where.Left + Where.Width;
                  Bottom := Where.Top + Where.Height;
               end if;
            end;
         end if;
      end loop;
      if Any then
         pragma Assert (Right >= Left and then Bottom >= Top);
         Centre_On (Self, (Left + Right) / 2.0, (Top + Bottom) / 2.0);
      end if;
   end Centre_On_Items;

   procedure Restore_View (Self : in out View_Model; Found : out Boolean) is
      Zoom, X, Y : Float;
   begin
      Get_View (Self.Kept.all, Found, Zoom, X, Y);
      if Found then
         Ask (Self, (Zoom => Zoom, Centre_X => X, Centre_Y => Y));
      end if;
   end Restore_View;

   procedure Save_View (Self : in out View_Model) is
   begin
      if Self.Entered and then Self.Width > 0.0 then
         Set_View (Self.Kept.all, Self.Looking.Zoom, Middle (Self, True), Middle (Self, False));
      end if;
   end Save_View;

   procedure Add (Self : in out View_Model; Name : String; Kind : Items.Kinds; Slot : out Items.Slot) is
      Before : constant Natural := Count (Self);
      Step   : constant Float := Float (Before mod Cascade_Count) * Cascade_Step;
      Wide   : constant Float := (if Kind = Items.Source then Items.Source_Width else Items.Default_Width);
      Where  : constant Items.Frame :=
        (Left   => Middle (Self, True) - Wide / 2.0 + Step,
         Top    => Middle (Self, False) - Items.Default_Height / 2.0 + Step,
         Width  => Wide,
         Height => Items.Default_Height);
      Free   : Natural := 0;
   begin
      for Which in 1 .. Self.Models.Count loop
         if Free = 0 and then not Models.Is_Assigned (Self.Models.all (Which)) then
            Free := Which;
         end if;
      end loop;
      if Free = 0 then
         --  Every one there is has an item: a place more is made.
         Make_Room (Self.Room.all, Self.Models.Count + 1);
         Free := Self.Models.Count;
      end if;
      declare
         Key : constant Items.Id := Create (Self.Kept.all, Name, Where, Kind);
      begin
         Models.Assign
           (Self.Models.all (Free),
            (Key    => Key,
             Title  => Projects.Titles.To_Text (Name),
             Where  => Where,
             State  => Items.Open,
             Kind   => Kind,
             Origin => (if Kind = Items.Source then Items.Unchosen else Items.Remote),
             others => <>),
            "");
      end;
      Slot := Free;
      Self.Last_Made := Free;
      Parts.Bump (Self.Shown);
      Touch (Self);
   end Add;

   procedure Show_As (Self : in out View_Model; Slot : Items.Slot; To : Items.States) is
   begin
      Models.Set_State (Self.Models.all (Slot), To);
      Keep_State (Self.Kept.all, Key_Of (Self, Slot), To);
      Parts.Bump (Self.Shown);
      Touch (Self);
   end Show_As;

   procedure Raise_Item (Self : in out View_Model; Slot : Items.Slot) is
   begin
      Self.Front := Slot;
      Parts.Bump (Self.Fronts);
   end Raise_Item;

   procedure Move_Item (Self : in out View_Model; Slot : Items.Slot; Across, Down : Float) is
   begin
      Models.Move (Self.Models.all (Slot), Across / Self.Looking.Zoom, Down / Self.Looking.Zoom);
   end Move_Item;

   procedure Resize_Item (Self : in out View_Model; Slot : Items.Slot; Across, Down : Float; Still : Boolean) is
   begin
      Models.Resize (Self.Models.all (Slot), Across / Self.Looking.Zoom, Down / Self.Looking.Zoom, Still);
   end Resize_Item;

   function Details_Is_Source (Self : View_Model; Slot : Items.Slot) return Boolean is
     (Models.Details (Self.Models.all (Slot)).Kind = Items.Source);

   procedure Choose_Origin (Self : in out View_Model; Slot : Items.Slot; To : Items.Origins) is
   begin
      Keep_Origin (Self.Kept.all, Key_Of (Self, Slot), To);
      Models.Set_Origin (Self.Models.all (Slot), To);
      Touch (Self);
   end Choose_Origin;

   procedure Put_Tool_Away (Self : in out View_Model; Slot : Items.Slot) is
   begin
      Models.Select_Tool (Self.Models.all (Slot), Models.Pointer);
   end Put_Tool_Away;

   procedure Flush_All (Self : in out View_Model; Now : Pomarine.Events.Milliseconds; Force : Boolean) is
      Wrote, Any : Boolean := False;
   begin
      for Each in 1 .. Self.Models.Count loop
         if Models.Is_Assigned (Self.Models.all (Each)) then
            Flush (Self.Kept.all, Self.Models.all (Each), Now, Force, Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Self);
      end if;
   end Flush_All;

   procedure Select_Link (Self : in out View_Model; Number : Natural) is
      Key : constant Items.Id := (if Number = 0 then 0 else Self.Link_Set (Number).Key);
   begin
      if Key /= Self.Chosen then
         Self.Chosen := Key;
         Parts.Bump (Self.Joined);
      end if;
   end Select_Link;

   procedure Join
     (Self : in out View_Model; From, To : Items.Slot; From_Side, To_Side : Items.Links.Sides)
   is
      Added : Boolean;
   begin
      Add_Link
        (Self.Kept.all,
         (From => Key_Of (Self, From), To => Key_Of (Self, To), From_Side => From_Side, To_Side => To_Side,
          others => <>),
         Added);
      if Added then
         Reload_Links (Self);
         Touch (Self);
      end if;
   end Join;

   procedure Begin_Link (Self : in out View_Model; From : Items.Slot; Side : Items.Links.Sides) is
   begin
      if Self.From = 0 then
         Self.From := From;
         Self.From_Side := Side;
         Self.Moving := False;
         Parts.Bump (Self.Joined);
      end if;
   end Begin_Link;

   procedure Begin_Moving_Link (Self : in out View_Model) is
      Number : constant Natural := Link_Number (Self, Self.Chosen);
      From   : constant Natural := (if Number = 0 then 0 else Slot_Of (Self, Self.Link_Set (Number).From));
   begin
      if Self.From = 0 and then From /= 0 then
         Self.From := From;
         Self.From_Side := Self.Link_Set (Number).From_Side;
         Self.Moving := True;
         Parts.Bump (Self.Joined);
      end if;
   end Begin_Moving_Link;

   procedure End_Link (Self : in out View_Model; To : Natural; Side : Items.Links.Sides) is
      Done : Boolean;
   begin
      if Self.From /= 0 and then To /= 0 and then To /= Self.From and then Is_Item (Self, To)
        and then Models.Details (Self.Models.all (To)).State = Items.Open
        and then Models.Details (Self.Models.all (Self.From)).State = Items.Open
      then
         if Self.Moving then
            if Self.Chosen /= 0 then
               Move_Link (Self.Kept.all, Self.Chosen, Key_Of (Self, To), Side, Done);
               if Done then
                  Reload_Links (Self);
                  Touch (Self);
               end if;
            end if;
         else
            Join (Self, Self.From, To, Self.From_Side, Side);
         end if;
      end if;
      if Self.From /= 0 then
         Self.From := 0;
         Self.Moving := False;
         Parts.Bump (Self.Joined);
      end if;
   end End_Link;

   procedure Restyle
     (Self   : in out View_Model;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors)
   is
      Number : constant Natural := Link_Number (Self, Self.Chosen);
   begin
      if Number = 0 then
         return;
      end if;
      declare
         Was : constant Items.Links.Link := Self.Link_Set (Number);
      begin
         if Stroke /= Was.Stroke or else Ending /= Was.Ending or else Color /= Was.Color then
            Set_Link_Style (Self.Kept.all, Was.Key, Stroke, Ending, Color);
            Reload_Links (Self);
            Touch (Self);
         end if;
      end;
   end Restyle;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      function Of_Item (Applies : not null access function (Details : Items.Info) return Boolean) return Boolean is
        (if Index = 0 then (for some Each in 1 .. Self.Models.Count =>
                              Models.Is_Assigned (Self.Models.all (Each))
                              and then Applies (Models.Details (Self.Models.all (Each))))
         else Is_Item (Self, Index) and then Applies (Models.Details (Self.Models.all (Index))));
      function Not_Open (Details : Items.Info) return Boolean is (Details.State /= Items.Open);
      function Open (Details : Items.Info) return Boolean is (Details.State = Items.Open);
      function Not_Closed (Details : Items.Info) return Boolean is (Details.State /= Items.Closed);
      function Any (Details : Items.Info) return Boolean is (Details.Key /= 0);
   begin
      return
        (case What is
            when Add_Note | Add_Source => Self.Entered,
            when Open_Item     => Self.Entered and then Of_Item (Not_Open'Access),
            when Minimize_Item => Self.Entered and then Of_Item (Open'Access),
            when Close_Item    => Self.Entered and then Of_Item (Not_Closed'Access),
            when Show_Item | Remove_Item => Self.Entered and then Of_Item (Any'Access),
            when Delete_Link   => Self.Chosen /= 0,
            when Cancel_Link   => Self.From /= 0,
            when Pick_Link     => True,
            when Set_Stroke    =>
               Self.Chosen /= 0 and then Index in 1 .. Items.Links.Strokes'Pos (Items.Links.Strokes'Last) + 1,
            when Set_Ending    =>
               Self.Chosen /= 0 and then Index in 1 .. Items.Links.Endings'Pos (Items.Links.Endings'Last) + 1,
            when Set_Color     => Self.Chosen /= 0 and then Index in Items.Links.Link_Colors);
   end Can_Execute;

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      Slot : Items.Slot;
   begin
      case What is
         when Add_Note =>
            Add (Self, Untitled, Items.Note, Slot);
         when Add_Source =>
            Add (Self, Untitled_Source, Items.Source, Slot);
         when Open_Item =>
            Show_As (Self, Index, Items.Open);
         when Minimize_Item =>
            Show_As (Self, Index, Items.Minimized);
         when Close_Item =>
            Show_As (Self, Index, Items.Closed);
         when Show_Item =>
            declare
               Where : constant Items.Frame := Models.Details (Self.Models.all (Index)).Where;
            begin
               if Models.Details (Self.Models.all (Index)).State /= Items.Open then
                  Show_As (Self, Index, Items.Open);
               end if;
               Centre_On (Self, Where.Left + Where.Width / 2.0, Where.Top + Where.Height / 2.0);
               Raise_Item (Self, Index);
            end;
         when Remove_Item =>
            Delete (Self.Kept.all, Key_Of (Self, Index));
            Models.Release (Self.Models.all (Index));
            Reload_Links (Self);
            Parts.Bump (Self.Shown);
            Touch (Self);
         when Delete_Link =>
            Delete_Link (Self.Kept.all, Self.Chosen);
            Reload_Links (Self);
            Touch (Self);
         when Cancel_Link =>
            Self.From := 0;
            Self.Moving := False;
            Parts.Bump (Self.Joined);
         when Pick_Link =>
            Select_Link (Self, (if Index <= Self.Link_Set.Count then Index else 0));
         when Set_Stroke | Set_Ending | Set_Color =>
            declare
               Was : constant Items.Links.Link := Link_At (Self, Link_Number (Self, Self.Chosen));
            begin
               Restyle
                 (Self,
                  (if What = Set_Stroke then Items.Links.Strokes'Val (Index - 1) else Was.Stroke),
                  (if What = Set_Ending then Items.Links.Endings'Val (Index - 1) else Was.Ending),
                  (if What = Set_Color then Index else Was.Color));
            end;
      end case;
   end Execute;

end Canvas_VM;
