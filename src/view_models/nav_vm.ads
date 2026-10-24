with Confirm_VM;
with Home_VM;
with Outline_VM;
with Pomarine.View_Models;
with Projects;
with Settings_VM;

--  The view-model of where the person is: the home screen or a project, the view of the project (outline, canvas,
--  writing, publish), the project's name and renaming it, the list of the project's items, and which of the layers
--  over the screens (the settings, the list, the dialog that asks before deleting) takes the person's events. It names
--  no widget, so the tests run it without a window.
--
--  It does not hold the settings' or the dialog's state: it is given those view-models and answers from them (Layer),
--  so what is open is said once. Showing a screen, a view or the list is the view's, in reaction to the versions here
--  (see Viewer.Navigation).
package Nav_VM is

   package Parts renames Pomarine.View_Models;

   use type Projects.Id;

   type Screens is (Home, Project);

   type Modes is (Outline, Canvas, Write, Publish);
   --  The views of a project, in the order of their tabs, which is how the project's last is kept.

   type Command is
     (Start_Project,
      --  Make a project and open it.
      Open_Project,
      --  Index: the row of the home screen's list (Home_VM) of the one to open.
      Open_Settings,
      Close_Settings,
      Leave_Project,
      --  To the home screen. A name being typed is kept.
      Show_Outline,
      Show_Canvas,
      Show_Writing,
      Show_Publish,
      --  The view of the project; kept, to be the one it opens to. Showing the one that is shown is allowed.
      Open_List,
      Close_List,
      Begin_Rename,
      --  The project's name, to type over.
      Accept_Rename,
      Cancel_Rename,
      Dismiss);
      --  Put away the layer that is over the rest, as Escape does.

   package Commands is new Parts.Command_Models (Command);

   --  The projects kept.

   type Library is limited interface;

   function Create (Self : in out Library) return Projects.Id is abstract;
   --  A new, untitled project.

   function Tab (Self : Library; Key : Projects.Id) return Natural is abstract;
   --  The view last shown, as the position of its Modes; 0 if none has been.

   procedure Set_Tab (Self : in out Library; Key : Projects.Id; To : Natural) is abstract;

   type View_Model is limited new Commands.Model with private;

   procedure Initialize
     (Self     : in out View_Model;
      Kept     : not null access Library'Class;
      Recent   : not null access constant Home_VM.View_Model;
      Written  : not null access Outline_VM.View_Model;
      Settings : not null access Settings_VM.View_Model;
      Dialog   : not null access Confirm_VM.View_Model);
   --  Recent lists the projects Open_Project opens, and Written has the project's name and sections: opening a
   --  project enters it, and leaving lets go of it. All must be there as long as the view-model is. At the home
   --  screen, with nothing over it.

   --  Where

   function Screen (Self : View_Model) return Screens;

   function Mode (Self : View_Model) return Modes;
   --  The view shown: Canvas at the home screen.

   --  What takes the person's events

   type Layers is
     (Plain,
      --  The screen.
      Settings_Form,
      --  The settings, in the place of the home screen.
      Model_Dialog,
      --  The dialog about deleting the speech model, over the settings.
      Item_List,
      --  The list of the project's items.
      Deleting);
      --  The dialog that asks before a project, a folder, a document or a source is deleted.

   function Layer (Self : View_Model) return Layers;
   --  The topmost one.

   function Is_Over (Self : View_Model) return Boolean is (Layer (Self) /= Plain);

   function Project_Key (Self : View_Model) return Projects.Id
     with Post => (Project_Key'Result = 0) = (Screen (Self) = Home);
   --  The project shown; 0 at the home screen.

   function Name (Self : View_Model) return String;
   --  Its name, as the outline has it: "" at the home screen.

   function Name_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever the name is.

   procedure Open (Self : in out View_Model; Which : Projects.Id)
     with Pre  => Screen (Self) = Home and then Which /= 0,
          Post => Screen (Self) = Project and then Project_Key (Self) = Which and then Mode (Self) = Canvas;
   --  Go to the project, at the canvas: Restore_Mode then goes to the view it was left at, once the screen is
   --  ready for it.

   procedure Restore_Mode (Self : in out View_Model)
     with Pre => Screen (Self) = Project;
   --  Show the view the project was left at, which is not kept again.

   function Is_Listing (Self : View_Model) return Boolean;
   --  Whether the list of the project's items is up.

   function Is_Renaming (Self : View_Model) return Boolean;

   function Draft (Self : View_Model) return String;
   --  The name being typed.

   procedure Set_Draft (Self : in out View_Model; Text : String)
     with Post => Draft (Self) = Text;

   function Takes_Gestures (Self : View_Model) return Boolean;
   --  Whether the canvas, the writing view and the outline may be worked: at a project, with nothing over it.

   function Takes_Search (Self : View_Model) return Boolean;
   --  Whether a search may be begun: as Takes_Gestures, in the canvas or the writing view.

   --  What changed

   function Screen_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever a project is opened or left.

   function Mode_Version (Self : View_Model) return Parts.Version_Number;

   function Layer_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever the list or the settings are put up or away.

   function Renaming_Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever renaming begins or ends.

   overriding function Version (Self : View_Model) return Parts.Version_Number;
   --  Different whenever any of these are, or the draft.

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Start_Project, Open_Project (the row, Index, is listed; 0 asks whether any is) and Open_Settings: at the home
   --  screen, with nothing over it. Close_Settings: they are up, and the dialog over them is not. Leave_Project and the
   --  views: at a project. Open_List: at a project. Begin_Rename: at a project with nothing over it.
   --  Close_List: it is up. Accept_Rename and Cancel_Rename: a name is being typed. Dismiss: something is over the
   --  screen.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => (case What is
                      when Start_Project | Open_Project => Screen (Self) = Project,
                      when Leave_Project  => Screen (Self) = Home and then not Is_Renaming (Self),
                      when Show_Outline   => Mode (Self) = Outline,
                      when Show_Canvas    => Mode (Self) = Canvas,
                      when Show_Writing   => Mode (Self) = Write,
                      when Show_Publish   => Mode (Self) = Publish,
                      when Open_List      => Is_Listing (Self),
                      when Close_List     => not Is_Listing (Self),
                      when Begin_Rename   => Is_Renaming (Self),
                      when Accept_Rename | Cancel_Rename => not Is_Renaming (Self),
                      when others         => True);

private

   package Mode_Properties is new Parts.Properties (Modes);

   type Library_Access is access all Library'Class;
   type Recent_Access is access constant Home_VM.View_Model;
   type Outline_Access is access all Outline_VM.View_Model;
   type Settings_Access is access all Settings_VM.View_Model;
   type Dialog_Access is access all Confirm_VM.View_Model;

   type View_Model is limited new Commands.Model with record
      Kept      : Library_Access;
      Recent    : Recent_Access;
      Outline   : Outline_Access;
      Settings  : Settings_Access;
      Dialog    : Dialog_Access;
      Shown     : Screens := Home;
      Current   : Projects.Id := 0;
      Viewing   : Mode_Properties.Property;
      Listing   : Boolean := False;
      Renaming  : Boolean := False;
      Typed     : Parts.Text_Property;
      Epoch     : Parts.Change_Counter;
      --  Of opening and leaving a project.
      Overs     : Parts.Change_Counter;
      --  Of the list and the settings.
      Titles    : Parts.Change_Counter;
      --  Of renaming.
   end record;

end Nav_VM;
