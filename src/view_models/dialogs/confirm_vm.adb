package body Confirm_VM is

   package Unbounded renames Ada.Strings.Unbounded;

   Open_Quote  : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9C#)];
   Close_Quote : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9D#)];
   --  In UTF-8.

   procedure Ask (Self : in out View_Model; About : Answer; Name, Size : String) is
   begin
      Self.Asked := About;
      Self.Name := Unbounded.To_Unbounded_String (Name);
      Self.Size := Unbounded.To_Unbounded_String (Size);
      Parts.Bump (Self.Changes);
      if Self.Reactions /= null then
         Self.Reactions.Dialog_Changed;
      end if;
   end Ask;

   procedure Observe (Self : in out View_Model; Reactions : access Effects'Class) is
   begin
      Self.Reactions := (if Reactions = null then null else Reactions.all'Unrestricted_Access);
   end Observe;

   procedure Ask_Project (Self : in out View_Model; Key : Projects.Id; Name : String) is
   begin
      Ask (Self, (Subject => Project, Project_Key => Key, others => <>), Name, "");
   end Ask_Project;

   procedure Ask_Node (Self : in out View_Model; Kind : Nodes; Dir, Doc : Natural; Name : String) is
   begin
      Ask (Self, (Subject => Kind, Dir => Dir, Doc => Doc, others => <>), Name, "");
   end Ask_Node;

   procedure Ask_Model (Self : in out View_Model; Size : String) is
   begin
      Ask (Self, (Subject => Model, others => <>), "", Size);
   end Ask_Model;

   procedure Ask_Update (Self : in out View_Model; Words, Detail : String) is
   begin
      Ask (Self, (Subject => Update, others => <>), Words, Detail);
   end Ask_Update;

   procedure Ask_Updating (Self : in out View_Model; Words, Detail : String) is
   begin
      Ask (Self, (Subject => Updating, others => <>), Words, Detail);
   end Ask_Updating;

   procedure Ask_Update_Problem (Self : in out View_Model; Words, Detail : String) is
   begin
      Ask (Self, (Subject => Update_Problem, others => <>), Words, Detail);
   end Ask_Update_Problem;

   function Subject (Self : View_Model) return Subjects
   is (Self.Asked.Subject);

   function Is_Asking (Self : View_Model) return Boolean
   is (Self.Asked.Subject /= Nothing);

   function Is_Deletion (Self : View_Model) return Boolean
   is (Self.Asked.Subject in Deletions);

   function Is_Update_Offer (Self : View_Model) return Boolean
   is (Self.Asked.Subject = Update);

   function Is_Updating (Self : View_Model) return Boolean
   is (Self.Asked.Subject = Updating);

   function Is_Update_Problem (Self : View_Model) return Boolean
   is (Self.Asked.Subject = Update_Problem);

   function Is_About_Node (Self : View_Model) return Boolean
   is (Self.Asked.Subject in Nodes);

   function Title (Self : View_Model) return String
   is (case Self.Asked.Subject is
         when Nothing | Project => "Delete project",
         when Update            => "Update available",
         when Updating          => "Updating Bonxie",
         when Update_Problem    => "Update",
         when Folder            => "Delete folder",
         when Document          => "Delete document",
         when Source            => "Delete source",
         when Model             => "Delete model");

   function Message (Self : View_Model) return String
   is (case Self.Asked.Subject is
         when Nothing => "",
         when Model   => "Delete the speech model?",
         when Updates => Unbounded.To_String (Self.Name),
         when others  => "Delete " & Open_Quote & Unbounded.To_String (Self.Name) & Close_Quote & "?");

   function Note (Self : View_Model) return String
   is (case Self.Asked.Subject is
         when Nothing | Project | Document | Source => "This cannot be undone.",
         when Folder                                => "This also deletes all subfolders.",
         when Model | Updates                       => Unbounded.To_String (Self.Size));

   function Offers_Documents (Self : View_Model) return Boolean
   is (Self.Asked.Subject = Folder);

   function Delete_Documents (Self : View_Model) return Boolean
   is (Self.Asked.Delete_Documents);

   procedure Set_Delete_Documents (Self : in out View_Model; To : Boolean) is
   begin
      if Self.Asked.Delete_Documents /= To then
         Self.Asked.Delete_Documents := To;
         Parts.Bump (Self.Changes);
      end if;
   end Set_Delete_Documents;

   overriding
   function Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes));

   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      pragma Unreferenced (Index);
   begin
      return
        (case What is
           when Confirm => Is_Asking (Self) and then Self.Asked.Subject not in Updating | Update_Problem,
           when Cancel  => Is_Asking (Self),
           when Skip    => Self.Asked.Subject = Update);
   end Can_Execute;

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
      Passed_On : constant Boolean := What = Confirm or else Self.Asked.Subject in Updates;
   begin
      Self.Given := (if Passed_On then Self.Asked else (others => <>));
      Self.Given.Choice := What;
      Self.Asked := (others => <>);
      Parts.Bump (Self.Changes);
      if Self.Reactions /= null then
         Self.Reactions.Dialog_Changed;
         if Passed_On then
            Self.Reactions.Answered (Self.Given);
         end if;
      end if;
   end Execute;

   function Last_Answer (Self : View_Model) return Answer
   is (Self.Given);

end Confirm_VM;
