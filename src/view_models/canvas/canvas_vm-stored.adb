with Items.Records;
with Items.Sources;

package body Canvas_VM.Stored is

   procedure Open (Self : in out Project_Kept; Store : not null access Projects.Store) is
   begin
      Self.Store := Store.all'Unrestricted_Access;
   end Open;

   procedure Set_Project (Self : in out Project_Kept; Which : Projects.Id) is
   begin
      Self.Current := Which;
   end Set_Project;

   function Project (Self : Project_Kept) return Projects.Id is (Self.Current);

   overriding procedure Load (Self : in out Project_Kept; Into : out Items.Info_List) is
   begin
      Items.Records.Load (Self.Store.all, Self.Current, Into);
   end Load;

   overriding function Create
     (Self : in out Project_Kept; Name : String; Where : Items.Frame; Kind : Items.Kinds) return Items.Id is
     (Items.Records.Create (Self.Store.all, Self.Current, Name, Where, Kind => Kind));

   overriding function Stored_Content (Self : in out Project_Kept; Key : Items.Id) return String is
     (Items.Records.Stored_Content (Self.Store.all, Key));

   overriding function Shown_File (Self : in out Project_Kept; Of_Item : Items.Info) return String is
     (Items.Sources.Shown_File (Self.Store.all, Self.Current, Of_Item));

   overriding procedure Load_Marks
     (Self : in out Project_Kept; Key : Items.Id; Into : out Items.Marks.Mark_List) is
   begin
      Items.Marks.Load_Marks (Self.Store.all, Key, Into);
   end Load_Marks;

   overriding procedure Keep_State (Self : in out Project_Kept; Key : Items.Id; To : Items.States) is
   begin
      Items.Records.Set_State (Self.Store.all, Key, To);
   end Keep_State;

   overriding procedure Keep_Origin (Self : in out Project_Kept; Key : Items.Id; To : Items.Origins) is
   begin
      Items.Sources.Set_Origin (Self.Store.all, Key, To);
   end Keep_Origin;

   overriding procedure Delete (Self : in out Project_Kept; Key : Items.Id) is
   begin
      Items.Records.Delete (Self.Store.all, Key);
   end Delete;

   overriding procedure Flush
     (Self  : in out Project_Kept;
      Model : in out Items.Models.Item;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean) is
   begin
      Items.Models.Flush (Model, Self.Store.all, Now, Force, Wrote);
   end Flush;

   overriding procedure Touch (Self : in out Project_Kept) is
   begin
      Projects.Touch (Self.Store.all, Self.Current);
   end Touch;

   overriding procedure Get_View
     (Self : in out Project_Kept; Found : out Boolean; Zoom, Centre_X, Centre_Y : out Float) is
   begin
      Projects.Get_View (Self.Store.all, Self.Current, Found, Zoom, Centre_X, Centre_Y);
   end Get_View;

   overriding procedure Set_View (Self : in out Project_Kept; Zoom, Centre_X, Centre_Y : Float) is
   begin
      Projects.Set_View (Self.Store.all, Self.Current, Zoom, Centre_X, Centre_Y);
   end Set_View;

   overriding procedure Load_Links (Self : in out Project_Kept; Into : out Items.Links.Link_List) is
   begin
      Items.Links.Load_Links (Self.Store.all, Self.Current, Into);
   end Load_Links;

   overriding procedure Add_Link (Self : in out Project_Kept; Fresh : Items.Links.Link; Added : out Boolean) is
   begin
      Items.Links.Add_Link (Self.Store.all, Fresh, Added);
   end Add_Link;

   overriding procedure Move_Link
     (Self : in out Project_Kept; Key : Items.Id; To : Items.Id; Side : Items.Links.Sides; Moved : out Boolean) is
   begin
      Items.Links.Move_Link (Self.Store.all, Key, To, Side, Moved);
   end Move_Link;

   overriding procedure Delete_Link (Self : in out Project_Kept; Key : Items.Id) is
   begin
      Items.Links.Delete_Link (Self.Store.all, Key);
   end Delete_Link;

   overriding procedure Set_Link_Style
     (Self   : in out Project_Kept;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors) is
   begin
      Items.Links.Set_Link_Style (Self.Store.all, Key, Stroke, Ending, Color);
   end Set_Link_Style;

end Canvas_VM.Stored;
