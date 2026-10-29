with Browser_Hosts;
with Browser_UI;
with Browser_VM;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.UI;
with Pomarine.UI.Menus;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Embeds.Callbacks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with SDL3.Cursors;
with SDL3.Windows.Renderers;
with System;
with SDL3.Windows;
with Settings_VM;
with Site_Filter_VM;
with View.Canvas_Items;
with Pomarine.View_Models;
with View.Navigation;

package body View.Browsers is

   package Widgets renames Pomarine.Widgets;
   package Embeds renames Pomarine.Widgets.Embeds;
   package Buttons renames Pomarine.Widgets.Buttons;
   package UI renames Pomarine.UI;
   package Themes renames Pomarine.Themes;
   package Controls renames Browser_UI.Controls;
   package Layouts renames Pomarine.Widgets.Layouts;

   use type Browser_VM.Capture_States;

   Address_Shortcut : constant := 1;
   Toggle_Shortcut  : constant := 2;
   --  Command with L and with G, kept for the program while the page has the keyboard.

   procedure Asked (Self : in out Session; Source : in out Embeds.Embed'Class; Which : Positive);
   --  The page kept a shortcut: L selects the address to be typed over, G puts the pane away.

   package Hearing is new Embeds.Callbacks (Session);

   Edge_Width : constant Float := 6.0;
   Tool_Side  : constant Float := 31.0;
   Tray_Pad   : constant Float := 8.0;
   --  Points: how tall the address, the buttons beside it and those of the tray all are, and the tray's padding.
   --  Points wide the strip at the pane's edge is.

   package Dragging is new Widgets.Callbacks (Session);

   procedure Set_Width (Item : in out Session; To : Float);
   --  Make the pane To points wide, within what the window leaves.

   procedure Set_Width (Item : in out Session; To : Float) is
      Content : Widgets.Widget'Class renames Content_Panel (Item).all;
      Most    : constant Float :=
        Float'Max
          (View_Parts.Browser.Least_Width,
           Widgets.Width_Of (Content) / Widgets.Density (Content) - View_Parts.Browser.Room_Left);
      Wide    : constant Float := Float'Min (Most, Float'Max (View_Parts.Browser.Least_Width, To));
   begin
      if Wide /= Item.Browser.Wide then
         Item.Browser.Wide := Wide;
         Widgets.Layouts.Set_Layout (Item.Browser.Pane, Width => Widgets.Layouts.Length_Of (Wide));
      end if;
   end Set_Width;

   procedure Dragged (Self : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The edge was dragged: the pane is as much wider as it went left.

   procedure Dragged (Self : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
   begin
      Set_Width (Self, Self.Browser.Wide - Event.Across);
   end Dragged;

   procedure Focus_Address (Item : in out Session);
   --  Give the address field the keyboard, with its text selected.

   procedure Focus_Address (Item : in out Session) is
   begin
      if Has_Screen (Item, Browser_Region) then
         declare
            Field : Widgets.Widget'Class renames UI.Named (Screen_Of (Item, Browser_Region).all, "Address").all;
         begin
            if Widgets.Is_Showing (Field) then
               Widgets.Focus (Field);
               Pomarine.Text_Areas.Select_All (Widgets.Editors.Editor'Class (Field).Area.all);
            end if;
         end;
      end if;
   end Focus_Address;

   procedure Asked (Self : in out Session; Source : in out Embeds.Embed'Class; Which : Positive) is
      pragma Unreferenced (Source);
   begin
      case Which is
         when Address_Shortcut =>
            Focus_Address (Self);

         when Toggle_Shortcut  =>
            Navigation.Do_Command (Self, Nav_VM.Toggle_Browser);

         when others           =>
            null;
      end case;
   end Asked;

   function Host_Of (Address : String) return String;
   --  The site an address is of, as it is written: without its scheme, or what follows the site's name.

   function Host_Of (Address : String) return String is
      Start : Natural := Address'First;
      Stop  : Natural := Address'Last;
   begin
      for I in Address'First .. Address'Last - 2 loop
         if Address (I .. I + 2) = "://" then
            Start := I + 3;
            exit;
         end if;
      end loop;
      for I in Start .. Address'Last loop
         if Address (I) in '/' | '?' | '#' then
            Stop := I - 1;
            exit;
         end if;
      end loop;
      return Address (Start .. Stop);
   end Host_Of;

   function Slot_Of (Colour : Natural) return Themes.Slot
   is (Themes.Fixed
         ((Red   => SDL3.Windows.Renderers.Color_Component (Colour / 65536),
           Green => SDL3.Windows.Renderers.Color_Component (Colour / 256 mod 256),
           Blue  => SDL3.Windows.Renderers.Color_Component (Colour mod 256),
           Alpha => 255)));

   Card_Width  : constant Float := 164.0;
   Card_Height : constant Float := 78.0;
   Card_Pad    : constant Float := 10.0;
   --  In points.

   package Clicking is new Widgets.Callbacks (Session);

   procedure Card_Clicked (Self : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A favourite was clicked: it is gone to.

   procedure Show_Page_Or_Start (Item : in out Session);
   --  The page is shown once an address has been gone to; until then the place to start is.

   procedure Card_Clicked (Self : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Event);
      use type System.Address;
   begin
      for Row in 1 .. Natural (Self.Browser.Pool.Length) loop
         if Self.Browser.Pool (Row).Whole'Address = Source'Address
           and then Browser_VM.Can_Execute (Self.Browser.Model, Browser_VM.Open_Favourite, Row)
         then
            Browser_VM.Execute (Self.Browser.Model, Browser_VM.Open_Favourite, Row);
            Show_Page_Or_Start (Self);
            return;
         end if;
      end loop;
   end Card_Clicked;

   procedure Add_Card (Item : in out Session);
   --  Make a card for one more favourite than there were.

   procedure Add_Card (Item : in out Session) is
      Parts : View_Parts.Browser.Browser_Choices renames Item.Browser;
      Made  : constant View_Parts.Browser.Card_Access := new View_Parts.Browser.Card;
      Pad   : constant Layouts.Length := Layouts.Length_Of (Card_Pad);
   begin
      Parts.Pool.Append (Made);
      Layouts.Add
        (Parts.Cards,
         Made.Whole,
         (Width    => Layouts.Length_Of (Card_Width),
          Height   => Layouts.Length_Of (Card_Height),
          Shrink   => 0.0,
          Flow     => Layouts.Column,
          Padding  => (others => Pad),
          Outlined => Layouts.On,
          Shadowed => Layouts.On,
          Gap      => Layouts.Length_Of (2.0),
          others   => <>));
      Layouts.Add (Made.Whole, Made.Name, (Height => Layouts.Length_Of (20.0), Shrink => 0.0, others => <>));
      Layouts.Add (Made.Whole, Made.Site, (Height => Layouts.Length_Of (16.0), Shrink => 0.0, others => <>));
      Widgets.Grips.Set_Border (Made.Whole, Themes.Border);
      Widgets.Grips.Set_Shadow (Made.Whole, Themes.Shadow);
      Widgets.Grips.Set_Radius (Made.Whole, Themes.Large_Radius);
      Widgets.Grips.Set_Hover_Outline (Made.Whole, Themes.Accent);
      Widgets.Grips.Set_Wanted_Cursor (Made.Whole, SDL3.Cursors.Pointer);
      Widgets.Grips.Set_Focusable (Made.Whole, True);
      Widgets.Labels.Set_Style (Made.Name, Pomarine.Line_Texts.Strong);
      Clicking.On (Made.Whole, Widgets.Click, Item'Unrestricted_Access, Card_Clicked'Access);
   end Add_Card;

   procedure Show_Favourites (Item : in out Session);
   --  The cards say the favourites there are now: made if more are wanted, the rest hidden.

   procedure Show_Favourites (Item : in out Session) is
      Parts : View_Parts.Browser.Browser_Choices renames Item.Browser;
      Count : constant Natural := Browser_VM.Favourite_Count (Parts.Model);
   begin
      while Natural (Parts.Pool.Length) < Count loop
         Add_Card (Item);
      end loop;
      Widgets.Labels.Set_Text (Parts.Start, (if Count = 0 then "Enter an address to start browsing" else "Favourites"));
      for Row in 1 .. Natural (Parts.Pool.Length) loop
         declare
            Card : View_Parts.Browser.Card renames Parts.Pool (Row).all;
         begin
            Widgets.Set_Visible (Card.Whole, Row <= Count);
            if Row <= Count then
               declare
                  Colour  : constant Natural := Browser_VM.Favourite_Colour (Parts.Model, Row);
                  Red     : constant Natural := Colour / 65536;
                  Green   : constant Natural := Colour / 256 mod 256;
                  Blue    : constant Natural := Colour mod 256;
                  Dark    : constant Boolean := (299 * Red + 587 * Green + 114 * Blue) < 140_000;
                  Ink     : constant Themes.Slot := Slot_Of (if Dark then 16#FFFFFF# else 16#202020#);
                  Address : constant String := Browser_VM.Favourite_Address (Parts.Model, Row);
               begin
                  Widgets.Grips.Set_Fill (Card.Whole, Slot_Of (Colour));
                  Widgets.Labels.Set_Ink (Card.Name, Ink);
                  Widgets.Labels.Set_Ink (Card.Site, Ink);
                  Widgets.Labels.Set_Text (Card.Name, Browser_VM.Favourite_Title (Parts.Model, Row));
                  Widgets.Labels.Set_Text (Card.Site, Host_Of (Address));
                  Widgets.Set_Accessible_Name (Card.Whole, "Open " & Browser_VM.Favourite_Title (Parts.Model, Row));
               end;
            end if;
         end;
      end loop;
   end Show_Favourites;

   procedure Capture_Clicked (Self : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Event);
      Button : Buttons.Button renames Buttons.Button (Source);
   begin
      if Buttons.Caret_Clicked (Button) then
         Widgets.Set_Visible (Self.Browser.Capture_Menu, not Widgets.Is_Visible (Self.Browser.Capture_Menu));
         Embeds.Set_Covered (Self.Browser.Page, Widgets.Is_Visible (Self.Browser.Capture_Menu));
         Widgets.Raise_To_Front (Self.Browser.Capture_Menu);
      elsif Browser_VM.Can_Execute (Self.Browser.Model, Browser_VM.Capture) then
         Widgets.Set_Visible (Self.Browser.Capture_Menu, False);
         Embeds.Set_Covered (Self.Browser.Page, False);
         Browser_VM.Execute (Self.Browser.Model, Browser_VM.Capture);
      end if;
   end Capture_Clicked;

   procedure Capture_Chosen (Self : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      What : constant Browser_VM.Command := (if Event.Row = 1 then Browser_VM.Capture else Browser_VM.Capture_View);
   begin
      Widgets.Set_Visible (Self.Browser.Capture_Menu, False);
      Embeds.Set_Covered (Self.Browser.Page, False);
      if Event.Row in 1 .. 2 and then Browser_VM.Can_Execute (Self.Browser.Model, What) then
         Browser_VM.Execute (Self.Browser.Model, What);
      end if;
   end Capture_Chosen;

   procedure Build (Item : in out Session) is
      Parts : View_Parts.Browser.Browser_Choices renames Item.Browser;
   begin
      Browser_VM.Initialize
        (Parts.Model, Parts.Live'Unrestricted_Access, Settings_VM.Config_Directory (Item.Choices.Model));
      Browser_Hosts.Hold_Back (Site_Filter_VM.Rules (Item.Choices.Filter));
      if Item.Shell.Windowed then
         Browser_Hosts.Attach (SDL3.Windows.Native_Handle (Item.Host.Win));
         Browser_Hosts.Keep ('l', Address_Shortcut);
         Browser_Hosts.Keep ('g', Toggle_Shortcut);
      end if;
      Parts.Host.Typing_In := Item.Host.Win'Unrestricted_Access;
      Embeds.Set_Host (Parts.Page, Parts.Host'Unrestricted_Access);
      Hearing.On_Shortcut (Parts.Page, Item'Unrestricted_Access, Asked'Access);
      Widgets.Panels.Set_Fill (Parts.Pane, Themes.Page);
      Widgets.Panels.Set_Border (Parts.Pane, Themes.Border);
      Widgets.Grips.Set_Fill (Parts.Edge, Themes.Border);
      Widgets.Grips.Set_Hover_Fill (Parts.Edge, Themes.Accent);
      Widgets.Grips.Set_Wanted_Cursor (Parts.Edge, SDL3.Cursors.Resize_Across);
      Dragging.On (Parts.Edge, Widgets.Drag, Item'Unrestricted_Access, Dragged'Access);
      Widgets.Labels.Set_Text (Parts.Start, "Enter an address to start browsing");
      Widgets.Labels.Set_Style (Parts.Start, Pomarine.Line_Texts.Strong);
      Widgets.Labels.Set_Ink (Parts.Start, Themes.Muted);
      Open_Screen (Item, Browser_Region);
      declare
         Form  : UI.View renames Screen_Of (Item, Browser_Region).all;
         Bound : constant Controls.Context'Class := Controls.Bind (Form, Parts.Model'Unrestricted_Access);
         Back  : constant UI.Button_Handle :=
           Bound.Button
             (Widgets.Buttons.Looks ("Back", Icon => Pomarine.Icons.Shown (Icon_Set.Back), Focusable => True),
              Browser_VM.Back);
         Ahead : constant UI.Button_Handle :=
           Bound.Button
             (Widgets.Buttons.Looks ("Forward", Icon => Pomarine.Icons.Shown (Icon_Set.Forward), Focusable => True),
              Browser_VM.Forward);
         House : constant UI.Button_Handle :=
           Bound.Button
             (Widgets.Buttons.Looks ("Home", Icon => Pomarine.Icons.Shown (Icon_Set.Home), Focusable => True),
              Browser_VM.Home);
         Again : constant UI.Button_Handle :=
           Bound.Button
             (Widgets.Buttons.Looks ("Reload", Icon => Pomarine.Icons.Shown (Icon_Set.Refresh), Focusable => True),
              Browser_VM.Reload);
         Star  : constant UI.Button_Handle :=
           Bound.Button
             (Widgets.Buttons.Looks ("Favourite", Icon => Pomarine.Icons.Shown (Icon_Set.Star), Focusable => True),
              Browser_VM.Favourite);

         function Tool (Made : UI.Button_Handle; Wide : Float := Tool_Side) return UI.Layout
         is (UI.Place
               (Made,
                Width  => Layouts.Length_Of (Wide),
                Height => Layouts.Length_Of (Tool_Side),
                Shrink => 0.0,
                Exact  => True));

         Bar    : constant UI.Layout :=
           UI.Row
             ([Tool (Back),
               Tool (Ahead),
               Tool (House),
               UI.Called
                 (Bound.Text_Field
                    (Browser_UI.Address,
                     Browser_VM.Go,
                     Placeholder => "Address",
                     Name        => "Address",
                     Grow        => 1.0,
                     Height      => Layouts.Length_Of (Tool_Side)),
                  "Address"),
               Tool (Again)],
              Gap     => 6.0,
              Padding => 8.0,
              Align   => Layouts.Center);
         Foot   : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Parts.Tray,
                 [Bound.Label (Browser_UI.Status, Ink => Themes.Muted, Grow => 1.0),
                  Tool (Star),
                  UI.Styled
                    (UI.Put (Form, Parts.Capture_Button),
                     (Width => 125.0, Height => Layouts.Length_Of (Tool_Side), Shrink => 0.0, others => <>))]),
              (Height  => Layouts.Length_Of (Tool_Side + 2.0 * Tray_Pad),
               Shrink  => 0.0,
               Flow    => Layouts.Row,
               Align   => Layouts.Center,
               Gap     => Layouts.Length_Of (6.0),
               Padding => (others => Layouts.Length_Of (Tray_Pad)),
               others  => <>));
         Home   : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Parts.Home,
                 [UI.Styled
                    (UI.Put (Form, Parts.Start), (Height => Layouts.Length_Of (22.0), Shrink => 0.0, others => <>)),
                  UI.Styled
                    (UI.Put (Form, Parts.Cards),
                     (Grow   => 1.0,
                      Flow   => Layouts.Row,
                      Wrap   => Layouts.On,
                      Gap    => Layouts.Length_Of (10.0),
                      others => <>))]),
              (Grow    => 1.0,
               Flow    => Layouts.Column,
               Gap     => Layouts.Length_Of (10.0),
               Padding => (others => Layouts.Length_Of (14.0)),
               others  => <>));
         Inside : constant UI.Layout :=
           UI.Column
             ([Bar,
               Home,
               Bound.Borrow_Widget (Parts.Page, Name => "Page", Grow => 1.0),
               Foot,
               UI.Styled
                 (UI.Put (Form, Parts.Capture_Menu),
                  (Place    => Layouts.Absolute,
                   Width    => 190.0,
                   Position => (Right => 8.0, Bottom => 47.0, others => <>),
                   others   => <>))],
              Grow => 1.0);
         Whole  : constant UI.Layout :=
           UI.Row
             ([UI.Styled
                 (UI.Put (Form, Parts.Edge),
                  (Width => Widgets.Layouts.Length_Of (Edge_Width), Shrink => 0.0, others => <>)),
               Inside],
              Align => Widgets.Layouts.Stretch,
              Grow  => 1.0);
      begin
         Parts.Star := Star;
         UI.Mount_Into (Form, Parts.Pane, Whole);
      end;
      Buttons.Configure
        (Parts.Capture_Button, Buttons.Looks ("Capture Page", Captioned => True, Shape => Buttons.Split_Dropdown));
      Pomarine.UI.Menus.Set_Content
        (Parts.Capture_Menu,
         [Pomarine.UI.Menus.Row (Widgets.Menus.Action, "Capture Page"),
          Pomarine.UI.Menus.Row (Widgets.Menus.Action, "Capture Current View")]);
      Widgets.Menus.Set_Keyboard (Parts.Capture_Menu, True);
      Clicking.On (Parts.Capture_Button, Widgets.Click, Item'Unrestricted_Access, Capture_Clicked'Access);
      Clicking.On (Parts.Capture_Menu, Widgets.Choose, Item'Unrestricted_Access, Capture_Chosen'Access);
      Widgets.Set_Visible (Parts.Capture_Menu, False);
      Widgets.Set_Visible (Parts.Page, False);
      Widgets.Set_Visible (Parts.Pane, False);
      Widgets.Panels.Set_Fill (Parts.Tray, Themes.Strip);
      Show_Favourites (Item);
   end Build;

   --  The page is shown once an address has been gone to; until then the place to start is.
   procedure Show_Page_Or_Start (Item : in out Session) is
      Started : constant Boolean := Browser_VM.Has_Started (Item.Browser.Model);
   begin
      if Widgets.Is_Visible (Item.Browser.Page) /= Started then
         Widgets.Set_Visible (Item.Browser.Page, Started);
         Widgets.Set_Visible (Item.Browser.Home, not Started);
      end if;
   end Show_Page_Or_Start;

   procedure Sync (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
      Shown : constant Boolean := Nav_VM.Browser_Shown (Model);
   begin
      Embeds.Set_Covered
        (Item.Browser.Page, Nav_VM.Is_Over (Model) or else Widgets.Is_Visible (Item.Browser.Capture_Menu));
      Buttons.Set_Selected (Tab_Of (Item, Item.Toolbar.Browser_Tab).all, Nav_VM.Browser_Open (Model));
      if Widgets.Is_Visible (Item.Browser.Pane) /= Shown then
         Widgets.Set_Visible (Item.Browser.Pane, Shown);
         if Shown then
            Widgets.Raise_To_Front (Item.Browser.Pane);
            Show_Page_Or_Start (Item);
            if not Browser_VM.Has_Started (Item.Browser.Model) then
               Focus_Address (Item);
            end if;
         end if;
      end if;
   end Sync;

   procedure Show_Star (Item : in out Session);
   --  The star is filled in while the page is a favourite, and an outline while it is not.

   procedure Show_Star (Item : in out Session) is
      Marked : constant Boolean := Browser_VM.Is_Favourite (Item.Browser.Model);
   begin
      if Marked /= Item.Browser.Starred then
         Item.Browser.Starred := Marked;
         Widgets.Buttons.Configure
           (Widgets.Buttons.Button'Class (UI.Widget_Of (Screen_Of (Item, Browser_Region).all, Item.Browser.Star).all),
            Widgets.Buttons.Looks
              ("Favourite",
               Icon      => Pomarine.Icons.Shown (if Marked then Icon_Set.Star_Filled else Icon_Set.Star),
               Focusable => True));
      end if;
   end Show_Star;

   procedure Keep_Capture (Item : in out Session);
   --  The page was captured: make a source of it, called as the page was.

   procedure Keep_Capture (Item : in out Session) is
      Model : Browser_VM.Model renames Item.Browser.Model;
      Added : Boolean;
   begin
      Canvas_Items.Add_Found_Source
        (Item,
         0,
         Browser_VM.Capture_Title (Model),
         Browser_VM.Capture_Address (Model),
         Browser_VM.Capture_File (Model),
         Added);
      Browser_VM.Finish_Capture (Model);
   end Keep_Capture;

   procedure Update (Item : in out Session) is
   begin
      if Has_Screen (Item, Browser_Region) and then Widgets.Is_Visible (Item.Browser.Pane) then
         --  The window may have been made smaller than the pane.
         Set_Width (Item, Item.Browser.Wide);
         Browser_VM.Refresh (Item.Browser.Model);
         if Pomarine.View_Models.Changed
              (Item.Browser.Seen_Favourites, Browser_VM.Favourites_Version (Item.Browser.Model))
         then
            Show_Favourites (Item);
         end if;
         if Browser_VM.Capture_State (Item.Browser.Model) = Browser_VM.Done then
            Keep_Capture (Item);
         end if;
         Show_Page_Or_Start (Item);
         Buttons.Set_Enabled
           (Item.Browser.Capture_Button, Browser_VM.Can_Execute (Item.Browser.Model, Browser_VM.Capture));
         Show_Star (Item);
         Sync_Screen (Item, Browser_Region);
      end if;
   end Update;

   procedure Open (Item : in out Session; Address : String) is
   begin
      if Address = "" then
         return;
      end if;
      if not Nav_VM.Browser_Open (Item.Nav_Model.Model) then
         Navigation.Do_Command (Item, Nav_VM.Toggle_Browser);
      end if;
      Browser_VM.Set_Address_Draft (Item.Browser.Model, Address);
      if Browser_VM.Can_Execute (Item.Browser.Model, Browser_VM.Go) then
         Browser_VM.Execute (Item.Browser.Model, Browser_VM.Go);
         Show_Page_Or_Start (Item);
      end if;
   end Open;

end View.Browsers;
