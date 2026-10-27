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
      Present  : Boolean := True;
      Loaded   : Strings.Unbounded_String;
      Loads    : Natural := 0;
      Reloads  : Natural := 0;
      Location : Strings.Unbounded_String;
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
