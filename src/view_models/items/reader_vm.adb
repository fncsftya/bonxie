with Items.Sources;

package body Reader_VM is
   use type Items.Models.Tools;

   procedure Initialize (Self : in out Model; Reading : not null access Engine'Class) is
   begin
      Self.Reading := Reading.all'Unrestricted_Access;
      Poll (Self);
   end Initialize;

   procedure Poll (Self : in out Model) is
      Open   : constant Boolean := Self.Reading /= null and then Is_Open (Self.Reading.all);
      Scale  : constant Float := (if Self.Reading = null then 1.0 else Zoom (Self.Reading.all));
      Chosen : constant Items.Models.Tools :=
        (if Self.Reading = null then Items.Models.Pointer else Tool (Self.Reading.all));
   begin
      if Open /= Self.Seen_Open or else Chosen /= Self.Seen_Tool or else Scale /= Self.Seen_Zoom then
         Self.Seen_Zoom := Scale;
         Self.Seen_Open := Open;
         Self.Seen_Tool := Chosen;
         Parts.Bump (Self.Changes);
      end if;
   end Poll;

   overriding
   function Version (Self : Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes));
   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (Index = 0 and then Self.Reading /= null and then Is_Open (Self.Reading.all));

   overriding
   procedure Execute (Self : in out Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Use_Pointer                       =>
            Select_Tool (Self.Reading.all, Items.Models.Pointer);

         when Use_Marker                        =>
            Select_Tool (Self.Reading.all, Items.Models.Highlighter);

         when Use_Eraser                        =>
            Select_Tool (Self.Reading.all, Items.Models.Eraser);

         when Toggle_Pin | Visit | Close_Reader =>
            Requested (Self.Reading.all, What);
      end case;
      Poll (Self);
   end Execute;

   function Zoom_Fraction (Self : Model) return Float
   is (Items.Sources.To_Slider (if Self.Reading = null then 1.0 else Zoom (Self.Reading.all)));

   procedure Set_Zoom_Fraction (Self : in out Model; Value : Float) is
   begin
      if Self.Reading /= null and then Is_Open (Self.Reading.all) then
         Set_Zoom (Self.Reading.all, Items.Sources.From_Slider (Value));
         Poll (Self);
      end if;
   end Set_Zoom_Fraction;

   function Pointer_Selected (Self : Model) return Boolean
   is (Self.Reading = null or else Tool (Self.Reading.all) = Items.Models.Pointer);
   function Marker_Selected (Self : Model) return Boolean
   is (Self.Reading /= null and then Tool (Self.Reading.all) = Items.Models.Highlighter);
   function Eraser_Selected (Self : Model) return Boolean
   is (Self.Reading /= null and then Tool (Self.Reading.all) = Items.Models.Eraser);
end Reader_VM;
