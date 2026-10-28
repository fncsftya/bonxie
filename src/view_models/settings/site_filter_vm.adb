package body Site_Filter_VM is

   use type Site_Filters.Modes;

   function Base_Of_Draft (Self : Model) return String
   is (Site_Filters.Base_Of (Parts.Get (Self.Typed)));

   No_Sites : aliased Site_Filters.Lists.List;

   --  The list in use, not copied: none if the filter is off.
   function In_Use (Self : Model) return not null access constant Site_Filters.Lists.List
   is (case Self.Held.Mode is
         when Site_Filters.Off         => No_Sites'Access,
         when Site_Filters.Use_Blocked => Self.Held.Blocked'Unrestricted_Access,
         when Site_Filters.Use_Allowed => Self.Held.Allowed'Unrestricted_Access);

   overriding
   function Parts_Version (Self : Model) return Parts.Version_Number
   is (Parts.Version (Self.Typed));

   procedure Keep (Self : in out Model);
   --  Write the filter down, if it is kept at all, and say the rows changed.

   procedure Keep (Self : in out Model) is
   begin
      Self.Edits := Self.Edits + 1;
      if Strings.Length (Self.Config) > 0 then
         Site_Filters.Save (Strings.To_String (Self.Config), Self.Held);
      end if;
   end Keep;

   procedure Initialize (Self : in out Model; Config : String) is
   begin
      Self.Config := Strings.To_Unbounded_String (Config);
      if Config /= "" then
         Site_Filters.Load (Config, Self.Held);
      end if;
      Self.Choice := 0;
      Self.Edits := Self.Edits + 1;
      Mark_Changed (Self);
   end Initialize;

   function Rules (Self : Model) return Site_Filters.Rules
   is (Self.Held);

   function Mode (Self : Model) return Site_Filters.Modes
   is (Self.Held.Mode);

   function Mode_Is (Self : Model; Value : Site_Filters.Modes) return Boolean
   is (Self.Held.Mode = Value);

   function List_Shown (Self : Model) return Boolean
   is (Self.Held.Mode /= Site_Filters.Off);

   function Count (Self : Model) return Natural
   is (In_Use (Self).Count);

   function Site (Self : Model; Row : Positive) return String
   is (Strings.To_String (In_Use (Self).all (Row)));

   function Draft (Self : Model) return String
   is (Parts.Get (Self.Typed));

   procedure Set_Draft (Self : in out Model; Text : String) is
   begin
      Parts.Set (Self.Typed, Text);
   end Set_Draft;

   --  Whether the draft, as an address, is another site of the list than the chosen one.
   function Is_New (Self : Model) return Boolean is
      Found : constant Natural := Site_Filters.Index_Of (In_Use (Self).all, Base_Of_Draft (Self));
   begin
      return Found = 0 or else Found = Self.Choice;
   end Is_New;

   function Hint (Self : Model) return String
   is (if Draft (Self) = "" or else not List_Shown (Self)
       then ""
       elsif Base_Of_Draft (Self) = ""
       then "That is not a web address."
       elsif not Is_New (Self)
       then "That site is in the list already."
       else "");

   function Selected_Site (Self : Model) return Natural
   is (if Self.Choice <= Count (Self) then Self.Choice else 0);

   procedure Select_Site (Self : in out Model; Id : Natural) is
   begin
      if Self.Choice /= Id then
         --  Letting go of a site whose address is still the draft lets go of the draft: it is no new one.
         if Id = 0 and then Self.Choice in 1 .. Count (Self) and then Draft (Self) = Site (Self, Self.Choice) then
            Set_Draft (Self, "");
         end if;
         Self.Choice := Id;
         if Id > 0 then
            Set_Draft (Self, Site (Self, Id));
         end if;
         Mark_Changed (Self);
      end if;
   end Select_Site;

   function Rows (Self : in out Model) return not null access Pomarine.Models.List_Model'Class
   is (Self.Showing'Unchecked_Access);

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (case What is
         when Choose_Mode => Index <= Site_Filters.Modes'Pos (Site_Filters.Modes'Last),
         when Add_Site    =>
           Index = 0
           and then List_Shown (Self)
           and then Base_Of_Draft (Self) /= ""
           and then Site_Filters.Index_Of (In_Use (Self).all, Base_Of_Draft (Self)) = 0,
         when Change_Site =>
           Index = 0 and then Selected_Site (Self) > 0 and then Base_Of_Draft (Self) /= "" and then Is_New (Self),
         when Remove_Site => Index = 0 and then Selected_Site (Self) > 0);

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
      Now  : constant Site_Filters.Modes := Self.Held.Mode;
      Base : constant Strings.Unbounded_String := Strings.To_Unbounded_String (Base_Of_Draft (Self));

      --  The list in use, to be changed (the commands that change it are for a listed mode).
      Edited : constant access Site_Filters.Lists.List :=
        (if Now = Site_Filters.Use_Blocked
         then Self.Held.Blocked'Unrestricted_Access
         else Self.Held.Allowed'Unrestricted_Access);
   begin
      case What is
         when Choose_Mode =>
            Self.Held.Mode := Site_Filters.Modes'Val (Index);
            Self.Choice := 0;
            Parts.Set (Self.Typed, "");
            Keep (Self);

         when Add_Site    =>
            Site_Filters.Lists.Append (Edited.all, Base);
            Parts.Set (Self.Typed, "");
            Keep (Self);

         when Change_Site =>
            Edited.all (Selected_Site (Self)) := Base;
            Keep (Self);

         when Remove_Site =>
            Site_Filters.Lists.Delete (Edited.all, Selected_Site (Self));
            Self.Choice := 0;
            Parts.Set (Self.Typed, "");
            Keep (Self);
      end case;
   end Perform;

   overriding
   function Count (Self : Site_Rows) return Natural
   is (Count (Self.Owner.all));

   overriding
   function Version (Self : Site_Rows) return Natural
   is (Self.Owner.Edits);

   overriding
   function Row_Id (Self : Site_Rows; Row : Positive) return Positive
   is (Row);

   overriding
   procedure Describe_Row (Self : Site_Rows; Row : Positive; Content : out Pomarine.Models.Row_Content) is
   begin
      Pomarine.Models.Set_Text (Content, Site (Self.Owner.all, Row));
   end Describe_Row;

end Site_Filter_VM;
