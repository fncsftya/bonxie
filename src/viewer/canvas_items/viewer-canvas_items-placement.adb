with Canvas_VM;
with Pomarine.Widgets;
with Pomarine.Widgets.Canvases;
with Pomarine.View_Models;

package body Viewer.Canvas_Items.Placement is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;

   procedure Report_Camera (Item : in out Session) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Canvases.Canvas (Item.Canvas_View);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Canvas_VM.Set_Viewport
        (Item.Canvas_Model.Model, Widgets.Width_Of (View) / Pixels, Widgets.Height_Of (View) / Pixels);
      Canvas_VM.Set_Camera
        (Item.Canvas_Model.Model,
         (Zoom => Canvases.Zoom (View), Origin_X => Canvases.Origin_X (View), Origin_Y => Canvases.Origin_Y (View)));
   end Report_Camera;

   procedure Place_All (Item : in out Session) is
   begin
      for Each of Item.Windows loop
         Windows.Place (Each);
      end loop;
   end Place_All;

   --  Pan so that the canvas point X, Y is in the middle of the view.
   procedure Centre_On (Item : in out Session; X, Y : Float);

   procedure Centre_On (Item : in out Session; X, Y : Float) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Canvases.Canvas (Item.Canvas_View);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom   : constant Float := Canvases.Zoom (View);
   begin
      Canvases.Pan_By
        (View,
         Widgets.Width_Of (View) / Pixels / 2.0
           - (Canvases.Origin_X (View) + X * Zoom),
         Widgets.Height_Of (View) / Pixels / 2.0
           - (Canvases.Origin_Y (View) + Y * Zoom));
   end Centre_On;

   procedure Follow (Item : in out Session) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Canvases.Canvas (Item.Canvas_View);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Model  : Canvas_VM.View_Model renames Item.Canvas_Model.Model;
   begin
      Report_Camera (Item);
      if Pomarine.View_Models.Changed (Item.Canvas_Model.Seen_Steering, Canvas_VM.Steering_Version (Model)) then
         declare
            Asked : constant Canvas_VM.Steer := Canvas_VM.Steering (Model);
         begin
            if Asked.Zoom /= 0.0 then
               Canvases.Zoom_By
                 (View,
                  Float'Min (Canvases.Max_Zoom, Float'Max (Canvases.Min_Zoom, Asked.Zoom)) / Canvases.Zoom (View),
                  Widgets.Width_Of (View) / Pixels / 2.0,
                  Widgets.Height_Of (View) / Pixels / 2.0);
            end if;
            Centre_On (Item, Asked.Centre_X, Asked.Centre_Y);
            Report_Camera (Item);
         end;
      end if;
      if Pomarine.View_Models.Changed (Item.Canvas_Model.Seen_Camera, Canvas_VM.Camera_Version (Model)) then
         Place_All (Item);
      end if;
   end Follow;

end Viewer.Canvas_Items.Placement;
