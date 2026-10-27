with Webshot.Live;

package body Browser_Hosts is

   procedure Attach (Window : System.Address) is
   begin
      Webshot.Live.Attach (Window);
   end Attach;

   procedure Keep (Letter : Character; Number : Positive) is
   begin
      Webshot.Live.Keep (Letter, Number);
   end Keep;

   overriding
   procedure Place (Self : in out Browser_Host; Left, Top, Wide, High : Float; Showing : Boolean) is
      pragma Unreferenced (Self);
   begin
      if Webshot.Live.Attached then
         Webshot.Live.Place (Left, Top, Wide, High);
         Webshot.Live.Show (Showing);
      end if;
   end Place;

   overriding
   procedure Give_Keyboard (Self : in out Browser_Host; To_View : Boolean) is
   begin
      if Webshot.Live.Attached then
         Webshot.Live.Focus (To_View);
         if Self.Typing /= null then
            Self.Typing (not To_View);
         end if;
      end if;
   end Give_Keyboard;

   overriding
   function Has_Keyboard (Self : Browser_Host) return Boolean
   is (Webshot.Live.Attached and then Webshot.Live.Has_Focus);

   overriding
   function Shortcut (Self : in out Browser_Host) return Natural
   is (if Webshot.Live.Attached then Webshot.Live.Shortcut else 0);

end Browser_Hosts;
