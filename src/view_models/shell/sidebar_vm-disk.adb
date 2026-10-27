with Preferences;

package body Sidebar_VM.Disk is
   use Ada.Strings.Unbounded;
   function Name (Which : Section) return String is
     (case Which is when Edit => "edit", when Documents => "documents", when Sources => "sources");

   procedure Open (Self : in out File_Store; Config : String) is
   begin
      Self.Config := To_Unbounded_String (Config);
   end Open;

   overriding function Load (Self : File_Store) return Open_Sections is
     ([for Which in Section => Preferences.Load_Section_Open (To_String (Self.Config), Name (Which))]);

   overriding procedure Save (Self : in out File_Store; Value : Open_Sections) is
   begin
      for Which in Section loop
         Preferences.Save_Section_Open (To_String (Self.Config), Name (Which), Value (Which));
      end loop;
   end Save;
end Sidebar_VM.Disk;
