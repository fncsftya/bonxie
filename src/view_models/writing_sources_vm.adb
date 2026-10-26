with Pomarine.Text_Areas;
with Projects;

package body Writing_Sources_VM is
   use type Items.Origins;
   use type Nav_VM.Modes;
   use type Items.Kinds;
   use type Items.Id;
   use type Parts.Version_Number;
   procedure Initialize
     (Self : in out View_Model; Navigation : not null access Nav_VM.View_Model;
      Models : not null access Items.Models.Tables.Table; Surface : not null access Effects'Class) is
   begin
      Self.Navigation := Navigation.all'Unrestricted_Access;
      Self.Models := Models.all'Unrestricted_Access;
      Self.Surface := Surface.all'Unrestricted_Access;
   end Initialize;
   function Count (Self : View_Model) return Natural is (Self.Rows.Count);
   function Slot_At (Self : View_Model; Row : Positive) return Items.Slot is (Self.Rows (Row).Slot);
   function Row_Of (Self : View_Model; Slot : Items.Slot) return Natural is
   begin
      for Row in 1 .. Count (Self) loop
         if Self.Rows (Row).Slot = Slot then
            return Row;
         end if;
      end loop;
      return 0;
   end Row_Of;
   function Is_Source (Self : View_Model; Slot : Items.Slot) return Boolean is
     (Slot <= Self.Models.Count and then Items.Models.Is_Assigned (Self.Models (Slot))
      and then Items.Models.Details (Self.Models (Slot)).Kind = Items.Source);
   function Can_Add (Self : View_Model; Slot : Items.Slot) return Boolean is
     (Is_Source (Self, Slot) and then Row_Of (Self, Slot) = 0);
   procedure Add (Self : in out View_Model; Slot : Items.Slot) is
   begin
      Self.Rows.Append ((Slot, Items.Models.Details (Self.Models (Slot)).Key));
      Parts.Bump (Self.Changes);
   end Add;
   procedure Remove (Self : in out View_Model; Slot : Items.Slot) is
      Row : constant Natural := Row_Of (Self, Slot);
   begin
      if Row /= 0 then
         Self.Rows.Delete (Row);
         Parts.Bump (Self.Changes);
      end if;
   end Remove;
   procedure Reset (Self : in out View_Model) is
   begin
      if Count (Self) /= 0 then
         Self.Rows.Clear;
         Parts.Bump (Self.Changes);
      end if;
   end Reset;
   procedure Offer_Links
     (Self : View_Model; Offer : not null access procedure (Title, Address : String)) is
   begin
      for Row in 1 .. Count (Self) loop
         declare
            Kept : Items.Models.Item renames Self.Models (Slot_At (Self, Row));
         begin
            if Is_Source (Self, Slot_At (Self, Row)) and then Items.Models.Details (Kept).Origin = Items.Remote
              and then Pomarine.Text_Areas.Is_Address (Items.Models.Text (Kept))
            then
               Offer (Projects.Titles.To_String (Items.Models.Details (Kept).Title), Items.Models.Text (Kept));
            end if;
         end;
      end loop;
   end Offer_Links;
   overriding function Version (Self : View_Model) return Parts.Version_Number is
     (Parts.Value (Self.Changes) + Nav_VM.Version (Self.Navigation.all));
   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      pragma Unreferenced (What);
   begin
      return Nav_VM.Takes_Gestures (Self.Navigation.all) and then Nav_VM.Mode (Self.Navigation.all) = Nav_VM.Write
        and then Index in 1 .. Count (Self) and then Is_Source (Self, Slot_At (Self, Index))
        and then Items.Models.Details (Self.Models (Slot_At (Self, Index))).Key = Self.Rows (Index).Key;
   end Can_Execute;
   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (What);
   begin
      Toggle_Source (Self.Surface.all, Slot_At (Self, Index));
   end Execute;
end Writing_Sources_VM;
