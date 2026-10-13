package body UI.Widgets.Pictures is

   package Textures renames SDL3.Windows.Renderers.Textures;

   use type SDL3.Events.Event_Kind;

   function File_Name (Item : Picture) return String is
     (Item.Name (1 .. Item.Length));

   function Has_Picture (Item : Picture) return Boolean is (Item.Loaded);

   function Has_Failed (Item : Picture) return Boolean is (Item.Failed);

   function Scrolled (Item : Picture) return Float is (Item.Down);

   function Zoom (Item : Picture) return Float is (Item.Zoomed);

   procedure Set_Zoom (Item : in out Picture; To : Float) is
   begin
      if To /= Item.Zoomed then
         Item.Zoomed := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Zoom;

   procedure Set_File (Item : in out Picture; Path : String) is
   begin
      Item.Length := Path'Length;
      Item.Name (1 .. Item.Length) := Path;
      Item.Loaded := False;
      Item.Failed := False;
      Item.Down := 0.0;
      Item.Across := 0.0;
      Item.Fitted := 0.0;
      Textures.Release (Item.Pixels);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_File;

   procedure Unload (Item : in out Picture) is
   begin
      Textures.Release (Item.Pixels);
      Item.Loaded := False;
      Item.Failed := False;
   end Unload;

   function Furthest (Item : Picture; High : Float) return Float is
     (if High > 0.0 and then Item.Fitted > High
      then 1.0 - High / Item.Fitted else 0.0);
   --  The most Down can be, for a box High pixels high, so that the
   --  picture's end is at the box's.

   procedure Scroll_To (Item : in out Picture; To : Float) is
      Wanted : constant Float :=
        Float'Min (To, Furthest (Item, Height_Of (Item)));
   begin
      if Wanted /= Item.Down then
         Item.Down := Wanted;
         Invalidate (Item);
      end if;
   end Scroll_To;

   overriding procedure Draw
     (Item   : in out Picture;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Box  : constant Float := Width_Of (Item);
      Wide : constant Float := Box * Item.Zoomed;
   begin
      SDL3.Windows.Renderers.Fill_Rect
        (Target, Themes.Mix (Colors.Background, Colors.Foreground, 0.08),
         Left_Of (Item), Top_Of (Item), Box, Height_Of (Item));
      if Item.Length = 0 or else Item.Failed then
         return;
      end if;
      if not Item.Loaded then
         begin
            Textures.Create_From_PNG (Item.Pixels, Target, File_Name (Item));
            Item.Loaded := True;
         exception
            when others =>
               Item.Failed := True;
               return;
         end;
      end if;
      Item.Fitted :=
        Wide * Float (Textures.Height (Item.Pixels))
          / Float (Textures.Width (Item.Pixels));
      Item.Down :=
        Float'Min (Item.Down, Furthest (Item, Height_Of (Item)));
      Item.Across := Float'Min (Item.Across, 1.0);
      Textures.Draw_Scaled
        (Target, Item.Pixels,
         Left_Of (Item) - Item.Across * Float'Max (0.0, Wide - Box),
         Top_Of (Item) - Item.Down * Item.Fitted,
         Wide, Item.Fitted);
   end Draw;

   overriding procedure Handle
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Event.Kind = SDL3.Events.Mouse_Wheel and then Item.Fitted > 0.0 then
         if Item.Zoomed > 1.0 and then Event.Wheel_X /= 0.0 then
            Item.Across :=
              Float'Min
                (1.0,
                 Float'Max
                   (0.0,
                    Item.Across
                    - Event.Wheel_X * Points_Per_Notch * Density (Item)
                      / (Width_Of (Item) * (Item.Zoomed - 1.0))));
            Invalidate (Item);
         end if;
         Scroll_To
           (Item,
            Float'Min
              (1.0,
               Float'Max
                 (0.0,
                  Item.Down
                  - Event.Wheel_Y * Points_Per_Notch * Density (Item)
                    / Item.Fitted)));
         Handled := True;
      end if;
   end Handle;

end UI.Widgets.Pictures;
