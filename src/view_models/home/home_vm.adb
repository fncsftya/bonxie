with Ada.Strings.Fixed;

package body Home_VM is

   use type Parts.Version_Number;

   Middle_Dot : constant String := [Character'Val (16#C2#), Character'Val (16#B7#)];
   --  In UTF-8.

   function Count (Self : View_Model) return Natural is (Self.Listed.Count);

   function Key_Of (Self : View_Model; Row : Positive) return Projects.Id is (Self.Listed.Items (Row).Key);

   function Title (Self : View_Model; Row : Positive) return String is
     (Projects.Titles.To_String (Self.Listed.Items (Row).Title));

   function Counted (Number : Natural; One, Many : String) return String is
     (Ada.Strings.Fixed.Trim (Number'Image, Ada.Strings.Both) & " " & (if Number = 1 then One else Many));

   function Meta (Self : View_Model; Row : Positive) return String is
     (Counted (Self.Numbers (Row).Documents, "document", "documents") & " " & Middle_Dot & " "
      & Counted (Self.Numbers (Row).Sources, "source", "sources"));

   function Listed_Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Lists));

   function Editing (Self : View_Model) return Natural is (Self.Row);

   function Draft (Self : View_Model) return String is (Parts.Get (Self.Typed));

   procedure Set_Draft (Self : in out View_Model; Text : String) is
   begin
      Parts.Set (Self.Typed, Text);
   end Set_Draft;

   overriding function Version (Self : View_Model) return Parts.Version_Number is
     (Parts.Value (Self.Changes) + Parts.Value (Self.Lists) + Parts.Version (Self.Typed));

   --  The draft without the spaces about it, as First .. Last of it.
   procedure Trim (Text : String; First : out Positive; Last : out Natural) is
   begin
      First := Text'First;
      Last := Text'Last;
      while First <= Last and then Text (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Text (Last) = ' ' loop
         Last := Last - 1;
      end loop;
   end Trim;

   function Is_Something (Text : String) return Boolean is
      First : Positive;
      Last  : Natural;
   begin
      Trim (Text, First, Last);
      return Last >= First;
   end Is_Something;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
     (case What is
         when Refresh                       => True,
         when Begin_Rename =>
            (if Index = 0 then Self.Listed.Count > 0 else Index <= Self.Listed.Count),
         when Ask_Delete => Index in 1 .. Self.Listed.Count and then Self.Dialog /= null
           and then not Confirm_VM.Is_Asking (Self.Dialog.all),
         when Cancel_Rename                 => Self.Row /= 0,
         when Accept_Rename                 => Self.Row /= 0 and then Is_Something (Draft (Self)));

   procedure List (Self : in out View_Model) is
   begin
      Self.Row := 0;
      Recent (Self.Kept.all, Self.Listed);
      for Each in 1 .. Self.Listed.Count loop
         Count_Items (Self.Kept.all, Self.Listed.Items (Each).Key,
                      Self.Numbers (Each).Documents, Self.Numbers (Each).Sources);
      end loop;
      Parts.Bump (Self.Lists);
   end List;

   procedure Initialize
     (Self : in out View_Model; Kept : not null access Library'Class;
      Dialog : access Confirm_VM.View_Model := null) is
   begin
      Self.Kept := Kept.all'Unrestricted_Access;
      Self.Dialog := (if Dialog = null then null else Dialog.all'Unrestricted_Access);
      List (Self);
   end Initialize;

   procedure Observe (Self : in out View_Model; Reactions : access Effects'Class) is
   begin
      Self.Reactions := (if Reactions = null then null else Reactions.all'Unrestricted_Access);
   end Observe;

   procedure Delete_Confirmed (Self : in out View_Model; Key : Projects.Id) is
   begin
      Delete (Self.Kept.all, Key);
      List (Self);
      if Self.Reactions /= null then
         Self.Reactions.Home_Changed;
      end if;
   end Delete_Confirmed;

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Refresh =>
            List (Self);
            Parts.Set (Self.Typed, "");
         when Begin_Rename =>
            if Index not in 1 .. Self.Listed.Count then
               raise Constraint_Error with "no such row" & Index'Image;
            end if;
            Self.Row := Index;
            Parts.Set (Self.Typed, Title (Self, Index));
            Parts.Bump (Self.Changes);
         when Cancel_Rename =>
            Self.Row := 0;
            Parts.Bump (Self.Changes);
         when Accept_Rename =>
            declare
               Text  : constant String := Draft (Self);
               First : Positive;
               Last  : Natural;
            begin
               Trim (Text, First, Last);
               Rename (Self.Kept.all, Key_Of (Self, Self.Row), Text (First .. Last));
            end;
            List (Self);
         when Ask_Delete =>
            if Self.Row /= 0 then
               Self.Row := 0;
               Parts.Bump (Self.Changes);
            end if;
            Confirm_VM.Ask_Project (Self.Dialog.all, Key_Of (Self, Index), Title (Self, Index));
      end case;
      if Self.Reactions /= null then
         Self.Reactions.Home_Changed;
      end if;
   end Execute;

end Home_VM;
