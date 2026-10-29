with Ada.Directories;
with Ada.Strings.Unbounded;
with Browser_VM;
with Goldens;

package body Browser_VM_Tests is

   package Strings renames Ada.Strings.Unbounded;

   use all type Browser_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   function Can (Model : Browser_VM.Model; What : Browser_VM.Command) return String
   is (Image (Browser_VM.Can_Execute (Model, What)));

   --  A page that keeps what it was told.
   type Pretend is limited new Browser_VM.Page with record
      Present   : Boolean := True;
      Loaded    : Strings.Unbounded_String;
      Loads     : Natural := 0;
      Reloads   : Natural := 0;
      Location  : Strings.Unbounded_String;
      Backs     : Natural := 0;
      Capturing : Boolean := False;
      View_Only : Boolean := False;
   end record;

   overriding
   function Is_Ready (Self : Pretend) return Boolean;
   overriding
   procedure Load (Self : in out Pretend; Where : String);
   overriding
   procedure Reload (Self : in out Pretend);
   overriding
   function Address (Self : Pretend) return String;
   overriding
   function Title (Self : Pretend) return String;
   overriding
   procedure Go_Back (Self : in out Pretend);
   overriding
   procedure Go_Forward (Self : in out Pretend);
   overriding
   function Can_Go_Back (Self : Pretend) return Boolean;
   overriding
   function Can_Go_Forward (Self : Pretend) return Boolean;
   overriding
   function Theme_Colour (Self : Pretend) return Integer;
   overriding
   procedure Start_Capture (Self : in out Pretend; File : String; Current_View : Boolean);
   overriding
   function Capture_State (Self : Pretend) return Browser_VM.Capture_States;
   overriding
   function Capture_Title (Self : Pretend) return String;
   overriding
   function Capture_Message (Self : Pretend) return String;
   overriding
   procedure Reset_Capture (Self : in out Pretend);

   overriding
   function Is_Ready (Self : Pretend) return Boolean
   is (Self.Present);

   overriding
   procedure Load (Self : in out Pretend; Where : String) is
   begin
      Self.Loaded := Strings.To_Unbounded_String (Where);
      Self.Location := Self.Loaded;
      Self.Loads := Self.Loads + 1;
   end Load;

   overriding
   procedure Reload (Self : in out Pretend) is
   begin
      Self.Reloads := Self.Reloads + 1;
   end Reload;

   overriding
   function Address (Self : Pretend) return String
   is (Strings.To_String (Self.Location));

   overriding
   function Title (Self : Pretend) return String
   is ("A page");

   overriding
   procedure Go_Back (Self : in out Pretend) is
   begin
      Self.Backs := Self.Backs + 1;
   end Go_Back;

   overriding
   procedure Go_Forward (Self : in out Pretend) is null;

   overriding
   function Can_Go_Back (Self : Pretend) return Boolean
   is (Self.Backs = 0);

   overriding
   function Can_Go_Forward (Self : Pretend) return Boolean
   is (False);

   overriding
   function Theme_Colour (Self : Pretend) return Integer
   is (16#102030#);

   overriding
   procedure Start_Capture (Self : in out Pretend; File : String; Current_View : Boolean) is
   begin
      Self.Capturing := File /= "";
      Self.View_Only := Current_View;
   end Start_Capture;

   overriding
   function Capture_State (Self : Pretend) return Browser_VM.Capture_States
   is (if Self.Capturing then Browser_VM.Done else Browser_VM.Idle);

   overriding
   function Capture_Title (Self : Pretend) return String
   is ("A page");

   overriding
   function Capture_Message (Self : Pretend) return String
   is ("");

   overriding
   procedure Reset_Capture (Self : in out Pretend) is
   begin
      Self.Capturing := False;
   end Reset_Capture;

   procedure Addresses is
   begin
      Check ("browser-vm-scheme-kept", "http://a.org/x", Browser_VM.Address_Of ("http://a.org/x"));
      Check ("browser-vm-https-kept", "https://a.org", Browser_VM.Address_Of ("https://a.org"));
      Check ("browser-vm-scheme-added", "https://a.org/x?y=1", Browser_VM.Address_Of ("a.org/x?y=1"));
      Check ("browser-vm-short", "https://h", Browser_VM.Address_Of ("h"));
   end Addresses;

   procedure Going is
      Shown : aliased Pretend;
      Model : Browser_VM.Model;
   begin
      Browser_VM.Initialize (Model, Shown'Access);
      Check
        ("browser-vm-before-go",
         "FALSE FALSE FALSE 0",
         Image (Browser_VM.Has_Started (Model))
         & " "
         & Can (Model, Go)
         & " "
         & Can (Model, Reload)
         & Shown.Loads'Image);

      --  Nothing typed, nothing to go to.
      Browser_VM.Refresh (Model);
      Check ("browser-vm-nothing-asked", "0", Shown.Loads'Image (2 .. Shown.Loads'Image'Last));

      Browser_VM.Set_Address_Draft (Model, "example.org/a");
      Check ("browser-vm-can-go", "TRUE FALSE", Can (Model, Go) & " " & Can (Model, Reload));
      Browser_VM.Execute (Model, Go);
      Check
        ("browser-vm-gone",
         "https://example.org/a 1 TRUE",
         Strings.To_String (Shown.Loaded) & Shown.Loads'Image & " " & Image (Browser_VM.Has_Started (Model)));
      Check ("browser-vm-can-reload", "TRUE", Can (Model, Reload));

      --  Where the page is now is the address shown, as redirects and clicks change it.
      Shown.Location := Strings.To_Unbounded_String ("https://example.org/b");
      Browser_VM.Refresh (Model);
      Check ("browser-vm-address-follows", "https://example.org/b", Browser_VM.Address_Draft (Model));

      Browser_VM.Execute (Model, Reload);
      Check ("browser-vm-reloaded", "1", Shown.Reloads'Image (2 .. Shown.Reloads'Image'Last));
   end Going;

   procedure Keeping is
      Shown  : aliased Pretend;
      Model  : Browser_VM.Model;
      Folder : constant String := "/tmp/bonxie-browser-vm-test";
   begin
      Ada.Directories.Create_Path (Folder);
      if Ada.Directories.Exists (Folder & "/favourites") then
         Ada.Directories.Delete_File (Folder & "/favourites");
      end if;
      Browser_VM.Initialize (Model, Shown'Access, Folder);
      Browser_VM.Set_Address_Draft (Model, "example.org/a");
      Browser_VM.Execute (Model, Go);
      Browser_VM.Refresh (Model);
      Check ("browser-vm-nav-back", "TRUE FALSE", Can (Model, Back) & " " & Can (Model, Forward));

      Check ("browser-vm-can-home", "TRUE", Can (Model, Home));

      Browser_VM.Execute (Model, Favourite);
      Check
        ("browser-vm-favourited",
         "1 A page https://example.org/a TRUE",
         Browser_VM.Favourite_Count (Model)'Image (2 .. 2)
         & " "
         & Browser_VM.Favourite_Title (Model, 1)
         & " "
         & Browser_VM.Favourite_Address (Model, 1)
         & " "
         & Image (Browser_VM.Is_Favourite (Model)));
      Check ("browser-vm-favourite-colour", "1056816", Browser_VM.Favourite_Colour (Model, 1)'Image (2 .. 8));

      --  A second model reads the file the first kept.
      declare
         Again : Browser_VM.Model;
      begin
         Browser_VM.Initialize (Again, Shown'Access, Folder);
         Check ("browser-vm-favourite-kept", "https://example.org/a", Browser_VM.Favourite_Address (Again, 1));
      end;

      Browser_VM.Execute (Model, Favourite);
      Check ("browser-vm-unfavourited", "0", Browser_VM.Favourite_Count (Model)'Image (2 .. 2));

      Browser_VM.Execute (Model, Capture);
      pragma Assert (not Shown.View_Only);
      Browser_VM.Refresh (Model);
      Check
        ("browser-vm-captured",
         "DONE A page https://example.org/a",
         Browser_VM.Capture_State (Model)'Image
         & " "
         & Browser_VM.Capture_Title (Model)
         & " "
         & Browser_VM.Capture_Address (Model));
      Browser_VM.Finish_Capture (Model);
      Check ("browser-vm-capture-finished", "IDLE", Browser_VM.Capture_State (Model)'Image);
      Browser_VM.Execute (Model, Capture_View);
      pragma Assert (Shown.View_Only);
      Browser_VM.Refresh (Model);
      Browser_VM.Finish_Capture (Model);

      Browser_VM.Execute (Model, Home);
      Check
        ("browser-vm-home",
         "FALSE FALSE ",
         Image (Browser_VM.Has_Started (Model)) & " " & Can (Model, Home) & " " & Browser_VM.Address_Draft (Model));
   end Keeping;

   procedure Without_A_Page is
      Shown : aliased Pretend;
      Model : Browser_VM.Model;
   begin
      Shown.Present := False;
      Browser_VM.Initialize (Model, Shown'Access);
      Browser_VM.Set_Address_Draft (Model, "example.org");
      Browser_VM.Refresh (Model);
      Check
        ("browser-vm-nothing",
         "FALSE FALSE FALSE 0",
         Image (Browser_VM.Has_Started (Model))
         & " "
         & Can (Model, Go)
         & " "
         & Can (Model, Reload)
         & " "
         & Shown.Loads'Image (2 .. Shown.Loads'Image'Last));
   end Without_A_Page;

end Browser_VM_Tests;
