package body UI.Widgets.Editors is

   package Docs renames Texts.Documents;

   Icon_Size : constant Float := 12.0;
   Icon_Room : constant Float := 18.0;
   --  In points: of the icon before a single line, and the room it is in.

   use type Docs.Version;

   procedure Configure
     (Item    : in out Editor;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0) is
   begin
      Text_Areas.Configure (Item.Text, Family, Size, Measure, Spacing);
   end Configure;

   function Is_Configured (Item : Editor) return Boolean is
     (Text_Areas.Is_Configured (Item.Text));

   procedure Set_Shared
     (Item   : in out Editor;
      Shared : not null Shared_Access) is
   begin
      Text_Areas.Set_Shared (Item.Text, Shared);
   end Set_Shared;

   procedure Attach
     (Item : in out Editor; Doc : not null Texts.Documents.Document_Access) is
   begin
      Text_Areas.Attach (Item.Text, Doc);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Attach;

   function Has_Document (Item : Editor) return Boolean is
     (Text_Areas.Is_Attached (Item.Text));

   function Zoom (Item : Editor) return Float is (Item.Zoomed);

   procedure Set_Zoom (Item : in out Editor; To : Float) is
   begin
      if To /= Item.Zoomed then
         Item.Zoomed := To;
         if Is_Placed (Item) then
            --  Now, not at the next layout, which may be after an event
            --  for the text.
            Placed (Item, Left_Of (Item), Top_Of (Item), Width_Of (Item),
                    Height_Of (Item));
            Invalidate (Item);
         end if;
      end if;
   end Set_Zoom;

   procedure Set_Invalid (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Invalid then
         Item.Invalid := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Invalid;

   function Is_Invalid (Item : Editor) return Boolean is (Item.Invalid);

   procedure Set_Enabled (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         if Is_Attached (Item) then
            if not To and then Has_Focus (Item) then
               Release_Focus (Item);
            end if;
            Invalidate (Item);
         end if;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Editor) return Boolean is (Item.Enabled);

   procedure Set_Placeholder (Item : in out Editor; Text : String) is
   begin
      Item.Hint_Length := Text'Length;
      Item.Hint (1 .. Text'Length) := Text;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Placeholder;

   procedure Set_Icon (Item : in out Editor; To : UI.Icons.Icon) is
   begin
      Item.Iconed := True;
      Item.Which := To;
      Text_Areas.Set_Lead (Item.Text, Icon_Room);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Icon;

   procedure Clear_Icon (Item : in out Editor) is
   begin
      if Item.Iconed then
         Item.Iconed := False;
         Text_Areas.Set_Lead (Item.Text, 0.0);
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Icon;

   function Is_Focused (Item : Editor) return Boolean is
     (Text_Areas.Is_Focused (Item.Text));

   procedure Caret_Box
     (Item : in out Editor;
      X, Y, Width, Height : out Float) is
   begin
      Text_Areas.Caret_Box (Item.Text, X, Y, Width, Height);
   end Caret_Box;

   function Area (Item : in out Editor)
      return not null access UI.Text_Areas.Text_Area is
     (Item.Text'Unchecked_Access);

   overriding procedure Placed
     (Item : in out Editor; Left, Top, Width, Height : Float) is
   begin
      pragma Assert
        (Is_Configured (Item), "an editor must be configured to be placed");
      --  Hidden, it has no room: it keeps where it was, rather than be
      --  wrapped to nothing and then wrapped again.
      if Width > 0.0 and then Height > 0.0 then
         Text_Areas.Place
           (Item.Text, Left, Top, Width, Height,
            Density => Density (Item), Zoom => Item.Zoomed);
      end if;
   end Placed;

   procedure Set_Paper (Item : in out Editor; To : Themes.Color) is
   begin
      Item.Has_Paper := True;
      Item.Paper := To;
      Invalidate (Item);
   end Set_Paper;

   overriding procedure Draw
     (Item   : in out Editor;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme) is
   begin
      if Has_Document (Item) then
         --  Of the lines, only those the part to draw touches.
         declare
            Part  : constant Pixel_Box := Painting_Part (Item);
            Paper : constant Themes.Color :=
              (if not Item.Enabled then Colors.Tint
               elsif Item.Has_Paper then Item.Paper
               else Themes.White);
            Shown : constant Themes.Theme :=
              (Colors with delta
                 Background => Paper,
                 Foreground =>
                   (if Item.Enabled then Colors.Foreground
                    else Themes.Quiet (Colors)),
                 Border     =>
                   (if Item.Invalid then Colors.Danger else Colors.Border));
            Faint : constant Themes.Color :=
              Themes.Mix (Colors.Foreground, Paper, 0.55);
            Pixels : constant Float := Density (Item);
         begin
            Text_Areas.Draw
              (Item.Text, Target, Shown, Is_Settled (Item),
               Rows_From => Float (Part.Top),
               Rows_To   => Float (Part.Top + Part.Height));
            if Item.Hint_Length > 0 and then Text_Lines (Item) /= null
              and then Docs.Count (Text_Areas.Document (Item.Text).all) = 1
              and then Docs.Length (Text_Areas.Document (Item.Text).all, 1)
                       = 0
            then
               UI.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, Faint,
                  Item.Hint (1 .. Item.Hint_Length),
                  Text_Areas.Line_Left (Item.Text),
                  Text_Areas.Line_Middle (Item.Text),
                  Pixels * Item.Zoomed);
            end if;
            if Item.Iconed and then Icon_Library (Item) /= null then
               declare
                  Size  : constant Positive :=
                    Positive (Float'Rounding (Icon_Size * Pixels));
                  Drawn : Boolean;
               begin
                  UI.Icons.Draw
                    (Icon_Library (Item).all, Target, Item.Which, Faint,
                     Float'Rounding
                       (Text_Areas.Lead_Left (Item.Text)
                        + (Icon_Room - Icon_Size) / 2.0 * Pixels),
                     Float'Rounding
                       (Text_Areas.Line_Middle (Item.Text)
                        - Float (Size) / 2.0),
                     Size, Drawn);
               end;
            end if;
         end;
         Item.Shown := Docs.Current (Text_Areas.Document (Item.Text).all);
         Item.Shown_Serial :=
           Docs.Serial (Text_Areas.Document (Item.Text).all);
      end if;
   end Draw;

   overriding procedure Handle
     (Item    : in out Editor;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Has_Document (Item) and then Item.Enabled then
         Text_Areas.Handle (Item.Text, Event, Clipboard (Item).all, Handled);
         declare
            Changed : Boolean;
         begin
            Text_Areas.Take_Bar_Change (Item.Text, Changed);
            if Handled or else Changed then
               Invalidate (Item);
            end if;
         end;
         --  Escape, for one, leaves it unfocused.
         if Has_Focus (Item) and then not Is_Focused (Item) then
            Release_Focus (Item);
         end if;
      end if;
   end Handle;

   overriding procedure Update
     (Item : in out Editor; Now : SDL3.Events.Milliseconds)
   is
      Blinked : Boolean;
   begin
      if not Has_Document (Item) then
         return;
      end if;
      Text_Areas.Tick (Item.Text, Now, Blinked);
      if Blinked then
         --  Only the caret changes.
         declare
            X, Y, Wide, High : Float;
         begin
            Text_Areas.Caret_Box (Item.Text, X, Y, Wide, High);
            Invalidate
              (Item,
               (Left   => Integer (Float'Floor (X)) - 1,
                Top    => Integer (Float'Floor (Y)) - 1,
                Width  => Integer (Float'Ceiling (Wide)) + 3,
                Height => Integer (Float'Ceiling (High)) + 3));
         end;
      end if;
      --  The document may have been changed from elsewhere.
      declare
         Doc : constant Docs.Document_Access :=
           Text_Areas.Document (Item.Text);
      begin
         if Docs.Current (Doc.all) /= Item.Shown
           or else Docs.Serial (Doc.all) /= Item.Shown_Serial
         then
            Invalidate (Item);
         end if;
      end;
   end Update;

   overriding function Until_Update (Item : Editor) return Integer is
     (if Has_Document (Item) and then Is_Focused (Item)
      then Integer (Text_Areas.Until_Blink (Item.Text)) else -1);

   overriding function Accepts_Focus (Item : Editor) return Boolean is
     (Has_Document (Item) and then Item.Enabled);

   overriding procedure Hover_Changed
     (Item : in out Editor; Hovered : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Hovered (Item.Text, Hovered);
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding procedure Focus_Changed
     (Item : in out Editor; Focused : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Focus (Item.Text, Focused);
         Invalidate (Item);
      end if;
   end Focus_Changed;

end UI.Widgets.Editors;
