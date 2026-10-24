with Pomarine.View_Models;
with Projects.Sections;

--  The view-model of a project's outline: the sections of the project in the order they are read in, which of
--  them have their notes open, and what is the title and description of the project. It has the rules of the
--  outline (a project is not left without a name, a section moves only to a place there is, and so on) and
--  keeps everything as it is typed or done. It names no widget, so the tests run it without a window.
--
--  Dragging a block is a gesture, and is the view's: what it comes to, Move, is the view-model's.
package Outline_VM is

   package Parts renames Pomarine.View_Models;

   package Sections renames Projects.Sections;

   Untitled_Section : constant String := "Untitled section";
   --  What a section is called until it is named.

   type Command is
     (Add_Section,
      --  Put a section last.
      Move_Up,
      --  Index: the row. Nothing is done for the first.
      Move_Down,
      --  Index: the row. Nothing is done for the last.
      Remove_Section,
      --  Index: the row.
      Toggle_Notes);
      --  Index: the row. Show its notes, or hide them.

   package Commands is new Parts.Command_Models (Command);

   --  The sections kept.

   type Library is limited interface;

   procedure Project_Words
     (Self : in out Library; Owner : Projects.Id; Found : out Boolean;
      Title, Description : out Projects.Titles.Text) is abstract;
   --  The project's title, and its description as kept (marked up).

   procedure Rename_Project (Self : in out Library; Owner : Projects.Id; Title : String) is abstract;

   procedure Keep_Description (Self : in out Library; Owner : Projects.Id; Stored : String) is abstract;

   procedure Load
     (Self    : in out Library;
      Owner   : Projects.Id;
      Order   : out Sections.Section_List;
      Links   : out Sections.Link_List) is abstract;

   procedure Load_Links
     (Self : in out Library; Owner : Projects.Id; Links : out Sections.Link_List) is abstract;

   function Add (Self : in out Library; Owner : Projects.Id; Title : String) return Sections.Section_Id is abstract;

   procedure Rename (Self : in out Library; Key : Sections.Section_Id; Title : String) is abstract;

   procedure Delete (Self : in out Library; Key : Sections.Section_Id) is abstract;

   procedure Set_Order
     (Self : in out Library; Owner : Projects.Id; Order : Sections.Key_Array) is abstract;

   function Stored_Notes (Self : in out Library; Key : Sections.Section_Id) return String is abstract;

   procedure Keep_Notes (Self : in out Library; Key : Sections.Section_Id; Stored : String) is abstract;

   procedure Set_Colour (Self : in out Library; Key : Sections.Section_Id; Colour : Sections.Colour_Value) is abstract;

   type View_Model is limited new Commands.Model with private;

   procedure Initialize (Self : in out View_Model; Kept : not null access Library'Class);
   --  Kept must be there as long as the view-model is. No project is in it.

   procedure Enter (Self : in out View_Model; Owner : Projects.Id)
     with Post => Is_Entered (Self);
   --  The project's title, description and sections are read, and its notes are open that have any.

   procedure Leave (Self : in out View_Model)
     with Post => not Is_Entered (Self) and then Count (Self) = 0;
   --  Let go of the project's sections.

   function Is_Entered (Self : View_Model) return Boolean;

   procedure Reload (Self : in out View_Model)
     with Pre => Is_Entered (Self);
   --  The sections have been changed in the database (their links): read them again. Which are open is
   --  not forgotten.

   --  The project

   function Project_Title (Self : View_Model) return String;
   --  As kept.

   function Project_Description (Self : View_Model) return String;
   --  As kept, marked up.

   procedure Reload_Project (Self : in out View_Model)
     with Pre => Is_Entered (Self);
   --  Read them again: the project may have been renamed elsewhere.

   procedure Set_Project_Title (Self : in out View_Model; Text : String; Kept : out Boolean)
     with Pre => Is_Entered (Self),
          Post => Kept = (Trimmed (Text) /= "");
   --  Name the project Text, without the spaces about it. A project is not left without a name: Kept is
   --  False, and nothing is done, if there is none.

   procedure Set_Project_Description (Self : in out View_Model; Stored : String)
     with Pre => Is_Entered (Self);

   function Trimmed (Text : String) return String;
   --  Without the spaces about it.

   --  The sections

   function Count (Self : View_Model) return Natural;

   function Section_At (Self : View_Model; Row : Positive) return Sections.Section
     with Pre => Row <= Count (Self);

   function Title (Self : View_Model; Row : Positive) return String
     with Pre => Row <= Count (Self);

   function Notes (Self : View_Model; Row : Positive) return String
     with Pre => Row <= Count (Self);
   --  As typed.

   function Stored_Notes (Self : in out View_Model; Row : Positive) return String
     with Pre => Row <= Count (Self);
   --  As kept, marked up.

   function Is_Open (Self : View_Model; Row : Positive) return Boolean
     with Pre => Row <= Count (Self);
   --  Whether its notes are shown.

   function Documents_In (Self : View_Model; Row : Positive) return Natural
     with Pre => Row <= Count (Self);
   --  How many items are of the section.

   function Section_Of_Item (Self : View_Model; Item : Long_Integer) return Natural;
   --  The place in the outline of the section the item (by its key) is of; 0 if it is of none.

   function Index_Of_Key (Self : View_Model; Key : Sections.Section_Id) return Natural;
   --  The place of the section with the key; 0 if there is none.

   function Can_Move_Up (Self : View_Model; Row : Positive) return Boolean
     with Pre => Row <= Count (Self);

   function Can_Move_Down (Self : View_Model; Row : Positive) return Boolean
     with Pre => Row <= Count (Self);

   procedure Set_Title (Self : in out View_Model; Row : Positive; Text : String)
     with Pre => Row <= Count (Self),
          Post => Title (Self, Row) = Text;
   --  The section is called Text, and that is kept.

   procedure Set_Notes (Self : in out View_Model; Row : Positive; Text, Stored : String)
     with Pre => Row <= Count (Self),
          Post => Notes (Self, Row) = Text;
   --  Its notes are Text, which Stored is the marked up form of, and that is kept.

   procedure Set_Colour (Self : in out View_Model; Row : Positive; Colour : Sections.Colour_Value)
     with Pre => Row <= Count (Self),
          Post => Section_At (Self, Row).Colour = Colour;

   procedure Move (Self : in out View_Model; From, To : Positive)
     with Pre  => From <= Count (Self) and then To <= Count (Self),
          Post => Sections."=" (Section_At (Self, To).Key, Section_At (Self, From)'Old.Key);
   --  Put the From-th section at the To-th, the rest in order, and keep that.

   overriding function Version (Self : View_Model) return Parts.Version_Number;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Add_Section: a project is entered. Of the others, for the row Index (0 for any): Move_Up, if it is not
   --  the first; Move_Down, if it is not the last; Remove_Section and Toggle_Notes, if there is such a row.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0);
   --  A row that cannot be so done by is refused by the precondition.

private

   type Library_Access is access all Library'Class;

   type View_Model is limited new Commands.Model with record
      Kept    : Library_Access;
      Owner   : Projects.Id := 0;
      Title   : Projects.Titles.Text;
      Words   : Projects.Titles.Text;
      Order   : aliased Sections.Section_List;
      Links   : aliased Sections.Link_List;
      Changes : Parts.Change_Counter;
   end record;

end Outline_VM;
