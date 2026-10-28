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
   function Title (Self : Live_Page) return String
   is (Webshot.Live.Title);

   overriding
   procedure Go_Back (Self : in out Live_Page) is
   begin
      Webshot.Live.Go_Back;
   end Go_Back;

   overriding
   procedure Go_Forward (Self : in out Live_Page) is
   begin
      Webshot.Live.Go_Forward;
   end Go_Forward;

   overriding
   function Can_Go_Back (Self : Live_Page) return Boolean
   is (Webshot.Live.Can_Go_Back);

   overriding
   function Can_Go_Forward (Self : Live_Page) return Boolean
   is (Webshot.Live.Can_Go_Forward);

   overriding
   function Theme_Colour (Self : Live_Page) return Integer
   is (Webshot.Live.Theme_Colour);

   overriding
   procedure Start_Capture (Self : in out Live_Page; File : String) is
   begin
      Webshot.Live.Capture (File);
   end Start_Capture;

   overriding
   function Capture_State (Self : Live_Page) return Browser_VM.Capture_States
   is (case Webshot.Live.Capture_State is
         when Webshot.Live.Idle    => Browser_VM.Idle,
         when Webshot.Live.Working => Browser_VM.Working,
         when Webshot.Live.Done    => Browser_VM.Done,
         when Webshot.Live.Failed  => Browser_VM.Failed);

   overriding
   function Capture_Title (Self : Live_Page) return String
   is (Webshot.Live.Capture_Title);

   overriding
   function Capture_Message (Self : Live_Page) return String
   is (Webshot.Live.Capture_Message);

   overriding
   procedure Reset_Capture (Self : in out Live_Page) is
   begin
      Webshot.Live.Capture_Reset;
   end Reset_Capture;

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
