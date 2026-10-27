with Browser_Hosts;
with Browser_UI;
with Browser_VM;
with Pomarine.Text_Areas;
with Pomarine.Themes;
with Pomarine.UI;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Embeds.Callbacks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with SDL3.Cursors;
with SDL3.Windows;
with View.Navigation;

package body View.Browsers is

   package Widgets renames Pomarine.Widgets;
   package Embeds renames Pomarine.Widgets.Embeds;
   package Buttons renames Pomarine.Widgets.Buttons;
   package UI renames Pomarine.UI;
   package Themes renames Pomarine.Themes;
   package Controls renames Browser_UI.Controls;

   Address_Shortcut : constant := 1;
   Toggle_Shortcut  : constant := 2;
   --  Command with L and with G, kept for the program while the page has the keyboard.

   procedure Asked (Self : in out Session; Source : in out Embeds.Embed'Class; Which : Positive);
   --  The page kept a shortcut: L selects the address to be typed over, G puts the pane away.

   package Hearing is new Embeds.Callbacks (Session);

   Edge_Width : constant Float := 6.0;
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

   procedure Build (Item : in out Session) is
      Parts : View_Parts.Browser.Browser_Choices renames Item.Browser;
   begin
      Browser_VM.Initialize (Parts.Model, Parts.Live'Unrestricted_Access);
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
      Widgets.Labels.Set_Centered (Parts.Start, True);
      Widgets.Labels.Set_Ink (Parts.Start, Themes.Muted);
      Open_Screen (Item, Browser_Region);
      declare
         Form   : UI.View renames Screen_Of (Item, Browser_Region).all;
         Bound  : constant Controls.Context'Class := Controls.Bind (Form, Parts.Model'Unrestricted_Access);
         Bar    : constant UI.Layout :=
           UI.Row
             ([Bound.Button ("Reload", Browser_VM.Reload, Width => 64.0),
               UI.Called
                 (Bound.Text_Field
                    (Browser_UI.Address, Browser_VM.Go, Placeholder => "Address", Name => "Address", Grow => 1.0),
                  "Address")],
              Gap     => 6.0,
              Padding => 8.0);
         Inside : constant UI.Layout :=
           UI.Column
             ([Bar,
               UI.Styled (UI.Put (Form, Parts.Start), (Grow => 1.0, others => <>)),
               Bound.Borrow_Widget (Parts.Page, Name => "Page", Grow => 1.0)],
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
         UI.Mount_Into (Form, Parts.Pane, Whole);
      end;
      Widgets.Set_Visible (Parts.Page, False);
      Widgets.Set_Visible (Parts.Pane, False);
   end Build;

   --  The page is shown once an address has been gone to; until then the place to start is.
   procedure Show_Page_Or_Start (Item : in out Session);

   procedure Show_Page_Or_Start (Item : in out Session) is
      Started : constant Boolean := Browser_VM.Has_Started (Item.Browser.Model);
   begin
      if Widgets.Is_Visible (Item.Browser.Page) /= Started then
         Widgets.Set_Visible (Item.Browser.Page, Started);
         Widgets.Set_Visible (Item.Browser.Start, not Started);
      end if;
   end Show_Page_Or_Start;

   procedure Sync (Item : in out Session) is
      Model : Nav_VM.View_Model renames Item.Nav_Model.Model;
      Shown : constant Boolean := Nav_VM.Browser_Shown (Model);
   begin
      Embeds.Set_Covered (Item.Browser.Page, Nav_VM.Is_Over (Model));
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

   procedure Update (Item : in out Session) is
   begin
      if Has_Screen (Item, Browser_Region) and then Widgets.Is_Visible (Item.Browser.Pane) then
         --  The window may have been made smaller than the pane.
         Set_Width (Item, Item.Browser.Wide);
         Browser_VM.Refresh (Item.Browser.Model);
         Show_Page_Or_Start (Item);
         Sync_Screen (Item, Browser_Region);
      end if;
   end Update;

end View.Browsers;
