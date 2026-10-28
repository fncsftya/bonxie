with Ada.Strings.Unbounded;
with Favourites;
with Pomarine.View_Models;

--  What the browser pane does, apart from the widgets and the web view: the address being typed, and the commands
--  that load it and reload the page. The page itself is a Page, which the view gives it, so that the tests run it
--  without a window or WebKit. No page is asked for until the person goes to an address: until then the pane has
--  nothing to show but a place to type one, and the favourites (kept in a file, for all projects). Capture takes
--  the page as it is, whole, for the view to make a source of it.

package Browser_VM is

   type Command is (Go, Reload, Back, Forward, Home, Favourite, Capture, Open_Favourite);
   package Commands is new Pomarine.View_Models.Command_Models (Command);

   type Page is limited interface;
   --  The page the pane shows, which may not be there (a window with no web view).

   function Is_Ready (Self : Page) return Boolean is abstract;
   procedure Load (Self : in out Page; Where : String) is abstract;
   procedure Reload (Self : in out Page) is abstract;
   function Address (Self : Page) return String is abstract;
   --  Where it now is: a redirect or a click changes it.
   function Title (Self : Page) return String is abstract;
   --  Empty if it has none yet.
   procedure Go_Back (Self : in out Page) is abstract;
   procedure Go_Forward (Self : in out Page) is abstract;
   function Can_Go_Back (Self : Page) return Boolean is abstract;
   function Can_Go_Forward (Self : Page) return Boolean is abstract;
   function Theme_Colour (Self : Page) return Integer is abstract;
   --  The colour the page gives itself, as 16#RRGGBB#; -1 if none.

   type Capture_States is (Idle, Working, Done, Failed);

   procedure Start_Capture (Self : in out Page; File : String) is abstract;
   --  Begin to write the whole page as a picture: File, and beside it more if it is long (Pomarine.Strips).
   function Capture_State (Self : Page) return Capture_States is abstract;
   function Capture_Title (Self : Page) return String is abstract;
   --  The page's title when it was begun.
   function Capture_Message (Self : Page) return String is abstract;
   procedure Reset_Capture (Self : in out Page) is abstract;

   type Model is limited new Commands.Observed_Model with private;

   procedure Initialize (Self : in out Model; Shown : not null access Page'Class; Config : String := "");
   --  Shown must be there as long as the model is. Config is the folder the favourites and the picture of a
   --  capture are kept in; with none, they are not kept, and nothing is captured.

   function Address_Draft (Self : Model) return String;
   procedure Set_Address_Draft (Self : in out Model; Text : String)
   with Post => Address_Draft (Self) = Text;

   function Has_Started (Self : Model) return Boolean;
   --  Whether an address has been gone to: the page is there to be shown.

   procedure Refresh (Self : in out Model);
   --  Look at the page, and say what changed (where it is): for when nothing the model did has changed it.

   function Favourite_Count (Self : Model) return Natural;
   function Favourite_Title (Self : Model; Index : Positive) return String
   with Pre => Index <= Favourite_Count (Self);
   --  Its address if it has no title.
   function Favourite_Address (Self : Model; Index : Positive) return String
   with Pre => Index <= Favourite_Count (Self);
   function Favourite_Colour (Self : Model; Index : Positive) return Natural
   with Pre => Index <= Favourite_Count (Self), Post => Favourite_Colour'Result <= 16#FFFFFF#;
   --  Of the page, or one made of its site's name if it gave none.
   function Favourites_Version (Self : Model) return Pomarine.View_Models.Version_Number;
   --  Changes when a favourite is made or lost.

   function Is_Favourite (Self : Model) return Boolean;
   --  Whether the page that is shown is one.

   function Status (Self : Model) return String;
   --  What the tray says: that the page is being captured, or why it was not.

   function Capture_State (Self : Model) return Capture_States;
   --  Done: the picture is written, for the view to keep (Finish_Capture).
   function Capture_Title (Self : Model) return String;
   --  Of the page, as it was: its address if it had none.
   function Capture_Address (Self : Model) return String;
   function Capture_File (Self : Model) return String;

   procedure Finish_Capture (Self : in out Model)
   with Post => Capture_State (Self) = Idle;
   --  The view has the picture: ready for another.

   function Address_Of (Text : String) return String
   with Post => Address_Of'Result'Length >= Text'Length;
   --  What is to be loaded for what was typed: an address with its scheme, or https:// put before it.

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   --  Go: the page is there and something is typed. Reload, Capture, Favourite: the page has been gone to
   --  (Capture, and nothing is being captured; and a folder was given). Back, Forward: the page can.
   --  Home: the page has been gone to; it returns to the place to start. Open_Favourite
   --  (Index): that favourite is gone to, and Favourite marks the page, or, if it is marked, lets it go.

private

   type Page_Access is access all Page'Class;

   type Model is limited new Commands.Observed_Model with record
      Shown               : Page_Access;
      Draft               : Pomarine.View_Models.Text_Property;
      Where               : Ada.Strings.Unbounded.Unbounded_String;
      --  The page's address, as last seen.
      Started             : Boolean := False;
      Config              : Ada.Strings.Unbounded.Unbounded_String;
      Saved               : Favourites.Lists.List;
      Listed              : Pomarine.View_Models.Change_Counter;
      Back_Ok, Forward_Ok : Boolean := False;
      Taking              : Capture_States := Idle;
      Note                : Ada.Strings.Unbounded.Unbounded_String;
      Name                : Ada.Strings.Unbounded.Unbounded_String;
      Taken               : Ada.Strings.Unbounded.Unbounded_String;
      --  The page's title and address when the capture began.
   end record;

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0);

   overriding
   function Parts_Version (Self : Model) return Pomarine.View_Models.Version_Number;

end Browser_VM;
