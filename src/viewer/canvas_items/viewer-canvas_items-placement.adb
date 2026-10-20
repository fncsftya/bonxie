with Pomarine.Widgets;
with Pomarine.Widgets.Canvases;

package body Viewer.Canvas_Items.Placement is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;

   use type Items.States;
   use type Projects.Id;

   procedure Place_All (Item : in out Session) is
   begin
      Item.Nav.Shown_Zoom := Canvases.Zoom (Item.Canvas_View);
      Item.Nav.Shown_X := Canvases.Origin_X (Item.Canvas_View);
      Item.Nav.Shown_Y := Canvases.Origin_Y (Item.Canvas_View);
      for Each of Item.Windows loop
         Windows.Place (Each, Item.Nav.Shown_Zoom, Item.Nav.Shown_X,
                        Item.Nav.Shown_Y);
      end loop;
   end Place_All;

   procedure Centre_On (Item : in out Session; X, Y : Float) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
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

   procedure Centre_On_Visible (Item : in out Session) is
      Any : Boolean := False;
      Left, Top, Right, Bottom : Float := 0.0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Open
         then
            declare
               Where : constant Items.Frame := Windows.Details (Each).Where;
            begin
               if Any then
                  Left   := Float'Min (Left, Where.Left);
                  Top    := Float'Min (Top, Where.Top);
                  Right  := Float'Max (Right, Where.Left + Where.Width);
                  Bottom := Float'Max (Bottom, Where.Top + Where.Height);
               else
                  Any    := True;
                  Left   := Where.Left;
                  Top    := Where.Top;
                  Right  := Where.Left + Where.Width;
                  Bottom := Where.Top + Where.Height;
               end if;
            end;
         end if;
      end loop;
      if Any then
         pragma Assert (Right >= Left and then Bottom >= Top);
         Centre_On (Item, (Left + Right) / 2.0, (Top + Bottom) / 2.0);
      end if;
   end Centre_On_Visible;

   procedure Save_View (Item : in out Session) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Item.Opened.Current /= 0 and then Widgets.Width_Of (View) > 0.0 then
         Projects.Set_View
           (Item.Nav.Store, Item.Opened.Current, Canvases.Zoom (View),
            Canvases.To_Canvas_X
              (View, Widgets.Width_Of (View) / Pixels / 2.0),
            Canvases.To_Canvas_Y
              (View, Widgets.Height_Of (View) / Pixels / 2.0));
      end if;
   end Save_View;

   procedure Restore_View
     (Item : in out Session; Found : out Boolean)
   is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom, X, Y : Float;
   begin
      Projects.Get_View (Item.Nav.Store, Item.Opened.Current, Found, Zoom, X,
                         Y);
      if Found then
         Canvases.Zoom_By
           (View,
            Float'Min (Canvases.Max_Zoom, Float'Max (Canvases.Min_Zoom, Zoom))
              / Canvases.Zoom (View),
            Widgets.Width_Of (View) / Pixels / 2.0,
            Widgets.Height_Of (View) / Pixels / 2.0);
         Centre_On (Item, X, Y);
      end if;
   end Restore_View;

end Viewer.Canvas_Items.Placement;
