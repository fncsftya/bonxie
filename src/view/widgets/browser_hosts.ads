with System;
with Browser_VM;
with Pomarine.Widgets.Embeds;
with SDL3.Windows;

--  The live web view (Webshot.Live) in the browser pane: as the Page the browser's view-model moves, and as the host
--  of the Embed that stands for it (the page is shown where the widget is, hidden while something is over it, and
--  has the keyboard as the widget does). Command with a letter given to Keep is the application's while the page has
--  the keyboard, and is said as its number.

package Browser_Hosts is

   procedure Attach (Window : System.Address);
   --  Put the view in the window (SDL3.Windows.Native_Handle: null if there is none, as with no screen). Before
   --  the widget is given the host.

   function Is_Attached return Boolean;

   procedure Keep (Letter : Character; Number : Positive);

   type Live_Page is limited new Browser_VM.Page with null record;

   overriding
   function Is_Ready (Self : Live_Page) return Boolean;

   overriding
   procedure Load (Self : in out Live_Page; Where : String);

   overriding
   procedure Reload (Self : in out Live_Page);

   overriding
   function Address (Self : Live_Page) return String;

   type Window_Access is access all SDL3.Windows.Window;

   type Browser_Host is limited new Pomarine.Widgets.Embeds.Host with record
      Typing_In : Window_Access;
      --  The window whose text input is off while the page has the keyboard: the window would give each key to the
      --  page a second time.
   end record;

   overriding
   procedure Place (Self : in out Browser_Host; Left, Top, Wide, High : Float; Showing : Boolean);

   overriding
   procedure Give_Keyboard (Self : in out Browser_Host; To_View : Boolean);

   overriding
   function Has_Keyboard (Self : Browser_Host) return Boolean;

   overriding
   function Shortcut (Self : in out Browser_Host) return Natural;

end Browser_Hosts;
