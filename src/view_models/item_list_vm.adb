package body Item_List_VM is
   use type Items.Id;
   use type Items.States;
   use type Projects.Titles.Text;

   procedure Initialize
     (Self : in out View_Model;
      Canvas : not null access Canvas_VM.View_Model;
      Models : not null access Items.Models.Tables.Table;
      View : not null access Surface'Class) is
   begin
      Self.Canvas := Canvas_Access (Canvas);
      Self.Models := Models_Access (Models);
      Self.View := Surface_Access (View);
   end Initialize;

   procedure Refresh (Self : in out View_Model) is
      Order : Canvas_VM.Slot_Lists.List;
      Changed : Boolean := False;
   begin
      Canvas_VM.Order (Self.Canvas.all, Order);
      Changed := Order.Count /= Self.Listed.Count;
      Rows.Resize (Self.Listed, Order.Count, (1, 0, Projects.Titles.Null_Text, False));
      for Row in 1 .. Order.Count loop
         declare
            Info : constant Items.Info := Items.Models.Details (Self.Models (Order (Row)));
            Fresh : constant Row_Info := (Order (Row), Info.Key, Info.Title, Info.State = Items.Closed);
         begin
            if Self.Listed (Row) /= Fresh then
               Self.Listed (Row) := Fresh;
               Changed := True;
            end if;
         end;
      end loop;
      if Changed then
         Parts.Bump (Self.Changes);
      end if;
   end Refresh;

   function Count (Self : View_Model) return Natural is (Self.Listed.Count);
   function Slot_Of (Self : View_Model; Row : Positive) return Items.Slot is (Self.Listed (Row).Slot);
   function Title (Self : View_Model; Row : Positive) return String is
     (if Projects.Titles.Length (Self.Listed (Row).Title) = 0 then "(untitled)"
      else Projects.Titles.To_String (Self.Listed (Row).Title));
   function Is_Closed (Self : View_Model; Row : Positive) return Boolean is (Self.Listed (Row).Closed);
   overriding function Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Changes));

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      pragma Unreferenced (What);
   begin
      if Index = 0 then
         for Row in 1 .. Count (Self) loop
            if Can_Execute (Self, Reveal, Row) then
               return True;
            end if;
         end loop;
         return False;
      end if;
      return Index <= Count (Self)
        and then Canvas_VM.Is_Item (Self.Canvas.all, Slot_Of (Self, Index))
        and then Items.Models.Details (Self.Models (Slot_Of (Self, Index))).Key = Self.Listed (Index).Key;
   end Can_Execute;

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      Row : Natural := Index;
      Action : Canvas_VM.Command;
   begin
      if Row = 0 then
         Row := 1;
         while not Can_Execute (Self, What, Row) loop
            Row := Row + 1;
         end loop;
      end if;
      Action := (case What is
                    when Reveal => Canvas_VM.Show_Item,
                    when Remove => Canvas_VM.Remove_Item,
                    when Toggle_Shown =>
                      (if Items.Models.Details (Self.Models (Slot_Of (Self, Row))).State = Items.Closed
                       then Canvas_VM.Open_Item else Canvas_VM.Close_Item));
      Apply (Self.View.all, Action, Slot_Of (Self, Row));
      Refresh (Self);
   end Execute;
end Item_List_VM;
