with Projects;

--  The items and links of a project in the database, for the canvas's view-model.
package Canvas_VM.Stored is

   type Project_Kept is limited new Library with private;

   procedure Open (Self : in out Project_Kept; Store : not null access Projects.Store);
   --  The items of the project in Store, which must be there as long as this is; Of_Project says which.

   procedure Set_Project (Self : in out Project_Kept; Which : Projects.Id);

   function Project (Self : Project_Kept) return Projects.Id;

   overriding procedure Load (Self : in out Project_Kept; Into : out Items.Info_List);

   overriding function Create
     (Self : in out Project_Kept; Name : String; Where : Items.Frame; Kind : Items.Kinds) return Items.Id;

   overriding function Stored_Content (Self : in out Project_Kept; Key : Items.Id) return String;

   overriding function Shown_File (Self : in out Project_Kept; Of_Item : Items.Info) return String;

   overriding procedure Load_Marks
     (Self : in out Project_Kept; Key : Items.Id; Into : out Items.Marks.Mark_List);

   overriding procedure Keep_State (Self : in out Project_Kept; Key : Items.Id; To : Items.States);

   overriding procedure Keep_Origin (Self : in out Project_Kept; Key : Items.Id; To : Items.Origins);

   overriding procedure Delete (Self : in out Project_Kept; Key : Items.Id);

   overriding procedure Flush
     (Self  : in out Project_Kept;
      Model : in out Items.Models.Item;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean);

   overriding procedure Touch (Self : in out Project_Kept);

   overriding procedure Get_View
     (Self : in out Project_Kept; Found : out Boolean; Zoom, Centre_X, Centre_Y : out Float);

   overriding procedure Set_View (Self : in out Project_Kept; Zoom, Centre_X, Centre_Y : Float);

   overriding procedure Load_Links (Self : in out Project_Kept; Into : out Items.Links.Link_List);

   overriding procedure Add_Link (Self : in out Project_Kept; Fresh : Items.Links.Link; Added : out Boolean);

   overriding procedure Move_Link
     (Self : in out Project_Kept; Key : Items.Id; To : Items.Id; Side : Items.Links.Sides; Moved : out Boolean);

   overriding procedure Delete_Link (Self : in out Project_Kept; Key : Items.Id);

   overriding procedure Set_Link_Style
     (Self   : in out Project_Kept;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors);

private

   type Store_Access is access all Projects.Store;

   type Project_Kept is limited new Library with record
      Store   : Store_Access;
      Current : Projects.Id := 0;
   end record;

end Canvas_VM.Stored;
