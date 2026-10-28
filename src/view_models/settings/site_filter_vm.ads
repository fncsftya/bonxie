with Ada.Strings.Unbounded;
with Pomarine.Models;
with Pomarine.View_Models;
with Site_Filters;

--  What the browser's site filter means, apart from the widgets: how it is set (off, the blocked sites, or only
--  the allowed ones), the list of the sites in use, the address being typed to add one or change the one chosen,
--  and where it is kept. It names no widget or window, so the tests run it without one (see Site_Filter_VM_Tests).
--
--  What it comes to for the browser is the view's: it gives Rules, which the web view holds pages back by.

package Site_Filter_VM is

   package Parts renames Pomarine.View_Models;

   type Command is
     (Choose_Mode,
      --  Index: the Site_Filters.Modes'Pos.
      Add_Site,
      --  The base address of the draft, to the list in use.
      Change_Site,
      --  The chosen site becomes the draft's base address.
      Remove_Site);
   --  The chosen site goes.

   package Commands is new Parts.Command_Models (Command);

   type Model is limited new Commands.Observed_Model with private;

   procedure Initialize (Self : in out Model; Config : String);
   --  With what is kept in Config; nothing is kept if it is empty.

   function Rules (Self : Model) return Site_Filters.Rules;
   --  As the filter stands.

   function Mode (Self : Model) return Site_Filters.Modes;

   function Mode_Is (Self : Model; Value : Site_Filters.Modes) return Boolean;

   function List_Shown (Self : Model) return Boolean;
   --  The sites are listed, and edited, while a list is in use.

   function Count (Self : Model) return Natural;
   --  How many sites are in the list in use; 0 if none is.

   function Site (Self : Model; Row : Positive) return String
   with Pre => Row <= Count (Self);

   function Draft (Self : Model) return String;

   procedure Set_Draft (Self : in out Model; Text : String)
   with Post => Draft (Self) = Text;

   function Hint (Self : Model) return String;
   --  What is wrong with the draft, in words: "" if it is empty or it is fine.

   function Selected_Site (Self : Model) return Natural;
   --  The id of the chosen site (its row, which is its own while the list stays as it is); 0 if none.

   procedure Select_Site (Self : in out Model; Id : Natural)
   with Pre => Id <= Count (Self);
   --  Choose a site, or none (0): its address is the draft, to be changed.

   function Rows (Self : in out Model) return not null access Pomarine.Models.List_Model'Class;
   --  The sites in use as a list's rows; Self must outlive the list.

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   --  Choose_Mode: Index is a mode. Add_Site: a list is in use, and the draft is an address that is not in it.
   --  Change_Site and Remove_Site: a site is chosen (and, to change it, the draft is a new address).

private

   package Strings renames Ada.Strings.Unbounded;

   type Site_Rows (Owner : not null access constant Model) is limited new Pomarine.Models.List_Model with null record;

   overriding
   function Count (Self : Site_Rows) return Natural;
   overriding
   function Version (Self : Site_Rows) return Natural;
   overriding
   function Row_Id (Self : Site_Rows; Row : Positive) return Positive;
   overriding
   procedure Describe_Row (Self : Site_Rows; Row : Positive; Content : out Pomarine.Models.Row_Content);

   type Model is limited new Commands.Observed_Model with record
      Held    : Site_Filters.Rules;
      Config  : Strings.Unbounded_String;
      Typed   : Parts.Text_Property;
      Choice  : Natural := 0;
      Edits   : Natural := 0;
      --  Of the list in use, and of which it is: for the rows.
      Showing : aliased Site_Rows (Model'Access);
   end record;

   overriding
   function Parts_Version (Self : Model) return Parts.Version_Number;

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0);

end Site_Filter_VM;
