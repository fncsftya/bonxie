with Webshot.Live;

package body Browser_Hosts is

   procedure Attach (Window : System.Address) is
      use type System.Address;
   begin
      if Window /= System.Null_Address then
         Webshot.Live.Attach (Window);
      end if;
   end Attach;

   function Is_Attached return Boolean
   is (Webshot.Live.Attached);

   procedure Keep (Letter : Character; Number : Positive) is
   begin
      Webshot.Live.Keep (Letter, Number);
   end Keep;

   overriding
   function Is_Ready (Self : Live_Page) return Boolean
   is (Webshot.Live.Attached);

   overriding
   procedure Load (Self : in out Live_Page; Where : String) is
   begin
      Webshot.Live.Load (Where);
   end Load;

   overriding
   procedure Reload (Self : in out Live_Page) is
   begin
      Webshot.Live.Reload;
   end Reload;

   overriding
   function Address (Self : Live_Page) return String
   is (Webshot.Live.Address);

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
         if Self.Typing_In /= null then
            if To_View then
               SDL3.Windows.Stop_Text_Input (Self.Typing_In.all);
            else
               SDL3.Windows.Start_Text_Input (Self.Typing_In.all);
            end if;
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
