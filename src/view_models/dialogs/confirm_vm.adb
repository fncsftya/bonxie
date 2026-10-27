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

   function Subject (Self : View_Model) return Subjects
   is (Self.Asked.Subject);

   function Is_Asking (Self : View_Model) return Boolean
   is (Self.Asked.Subject /= Nothing);

   function Is_About_Node (Self : View_Model) return Boolean
   is (Self.Asked.Subject in Nodes);

   function Title (Self : View_Model) return String
   is (case Self.Asked.Subject is
         when Nothing | Project => "Delete project",
         when Folder            => "Delete folder",
         when Document          => "Delete document",
         when Source            => "Delete source",
         when Model             => "Delete model");

   function Message (Self : View_Model) return String
   is (case Self.Asked.Subject is
         when Nothing => "",
         when Model   => "Delete the Parakeet model?",
         when others  => "Delete " & Open_Quote & Unbounded.To_String (Self.Name) & Close_Quote & "?");

   function Note (Self : View_Model) return String
   is (case Self.Asked.Subject is
         when Nothing | Project | Document | Source => "This cannot be undone.",
         when Folder                                => "This also deletes all subfolders.",
         when Model                                 => Unbounded.To_String (Self.Size));

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
           when Confirm | Cancel => Is_Asking (Self));
   end Can_Execute;

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      Self.Given := (if What = Confirm then Self.Asked else (others => <>));
      Self.Asked := (others => <>);
      Parts.Bump (Self.Changes);
      if Self.Reactions /= null then
         Self.Reactions.Dialog_Changed;
         if What = Confirm then
            Self.Reactions.Answered (Self.Given);
         end if;
      end if;
   end Execute;

   function Last_Answer (Self : View_Model) return Answer
   is (Self.Given);

end Confirm_VM;
