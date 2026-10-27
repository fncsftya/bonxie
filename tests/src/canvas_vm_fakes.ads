with Canvas_VM;
with Items.Links;
with Items.Marks;
with Items.Models;
with Items.Models.Tables;
with Pomarine.Events;

--  What a test of the canvas's view-model has in place of the database and the windows: items kept in memory, which say
--  how they were handled, and a surface that makes room.

package Canvas_VM_Fakes is

   type Kept_Item is record
      Info    : Items.Info;
      Content : Natural := 0;
   end record;

   type Item_Array is array (1 .. 30) of Kept_Item;

   type Few is limited new Canvas_VM.Library with record
      Table                    : Item_Array;
      Last                     : Natural := 0;
      Next_Key                 : Items.Id := 1;
      Links                    : Items.Links.Link_List;
      Next_Link                : Items.Id := 1;
      Touched                  : Natural := 0;
      --  How many times the project was said to be changed.
      Flushed                  : Natural := 0;
      --  How many items were asked to write.
      Saved_View               : Boolean := False;
      Zoom, Centre_X, Centre_Y : Float := 0.0;
   end record;

   procedure Add (Self : in out Few; Title : String; Kind : Items.Kinds; Where : Items.Frame);
   --  An item the project already had.

   function Keys (Self : Few) return String;
   --  The keys of the items there are, in order, apart by commas.

   function State_Of (Self : Few; Key : Items.Id) return Items.States;

   overriding
   procedure Load (Self : in out Few; Into : out Items.Info_List);
   overriding
   function Create (Self : in out Few; Name : String; Where : Items.Frame; Kind : Items.Kinds) return Items.Id;
   overriding
   function Stored_Content (Self : in out Few; Key : Items.Id) return String;
   overriding
   function Shown_File (Self : in out Few; Of_Item : Items.Info) return String;
   overriding
   procedure Load_Marks (Self : in out Few; Key : Items.Id; Into : out Items.Marks.Mark_List);
   overriding
   procedure Keep_State (Self : in out Few; Key : Items.Id; To : Items.States);
   overriding
   procedure Keep_Origin (Self : in out Few; Key : Items.Id; To : Items.Origins);
   overriding
   procedure Delete (Self : in out Few; Key : Items.Id);
   overriding
   procedure Flush
     (Self  : in out Few;
      Model : in out Items.Models.Item;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean);
   overriding
   procedure Touch (Self : in out Few);
   overriding
   procedure Get_View (Self : in out Few; Found : out Boolean; Zoom, Centre_X, Centre_Y : out Float);
   overriding
   procedure Set_View (Self : in out Few; Zoom, Centre_X, Centre_Y : Float);
   overriding
   procedure Load_Links (Self : in out Few; Into : out Items.Links.Link_List);
   overriding
   procedure Add_Link (Self : in out Few; Fresh : Items.Links.Link; Added : out Boolean);
   overriding
   procedure Move_Link
     (Self : in out Few; Key : Items.Id; To : Items.Id; Side : Items.Links.Sides; Moved : out Boolean);
   overriding
   procedure Delete_Link (Self : in out Few; Key : Items.Id);
   overriding
   procedure Set_Link_Style
     (Self   : in out Few;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors);

   type Room is limited new Canvas_VM.Surface with record
      Models : access Items.Models.Tables.Table;
      Made   : Natural := 0;
      --  How many times room was made.
   end record;

   overriding
   procedure Make_Room (Self : in out Room; Slots : Positive);

end Canvas_VM_Fakes;
