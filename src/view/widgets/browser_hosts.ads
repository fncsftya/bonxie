with System;
with Browser_VM;
with Pomarine.Widgets.Embeds;
with Site_Filters;
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

   procedure Hold_Back (Using : Site_Filters.Rules);
   --  Have the web view open only the pages the rules permit (as Webshot.Live.Set_Filter). May be before Attach.

   type Live_Page is limited new Browser_VM.Page with null record;

   overriding
   function Is_Ready (Self : Live_Page) return Boolean;

   overriding
   procedure Load (Self : in out Live_Page; Where : String);

   overriding
   procedure Reload (Self : in out Live_Page);

   overriding
   function Address (Self : Live_Page) return String;

   overriding
   function Title (Self : Live_Page) return String;

   overriding
   procedure Go_Back (Self : in out Live_Page);

   overriding
   procedure Go_Forward (Self : in out Live_Page);

   overriding
   function Can_Go_Back (Self : Live_Page) return Boolean;

   overriding
   function Can_Go_Forward (Self : Live_Page) return Boolean;

   overriding
   function Theme_Colour (Self : Live_Page) return Integer;

   overriding
   procedure Start_Capture (Self : in out Live_Page; File : String; Current_View : Boolean);

   overriding
   function Capture_State (Self : Live_Page) return Browser_VM.Capture_States;

   overriding
   function Capture_Title (Self : Live_Page) return String;

   overriding
   function Capture_Message (Self : Live_Page) return String;

   overriding
   procedure Reset_Capture (Self : in out Live_Page);

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
