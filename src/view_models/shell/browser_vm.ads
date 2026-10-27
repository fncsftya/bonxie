with Ada.Strings.Unbounded;
with Pomarine.View_Models;

--  What the browser pane does, apart from the widgets and the web view: the address being typed, and the commands
--  that load it and reload the page. The page itself is a Page, which the view gives it, so that the tests run it
--  without a window or WebKit. No page is asked for until the person goes to an address: until then the pane has
--  nothing to show but a place to type one.

package Browser_VM is

   type Command is (Go, Reload);
   package Commands is new Pomarine.View_Models.Command_Models (Command);

   type Page is limited interface;
   --  The page the pane shows, which may not be there (a window with no web view).

   function Is_Ready (Self : Page) return Boolean is abstract;
   procedure Load (Self : in out Page; Where : String) is abstract;
   procedure Reload (Self : in out Page) is abstract;
   function Address (Self : Page) return String is abstract;
   --  Where it now is: a redirect or a click changes it.

   type Model is limited new Commands.Observed_Model with private;

   procedure Initialize (Self : in out Model; Shown : not null access Page'Class);
   --  Shown must be there as long as the model is.

   function Address_Draft (Self : Model) return String;
   procedure Set_Address_Draft (Self : in out Model; Text : String)
   with Post => Address_Draft (Self) = Text;

   function Has_Started (Self : Model) return Boolean;
   --  Whether an address has been gone to: the page is there to be shown.

   procedure Refresh (Self : in out Model);
   --  Look at the page, and say what changed (where it is): for when nothing the model did has changed it.

   function Address_Of (Text : String) return String
   with Post => Address_Of'Result'Length >= Text'Length;
   --  What is to be loaded for what was typed: an address with its scheme, or https:// put before it.

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   --  Go: the page is there and something is typed. Reload: the page has been gone to.

private

   type Page_Access is access all Page'Class;

   type Model is limited new Commands.Observed_Model with record
      Shown   : Page_Access;
      Draft   : Pomarine.View_Models.Text_Property;
      Where   : Ada.Strings.Unbounded.Unbounded_String;
      --  The page's address, as last seen.
      Started : Boolean := False;
   end record;

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0);

   overriding
   function Parts_Version (Self : Model) return Pomarine.View_Models.Version_Number;

end Browser_VM;
