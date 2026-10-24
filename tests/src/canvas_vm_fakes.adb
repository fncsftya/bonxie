with Ada.Strings.Unbounded;
with Projects;

package body Canvas_VM_Fakes is

   use type Items.Id;
   use type Items.Kinds;

   function Place_Of (Self : Few; Key : Items.Id) return Natural is
   begin
      for Each in 1 .. Self.Last loop
         if Self.Table (Each).Info.Key = Key then
            return Each;
         end if;
      end loop;
      return 0;
   end Place_Of;

   procedure Add (Self : in out Few; Title : String; Kind : Items.Kinds; Where : Items.Frame) is
   begin
      Self.Last := Self.Last + 1;
      Self.Table (Self.Last) :=
        (Info => (Key => Self.Next_Key, Title => Projects.Titles.To_Text (Title), Where => Where, Kind => Kind,
                  State => Items.Open, others => <>),
         others => <>);
      Self.Next_Key := Self.Next_Key + 1;
   end Add;

   function Keys (Self : Few) return String is
      Said : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Each in 1 .. Self.Last loop
         if Each > 1 then
            Ada.Strings.Unbounded.Append (Said, ",");
         end if;
         Ada.Strings.Unbounded.Append (Said, Items.Id'Image (Self.Table (Each).Info.Key) (2 .. 2));
      end loop;
      return Ada.Strings.Unbounded.To_String (Said);
   end Keys;

   function State_Of (Self : Few; Key : Items.Id) return Items.States is
     (Self.Table (Place_Of (Self, Key)).Info.State);

   overriding procedure Load (Self : in out Few; Into : out Items.Info_List) is
   begin
      Into.Clear;
      for Each in 1 .. Self.Last loop
         Into.Append (Self.Table (Each).Info);
      end loop;
   end Load;

   overriding function Create
     (Self : in out Few; Name : String; Where : Items.Frame; Kind : Items.Kinds) return Items.Id
   is
      Key : constant Items.Id := Self.Next_Key;
   begin
      Add (Self, Name, Kind, Where);
      return Key;
   end Create;

   overriding function Stored_Content (Self : in out Few; Key : Items.Id) return String is
     (if Place_Of (Self, Key) = 0 then "" else "text of" & Key'Image);

   overriding function Shown_File (Self : in out Few; Of_Item : Items.Info) return String is ("");

   overriding procedure Load_Marks (Self : in out Few; Key : Items.Id; Into : out Items.Marks.Mark_List) is
   begin
      Into := (others => <>);
   end Load_Marks;

   overriding procedure Keep_State (Self : in out Few; Key : Items.Id; To : Items.States) is
   begin
      Self.Table (Place_Of (Self, Key)).Info.State := To;
   end Keep_State;

   overriding procedure Keep_Origin (Self : in out Few; Key : Items.Id; To : Items.Origins) is
   begin
      Self.Table (Place_Of (Self, Key)).Info.Origin := To;
   end Keep_Origin;

   overriding procedure Delete (Self : in out Few; Key : Items.Id) is
      Place : constant Natural := Place_Of (Self, Key);
   begin
      Self.Table (Place .. Self.Last - 1) := Self.Table (Place + 1 .. Self.Last);
      Self.Last := Self.Last - 1;
      --  Its links go with it.
      for Each in reverse 1 .. Self.Links.Count loop
         if Self.Links (Each).From = Key or else Self.Links (Each).To = Key then
            Self.Links.Data (Each .. Self.Links.Count - 1) := Self.Links.Data (Each + 1 .. Self.Links.Count);
            Self.Links.Count := Self.Links.Count - 1;
         end if;
      end loop;
   end Delete;

   overriding procedure Flush
     (Self  : in out Few;
      Model : in out Items.Models.Item;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean) is
   begin
      Self.Flushed := Self.Flushed + 1;
      Wrote := Force and then Items.Models.Details (Model).Kind = Items.Note;
   end Flush;

   overriding procedure Touch (Self : in out Few) is
   begin
      Self.Touched := Self.Touched + 1;
   end Touch;

   overriding procedure Get_View (Self : in out Few; Found : out Boolean; Zoom, Centre_X, Centre_Y : out Float) is
   begin
      Found := Self.Saved_View;
      Zoom := Self.Zoom;
      Centre_X := Self.Centre_X;
      Centre_Y := Self.Centre_Y;
   end Get_View;

   overriding procedure Set_View (Self : in out Few; Zoom, Centre_X, Centre_Y : Float) is
   begin
      Self.Saved_View := True;
      Self.Zoom := Zoom;
      Self.Centre_X := Centre_X;
      Self.Centre_Y := Centre_Y;
   end Set_View;

   overriding procedure Load_Links (Self : in out Few; Into : out Items.Links.Link_List) is
   begin
      Into := Self.Links;
   end Load_Links;

   overriding procedure Add_Link (Self : in out Few; Fresh : Items.Links.Link; Added : out Boolean) is
      Made : Items.Links.Link := Fresh;
   begin
      Added := True;
      for Each of Self.Links.Slice loop
         if (Each.From = Fresh.From and then Each.To = Fresh.To)
           or else (Each.From = Fresh.To and then Each.To = Fresh.From)
         then
            Added := False;
         end if;
      end loop;
      if Added then
         Made.Key := Self.Next_Link;
         Self.Next_Link := Self.Next_Link + 1;
         Self.Links.Append (Made);
      end if;
   end Add_Link;

   overriding procedure Move_Link
     (Self : in out Few; Key : Items.Id; To : Items.Id; Side : Items.Links.Sides; Moved : out Boolean) is
   begin
      Moved := False;
      for Each in 1 .. Self.Links.Count loop
         if Self.Links (Each).Key = Key and then Self.Links (Each).From /= To then
            Self.Links (Each).To := To;
            Self.Links (Each).To_Side := Side;
            Moved := True;
         end if;
      end loop;
   end Move_Link;

   overriding procedure Delete_Link (Self : in out Few; Key : Items.Id) is
   begin
      for Each in reverse 1 .. Self.Links.Count loop
         if Self.Links (Each).Key = Key then
            Self.Links.Data (Each .. Self.Links.Count - 1) := Self.Links.Data (Each + 1 .. Self.Links.Count);
            Self.Links.Count := Self.Links.Count - 1;
         end if;
      end loop;
   end Delete_Link;

   overriding procedure Set_Link_Style
     (Self   : in out Few;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors) is
   begin
      for Each in 1 .. Self.Links.Count loop
         if Self.Links (Each).Key = Key then
            Self.Links (Each).Stroke := Stroke;
            Self.Links (Each).Ending := Ending;
            Self.Links (Each).Color := Color;
         end if;
      end loop;
   end Set_Link_Style;

   overriding procedure Make_Room (Self : in out Room; Slots : Positive) is
   begin
      Self.Made := Self.Made + 1;
      Self.Models.Grow (Slots);
   end Make_Room;

end Canvas_VM_Fakes;
