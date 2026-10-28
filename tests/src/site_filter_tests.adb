with Ada.Directories;
with Ada.Strings.Unbounded;
with Goldens;
with Site_Filter_VM;
with Site_Filters;

package body Site_Filter_Tests is

   package Strings renames Ada.Strings.Unbounded;

   use all type Site_Filter_VM.Command;
   use all type Site_Filters.Modes;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   function Can (Model : Site_Filter_VM.Model; What : Site_Filter_VM.Command; Index : Natural := 0) return String
   is (Image (Site_Filter_VM.Can_Execute (Model, What, Index)));

   function Listed (Model : Site_Filter_VM.Model) return String is
      Text : Strings.Unbounded_String;
   begin
      for Row in 1 .. Site_Filter_VM.Count (Model) loop
         Strings.Append (Text, (if Row > 1 then " " else "") & Site_Filter_VM.Site (Model, Row));
      end loop;
      return Strings.To_String (Text);
   end Listed;

   procedure Bases is
   begin
      Check ("site-filter-base-plain", "https://google.com", Site_Filters.Base_Of ("https://google.com"));
      Check ("site-filter-base-path", "https://google.com", Site_Filters.Base_Of ("https://google.com/search?q=a#b"));
      Check ("site-filter-base-no-scheme", "https://google.com", Site_Filters.Base_Of ("Google.com/maps"));
      Check ("site-filter-base-http", "http://example.org", Site_Filters.Base_Of ("http://Example.ORG/"));
      Check ("site-filter-base-port", "http://localhost:8080", Site_Filters.Base_Of ("http://localhost:8080/x"));
      Check ("site-filter-base-login", "https://a.org", Site_Filters.Base_Of ("https://me:secret@a.org/x"));
      Check ("site-filter-base-spaces", "https://a.org", Site_Filters.Base_Of ("  a.org  "));
      Check ("site-filter-base-empty", "", Site_Filters.Base_Of (""));
      Check ("site-filter-base-words", "", Site_Filters.Base_Of ("not an address"));
      Check ("site-filter-base-scheme-only", "", Site_Filters.Base_Of ("https://"));
      Check ("site-filter-base-other-scheme", "", Site_Filters.Base_Of ("ftp://a.org"));
      Check ("site-filter-base-bad-port", "", Site_Filters.Base_Of ("a.org:80x"));
   end Bases;

   procedure Rules_Permit is
      Using : Site_Filters.Rules;

      function Lets (Address : String) return String
      is (Image (Site_Filters.Permits (Using, Address)));
   begin
      Site_Filters.Lists.Append (Using.Blocked, Strings.To_Unbounded_String ("https://bad.com"));
      Site_Filters.Lists.Append (Using.Allowed, Strings.To_Unbounded_String ("https://good.org"));

      Check ("site-filter-off", "TRUE TRUE", Lets ("https://bad.com/x") & " " & Lets ("https://anything.net"));

      Using.Mode := Use_Blocked;
      Check
        ("site-filter-blocking",
         "FALSE FALSE FALSE TRUE TRUE TRUE",
         Lets ("https://bad.com")
         & " "
         & Lets ("http://BAD.com/a?b")
         & " "
         & Lets ("https://www.bad.com")
         & " "
         & Lets ("https://notbad.com")
         & " "
         & Lets ("https://bad.com.evil.net/x")
         & " "
         & Lets ("https://good.org"));

      Using.Mode := Use_Allowed;
      Check
        ("site-filter-allowing",
         "TRUE TRUE FALSE FALSE",
         Lets ("https://good.org/a")
         & " "
         & Lets ("https://docs.good.org")
         & " "
         & Lets ("https://bad.com")
         & " "
         & Lets ("https://agood.org"));

      Check ("site-filter-not-web", "TRUE TRUE", Lets ("about:blank") & " " & Lets ("file:///tmp/a.html"));

      Using.Mode := Use_Allowed;
      Check ("site-filter-hosts", "good.org" & ASCII.LF, Site_Filters.Hosts_Of (Using));
      Using.Mode := Off;
      Check ("site-filter-hosts-off", "", Site_Filters.Hosts_Of (Using));
   end Rules_Permit;

   procedure Editing is
      Folder : constant String := "/tmp/bonxie-site-filter-test";
      Model  : Site_Filter_VM.Model;
   begin
      Ada.Directories.Create_Path (Folder);
      if Ada.Directories.Exists (Folder & "/site-filter") then
         Ada.Directories.Delete_File (Folder & "/site-filter");
      end if;
      Site_Filter_VM.Initialize (Model, Folder);

      Check
        ("site-filter-vm-start",
         "OFF FALSE FALSE 0",
         Site_Filters.Modes'Image (Site_Filter_VM.Mode (Model))
         & " "
         & Image (Site_Filter_VM.List_Shown (Model))
         & " "
         & Can (Model, Add_Site)
         & Site_Filter_VM.Count (Model)'Image);

      Site_Filter_VM.Execute (Model, Choose_Mode, Site_Filters.Modes'Pos (Use_Blocked));
      Site_Filter_VM.Set_Draft (Model, "Example.com/page");
      Check ("site-filter-vm-can-add", "TRUE", Can (Model, Add_Site));
      Site_Filter_VM.Execute (Model, Add_Site);
      Check ("site-filter-vm-added", "https://example.com |", Listed (Model) & " |" & Site_Filter_VM.Draft (Model));

      --  The same site again, and what is no address.
      Site_Filter_VM.Set_Draft (Model, "https://example.com");
      Check
        ("site-filter-vm-twice",
         "FALSE That site is in the list already.",
         Can (Model, Add_Site) & " " & Site_Filter_VM.Hint (Model));
      Site_Filter_VM.Set_Draft (Model, "two words");
      Check
        ("site-filter-vm-not-address",
         "FALSE That is not a web address.",
         Can (Model, Add_Site) & " " & Site_Filter_VM.Hint (Model));
      Site_Filter_VM.Set_Draft (Model, "");

      Site_Filter_VM.Set_Draft (Model, "other.org");
      Site_Filter_VM.Execute (Model, Add_Site);
      Check ("site-filter-vm-two", "https://example.com https://other.org", Listed (Model));

      --  Choosing a site makes it the draft; change it, or remove it.
      Check ("site-filter-vm-none-chosen", "FALSE FALSE", Can (Model, Change_Site) & " " & Can (Model, Remove_Site));
      Site_Filter_VM.Select_Site (Model, 2);
      Check
        ("site-filter-vm-chosen",
         "https://other.org TRUE TRUE",
         Site_Filter_VM.Draft (Model) & " " & Can (Model, Change_Site) & " " & Can (Model, Remove_Site));
      --  Letting go of it, untouched, leaves nothing typed, and no complaint.
      Site_Filter_VM.Select_Site (Model, 0);
      Check ("site-filter-vm-let-go", "|", Site_Filter_VM.Draft (Model) & "|" & Site_Filter_VM.Hint (Model));
      Site_Filter_VM.Select_Site (Model, 2);
      Site_Filter_VM.Set_Draft (Model, "https://third.net/x");
      Site_Filter_VM.Execute (Model, Change_Site);
      Check ("site-filter-vm-changed", "https://example.com https://third.net", Listed (Model));
      Site_Filter_VM.Execute (Model, Remove_Site);
      Check
        ("site-filter-vm-removed",
         "https://example.com 0",
         Listed (Model) & Site_Filter_VM.Selected_Site (Model)'Image);

      --  The other list is its own, and the rules say what the web view holds back.
      Site_Filter_VM.Execute (Model, Choose_Mode, Site_Filters.Modes'Pos (Use_Allowed));
      Check ("site-filter-vm-other-list", "0", Site_Filter_VM.Count (Model)'Image (2 .. 2));
      Site_Filter_VM.Set_Draft (Model, "good.org");
      Site_Filter_VM.Execute (Model, Add_Site);
      Check
        ("site-filter-vm-rules",
         "FALSE TRUE",
         Image (Site_Filters.Permits (Site_Filter_VM.Rules (Model), "https://example.com"))
         & " "
         & Image (Site_Filters.Permits (Site_Filter_VM.Rules (Model), "https://good.org/a")));

      --  Kept, for another model.
      declare
         Again : Site_Filter_VM.Model;
      begin
         Site_Filter_VM.Initialize (Again, Folder);
         Site_Filter_VM.Execute (Again, Choose_Mode, Site_Filters.Modes'Pos (Use_Blocked));
         Check ("site-filter-vm-kept-blocked", "https://example.com", Listed (Again));
         Site_Filter_VM.Execute (Again, Choose_Mode, Site_Filters.Modes'Pos (Use_Allowed));
         Check ("site-filter-vm-kept-allowed", "https://good.org", Listed (Again));
      end;
      declare
         Third : Site_Filter_VM.Model;
      begin
         Site_Filter_VM.Initialize (Third, Folder);
         Check ("site-filter-vm-kept-mode", "USE_ALLOWED", Site_Filters.Modes'Image (Site_Filter_VM.Mode (Third)));
      end;
   end Editing;

end Site_Filter_Tests;
