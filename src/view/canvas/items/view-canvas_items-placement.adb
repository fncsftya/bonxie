with Canvas_VM;
with Pomarine.Widgets;
with Pomarine.Widgets.Canvases;
with Pomarine.View_Models;

package body View.Canvas_Items.Placement is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;

   procedure Report_Camera (Item : in out Session) is
      Pane   : Pomarine.Widgets.Canvases.Canvas renames Canvases.Canvas (Item.Canvas_View);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Canvas_VM.Set_Viewport
        (Item.Canvas_Model.Model, Widgets.Width_Of (Pane) / Pixels, Widgets.Height_Of (Pane) / Pixels);
      Canvas_VM.Set_Camera
        (Item.Canvas_Model.Model,
         (Zoom => Canvases.Zoom (Pane), Origin_X => Canvases.Origin_X (Pane), Origin_Y => Canvases.Origin_Y (Pane)));
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
      Pane   : Pomarine.Widgets.Canvases.Canvas renames Canvases.Canvas (Item.Canvas_View);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom   : constant Float := Canvases.Zoom (Pane);
   begin
      Canvases.Pan_By
        (Pane,
         Widgets.Width_Of (Pane) / Pixels / 2.0 - (Canvases.Origin_X (Pane) + X * Zoom),
         Widgets.Height_Of (Pane) / Pixels / 2.0 - (Canvases.Origin_Y (Pane) + Y * Zoom));
   end Centre_On;

   procedure Follow (Item : in out Session) is
      Pane   : Pomarine.Widgets.Canvases.Canvas renames Canvases.Canvas (Item.Canvas_View);
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
                 (Pane,
                  Float'Min (Canvases.Max_Zoom, Float'Max (Canvases.Min_Zoom, Asked.Zoom)) / Canvases.Zoom (Pane),
                  Widgets.Width_Of (Pane) / Pixels / 2.0,
                  Widgets.Height_Of (Pane) / Pixels / 2.0);
            end if;
            Centre_On (Item, Asked.Centre_X, Asked.Centre_Y);
            Report_Camera (Item);
         end;
      end if;
      if Pomarine.View_Models.Changed (Item.Canvas_Model.Seen_Camera, Canvas_VM.Camera_Version (Model)) then
         Place_All (Item);
      end if;
   end Follow;

end View.Canvas_Items.Placement;
