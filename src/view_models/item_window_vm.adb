with Items.Sources;

package body Item_Window_VM is

   use type Items.Kinds;
   use type Items.States;
   use type Items.Origins;
   use type Items.Models.Tools;

   function Current (Self : Model) return Snapshot is
   begin
      if Self.Data = null or else not Items.Models.Is_Assigned (Self.Data.all) then
         return (others => <>);
      end if;
      declare
         Info : constant Items.Info := Items.Models.Details (Self.Data.all);
      begin
         return (Assigned => True, Key => Info.Key, Kind => Info.Kind, State => Info.State,
                 Origin => Info.Origin, Page => Info.Page, Count => Info.Page_Count, Zoom => Info.Zoom,
                 Tool => Items.Models.Tool (Self.Data.all));
      end;
   end Current;

   procedure Initialize
     (Self : in out Model; Data : not null access Items.Models.Item; View : not null access Effects'Class) is
   begin
      Self.Data := Data.all'Unrestricted_Access;
      Self.View := View.all'Unrestricted_Access;
      Poll (Self);
   end Initialize;

   procedure Poll (Self : in out Model) is
      Now : constant Snapshot := Current (Self);
   begin
      if Now /= Self.Seen then
         Self.Seen := Now;
         Parts.Bump (Self.Changes);
      end if;
   end Poll;

   overriding function Version (Self : Model) return Parts.Version_Number is (Parts.Value (Self.Changes));

   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean is
      Now : constant Snapshot := Current (Self);
      Source : constant Boolean := Now.Kind = Items.Source;
   begin
      if not Now.Assigned or else Self.View = null then
         return False;
      elsif What = Close_Window then
         return Index = 0 and then Now.State in Items.Open | Items.Minimized;
      elsif What = Restore_Window then
         return Index = 0 and then Now.State = Items.Minimized;
      elsif Now.State /= Items.Open then
         return False;
      elsif What = Use_Tool then
         return Index > 0;
      elsif What = Follow_Link then
         return Index = 0;
      elsif What = Zoom_Preset then
         return Source and then Index in Preset_Index;
      elsif Index /= 0 then
         return False;
      end if;
      case What is
         when Begin_Title_Edit | Accept_Title | Minimize_Window => return True;
         when Speak | Link_To_Outline => return Now.Kind = Items.Note;
         when Previous_Page => return Source and then Now.Count > 1 and then Now.Page > 1;
         when Next_Page => return Source and then Now.Count > 1 and then Now.Page < Now.Count;
         when Choose_File => return Source and then Now.Origin /= Items.Remote;
         when others => return Source;
      end case;
   end Can_Execute;

   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Use_Pointer => Items.Models.Select_Tool (Self.Data.all, Items.Models.Pointer);
         when Use_Marker => Items.Models.Select_Tool (Self.Data.all, Items.Models.Highlighter);
         when Use_Eraser => Items.Models.Select_Tool (Self.Data.all, Items.Models.Eraser);
         when Zoom_Preset => Items.Models.Set_Zoom (Self.Data.all, Preset_Zooms (Index));
         when others => null;
      end case;
      if What not in Use_Pointer | Use_Marker | Use_Eraser then
         Requested (Self.View.all, What, Index);
      end if;
      Poll (Self);
      Changed (Self.View.all);
   end Execute;

   function Zoom_Fraction (Self : Model) return Float is
     (Items.Sources.To_Slider (Current (Self).Zoom));

   procedure Set_Zoom_Fraction (Self : in out Model; Value : Float) is
   begin
      if Can_Execute (Self, Toggle_Zoom) then
         Items.Models.Set_Zoom (Self.Data.all, Items.Sources.From_Slider (Value));
         Poll (Self);
         Changed (Self.View.all);
      end if;
   end Set_Zoom_Fraction;

   function Pointer_Selected (Self : Model) return Boolean is
     (Current (Self).Tool = Items.Models.Pointer);
   function Marker_Selected (Self : Model) return Boolean is
     (Current (Self).Tool = Items.Models.Highlighter);
   function Eraser_Selected (Self : Model) return Boolean is
     (Current (Self).Tool = Items.Models.Eraser);

end Item_Window_VM;
