with UI.Widgets;
with UI.Widgets.Canvases;

package body Viewer.Canvas_Items is

   package Widgets renames UI.Widgets;
   package Canvases renames UI.Widgets.Canvases;
   package Windows renames Items.Windows;

   use type Items.States;
   use type Items.Id;

   Cascade_Step  : constant Float := 24.0;
   Cascade_Count : constant := 6;
   --  Each new item is put this far down and right of the last, for so
   --  many, so that they are not all on top of each other.

   function Count (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Count;

   procedure Order
     (Item : Session; Slots : out Slot_List; Found : out Natural) is
   begin
      Found := 0;
      Slots := [others => Items.Slot'First];
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            --  Inserted among those before it by when they were made,
            --  which the ids give.
            declare
               Key : constant Items.Id :=
                 Windows.Details (Item.Windows (Which)).Key;
               At_Index : Natural := Found;
            begin
               while At_Index >= 1
                 and then Windows.Details
                            (Item.Windows
                               (Slots (Slots'First + At_Index - 1))).Key > Key
               loop
                  Slots (Slots'First + At_Index) :=
                    Slots (Slots'First + At_Index - 1);
                  At_Index := At_Index - 1;
               end loop;
               Slots (Slots'First + At_Index) := Which;
               Found := Found + 1;
            end;
         end if;
      end loop;
   end Order;

   procedure Show_Dock (Item : in out Session);
   --  Show the dock if any item is minimised.

   procedure Show_Dock (Item : in out Session) is
      Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Minimized
         then
            Any := True;
         end if;
      end loop;
      if Any /= Widgets.Is_Visible (Item.Dock_Panel) then
         Widgets.Set_Visible (Item.Dock_Panel, Any);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Show_Dock;

   procedure Place_All (Item : in out Session);
   --  Put every window where the canvas has them.

   procedure Place_All (Item : in out Session) is
   begin
      Item.Shown_Zoom := Canvases.Zoom (Item.Canvas_View);
      Item.Shown_X := Canvases.Origin_X (Item.Canvas_View);
      Item.Shown_Y := Canvases.Origin_Y (Item.Canvas_View);
      for Each of Item.Windows loop
         Windows.Place (Each, Item.Shown_Zoom, Item.Shown_X, Item.Shown_Y);
      end loop;
   end Place_All;

   procedure Touch (Item : in out Session);
   --  Say the project has been changed, so that it is listed first.

   procedure Touch (Item : in out Session) is
   begin
      Projects.Touch (Item.Store, Item.Current);
   end Touch;

   procedure Centre_On (Item : in out Session; X, Y : Float);
   --  Pan so that the canvas point X, Y is in the middle of the view.

   procedure Centre_On (Item : in out Session; X, Y : Float) is
      View   : UI.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Zoom   : constant Float := Canvases.Zoom (View);
   begin
      Canvases.Pan_By
        (View,
         Widgets.Width_Of (View) / Pixels / 2.0
           - (Canvases.Origin_X (View) + X * Zoom),
         Widgets.Height_Of (View) / Pixels / 2.0
           - (Canvases.Origin_Y (View) + Y * Zoom));
   end Centre_On;

   procedure Centre_On_Visible (Item : in out Session);
   --  Centre the view on the middle of the bounding box of the windows
   --  that are open, if there are any.

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

   procedure Enter (Item : in out Session) is
      Found : Items.Info_List;
   begin
      Items.Load (Item.Store, Item.Current, Found);
      for I in 1 .. Found.Count loop
         Windows.Assign
           (Item.Windows (I), Found.Items (I),
            Items.Content (Item.Store, Found.Items (I).Key));
      end loop;
      Centre_On_Visible (Item);
      Place_All (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Enter;

   procedure Save_All (Item : in out Session) is
      Wrote, Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Store, 0, Force => True, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Item);
      end if;
   end Save_All;

   procedure Leave (Item : in out Session) is
   begin
      Save_All (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Release (Each);
         end if;
      end loop;
      Widgets.Set_Visible (Item.Dock_Panel, False);
   end Leave;

   procedure Add (Item : in out Session; Name : String := Untitled) is
      View   : UI.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Made   : constant Natural := Count (Item);
      Step   : constant Float :=
        Float (Made mod Cascade_Count) * Cascade_Step;
      Middle_X : constant Float :=
        Canvases.To_Canvas_X (View, Widgets.Width_Of (View) / Pixels / 2.0);
      Middle_Y : constant Float :=
        Canvases.To_Canvas_Y (View, Widgets.Height_Of (View) / Pixels / 2.0);
      Where  : constant Items.Frame :=
        (Left   => Middle_X - Items.Default_Width / 2.0 + Step,
         Top    => Middle_Y - Items.Default_Height / 2.0 + Step,
         Width  => Items.Default_Width,
         Height => Items.Default_Height);
      Free   : Natural := 0;
   begin
      for Which in Items.Slot loop
         if Free = 0 and then not Windows.Is_Assigned (Item.Windows (Which))
         then
            Free := Which;
         end if;
      end loop;
      if Free = 0 then
         return;
      end if;
      declare
         Key : constant Items.Id :=
           Items.Create (Item.Store, Item.Current, Name, Where);
      begin
         Windows.Assign
           (Item.Windows (Free),
            (Key   => Key,
             Title => Projects.Titles.To_Bounded_String (Name),
             Where => Where,
             State => Items.Open),
            "");
         Windows.Place
           (Item.Windows (Free),
            Canvases.Zoom (View), Canvases.Origin_X (View),
            Canvases.Origin_Y (View));
         Touch (Item);
         Widgets.Layout (Item.Widgets, Item.Target);
         Windows.Focus_Text (Item.Windows (Free));
      end;
   end Add;

   procedure Set_State
     (Item : in out Session; Which : Items.Slot; To : Items.States) is
   begin
      Windows.Set_State (Item.Windows (Which), To);
      Items.Set_State
        (Item.Store, Windows.Details (Item.Windows (Which)).Key, To);
      Windows.Place
        (Item.Windows (Which),
         Item.Shown_Zoom, Item.Shown_X, Item.Shown_Y);
      Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Set_State;

   procedure Reveal (Item : in out Session; Which : Items.Slot) is
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
   begin
      if Windows.Details (Item.Windows (Which)).State /= Items.Open then
         Set_State (Item, Which, Items.Open);
      end if;
      Centre_On (Item, Where.Left + Where.Width / 2.0,
                 Where.Top + Where.Height / 2.0);
      Windows.Bring_To_Front (Item.Windows (Which));
      Sync (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Reveal;

   procedure Remove (Item : in out Session; Which : Items.Slot) is
   begin
      Items.Delete
        (Item.Store, Windows.Details (Item.Windows (Which)).Key);
      Windows.Release (Item.Windows (Which));
      Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Remove;

   procedure Take (Item : in out Session) is
      Action : Windows.Actions;
   begin
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            Windows.Poll (Item.Windows (Which), Action);
            case Action is
               when Windows.None =>
                  null;
               when Windows.Minimize =>
                  Set_State (Item, Which, Items.Minimized);
               when Windows.Restore =>
                  Set_State (Item, Which, Items.Open);
               when Windows.Close =>
                  Set_State (Item, Which, Items.Closed);
            end case;
         end if;
      end loop;
   end Take;

   procedure Sync (Item : in out Session) is
   begin
      if Canvases.Zoom (Item.Canvas_View) /= Item.Shown_Zoom
        or else Canvases.Origin_X (Item.Canvas_View) /= Item.Shown_X
        or else Canvases.Origin_Y (Item.Canvas_View) /= Item.Shown_Y
      then
         Place_All (Item);
      end if;
   end Sync;

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Wrote, Any : Boolean := False;
   begin
      Sync (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Store, Now, Force => False, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Item);
      end if;
   end Update;

end Viewer.Canvas_Items;
