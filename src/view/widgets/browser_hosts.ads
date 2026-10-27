with System;
with Pomarine.Widgets.Embeds;

--  The live web view (Webshot.Live) as the host of an Embed: the page is shown where the widget is, hidden while an
--  overlay is over it, and has the keyboard as the widget does. Command with a letter given to Keep is the
--  application's while the page has the keyboard, and is said as its number.

package Browser_Hosts is

   type Typing_Switch is access procedure (On : Boolean);

   type Browser_Host is limited new Pomarine.Widgets.Embeds.Host with record
      Typing : Typing_Switch;
      --  What turns typing in the window as text on and off (Pomarine.Windows.Set_Typing), if the window should:
      --  while the page has the keyboard, the window's own text input would be given each key as well.
   end record;

   procedure Attach (Window : System.Address);
   --  Put the view in the window (Pomarine.Windows.Native_Handle). Before the widget is given the host.

   procedure Keep (Letter : Character; Number : Positive);

   overriding
   procedure Place (Self : in out Browser_Host; Left, Top, Wide, High : Float; Showing : Boolean);

   overriding
   procedure Give_Keyboard (Self : in out Browser_Host; To_View : Boolean);

   overriding
   function Has_Keyboard (Self : Browser_Host) return Boolean;

   overriding
   function Shortcut (Self : in out Browser_Host) return Natural;

end Browser_Hosts;
