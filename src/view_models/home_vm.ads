with Pomarine.View_Models;
with Confirm_VM;
with Projects;

--  The view-model of the home screen: the recent projects, how many documents and
--  sources each has, renaming one in place, and deleting one (the dialog that asks
--  first is Confirm_VM). It names no widget, so the tests run it without a window.
package Home_VM is

   package Parts renames Pomarine.View_Models;

   use type Projects.Id;

   type Command is
     (Refresh,
      --  List the most recently updated projects again; any renaming stops.
      Begin_Rename,
      --  Index: the row. Its title is the draft, to type over.
      Accept_Rename,
      --  Give the project being renamed the draft, unless it is nothing but spaces.
      Cancel_Rename,
      Ask_Delete);
      --  Index: a listed row. Stop renaming and ask before deleting it, retaining its stable key.

   package Commands is new Parts.Command_Models (Command);

   --  The projects kept.

   type Library is limited interface;

   procedure Recent (Self : in out Library; Into : out Projects.Recent_List) is abstract;

   procedure Count_Items (Self : in out Library; Key : Projects.Id; Documents, Sources : out Natural) is abstract;

   procedure Rename (Self : in out Library; Key : Projects.Id; Words : String) is abstract;

   procedure Delete (Self : in out Library; Key : Projects.Id) is abstract;

   type Effects is limited interface;

   procedure Home_Changed (Self : in out Effects) is abstract;
   --  After a command was done: the screen shows the projects and the renaming.

   type View_Model is limited new Commands.Model with private;

   procedure Observe (Self : in out View_Model; Reactions : access Effects'Class);
   --  Tell Reactions, from now on, after every command that is done.

   procedure Initialize
     (Self : in out View_Model; Kept : not null access Library'Class;
      Dialog : access Confirm_VM.View_Model := null);
   --  Kept and an optional confirmation model must outlive Self. The projects are listed.

   procedure Delete_Confirmed (Self : in out View_Model; Key : Projects.Id)
     with Pre => Key /= 0,
          Post => Editing (Self) = 0;
   --  Delete the confirmed identity, even if the recent-project list has since moved or omitted its row.

   --  The rows

   function Count (Self : View_Model) return Natural
     with Post => Count'Result <= Projects.Recent_Count;

   function Key_Of (Self : View_Model; Row : Positive) return Projects.Id
     with Pre => Row <= Count (Self);

   function Title (Self : View_Model; Row : Positive) return String
     with Pre => Row <= Count (Self);

   function Meta (Self : View_Model; Row : Positive) return String
     with Pre => Row <= Count (Self);
   --  "2 documents · 1 source".

   function Listed_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever the rows are listed again.

   --  Renaming

   function Editing (Self : View_Model) return Natural;
   --  The row being renamed, 0 if none.

   function Draft (Self : View_Model) return String;

   procedure Set_Draft (Self : in out View_Model; Text : String)
     with Post => Draft (Self) = Text;
   --  What has been typed over the title.

   overriding function Version (Self : View_Model) return Parts.Version_Number;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Refresh: always. Begin_Rename: the project of the row (Index; 0 for any) is listed.
   --  Ask_Delete: a positive listed row and an injected confirmation model that is not already asking.
   --  Cancel_Rename: one is being renamed. Accept_Rename: one is, and the draft is something besides spaces.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => (case What is
                      when Begin_Rename => Editing (Self) = Index,
                      when Accept_Rename | Cancel_Rename | Refresh | Ask_Delete => Editing (Self) = 0);
   --  A row that is not listed is refused by the precondition.

private

   type Counts is record
      Documents, Sources : Natural := 0;
   end record;

   type Count_Array is array (1 .. Projects.Recent_Count) of Counts;

   type Library_Access is access all Library'Class;

   type Effects_Access is access all Effects'Class;
   type Dialog_Access is access all Confirm_VM.View_Model;

   type View_Model is limited new Commands.Model with record
      Reactions : Effects_Access;
      Dialog : Dialog_Access;
      Kept    : Library_Access;
      Listed  : Projects.Recent_List;
      Numbers : Count_Array;
      Row     : Natural := 0;
      --  Being renamed.
      Typed   : Parts.Text_Property;
      Changes : Parts.Change_Counter;
      --  Of the list, and the row.
      Lists   : Parts.Change_Counter;
      --  Of the list.
   end record;

end Home_VM;
