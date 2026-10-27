package body Writing_VM.Actions is
   use type Nav_VM.Modes;
   use type Items.Kinds;
   use type Items.Models.Dictations;
   use type Parts.Version_Number;

   procedure Initialize
     (Self       : in out Page_Model;
      Navigation : not null access Nav_VM.View_Model;
      Tree       : not null access Trees.Tree_Model;
      Models     : not null access Items.Models.Tables.Table;
      Names      : not null access Naming_VM.Model;
      Surface    : not null access Effects'Class) is
   begin
      Self.Names := Names.all'Unrestricted_Access;
      Self.Navigation := Navigation.all'Unrestricted_Access;
      Self.Tree := Tree.all'Unrestricted_Access;
      Self.Models := Models.all'Unrestricted_Access;
      Self.Surface := Surface.all'Unrestricted_Access;
   end Initialize;

   overriding
   function Version (Self : Page_Model) return Parts.Version_Number
   is (Nav_VM.Version (Self.Navigation.all) + Trees.Version (Self.Tree.all));

   function Rank_Of (What : Command; Index : Natural) return Natural
   is (if What = Use_Tool then (if Index = 0 then 0 else (Index - 1) / Tools_Per_Page) else Index);
   --  Use_Tool's Index says the tool as well (Tool_Index).

   overriding
   function Can_Execute (Self : Page_Model; What : Command; Index : Natural := 0) return Boolean is
      Rank : constant Natural := Rank_Of (What, Index);
   begin
      if What = End_Page_Title then
         return Index in 1 .. Self.Models.Count and then Naming_VM.Is_Titling (Self.Names.all, Index);
      elsif not Nav_VM.Takes_Gestures (Self.Navigation.all) or else Nav_VM.Mode (Self.Navigation.all) /= Nav_VM.Write
      then
         return False;
      end if;
      case What is
         when Select_Row | Rename_Row =>
            return Index in 1 .. Trees.Count (Self.Tree.all);

         when End_Name_Edit           =>
            return Index = 0 and then Naming_VM.Is_Renaming_Name (Self.Names.all);

         when End_Source_Name_Edit    =>
            return Index = 0 and then Naming_VM.Source (Self.Names.all) /= 0;

         when others                  =>
            null;
      end case;
      if Rank not in 1 .. Trees.Page_Count (Self.Tree.all) then
         return False;
      end if;
      declare
         Slot : constant Items.Slot := Trees.Page_At (Self.Tree.all, Rank);
      begin
         return
           Slot <= Self.Models.Count
           and then Items.Models.Is_Assigned (Self.Models (Slot))
           and then Items.Models.Details (Self.Models (Slot)).Kind = Items.Note
           and then (What /= Toggle_Dictation
                     or else Items.Models.Dictation (Self.Models (Slot)) /= Items.Models.Transcribing)
           and then (What /= Begin_Page_Title or else not Naming_VM.Is_Titling (Self.Names.all, Rank));
      end;
   end Can_Execute;

   overriding
   procedure Execute (Self : in out Page_Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Open_Sources         =>
            Open_Sources (Self.Surface.all, Index);

         when Toggle_Dictation     =>
            Toggle_Dictation (Self.Surface.all, Trees.Page_At (Self.Tree.all, Index));

         when Use_Tool             =>
            Use_Tool (Self.Surface.all, Rank_Of (What, Index), (Index - 1) mod Tools_Per_Page + 1);

         when Follow_Link          =>
            Follow_Link (Self.Surface.all, Index);

         when Ask_Link             =>
            Ask_Link (Self.Surface.all, Index);

         when Begin_Page_Title     =>
            Begin_Page_Title (Self.Surface.all, Index);

         when End_Page_Title       =>
            End_Page_Title (Self.Surface.all, Index);

         when Open_Section_Menu    =>
            Open_Section_Menu (Self.Surface.all, Index);

         when Select_Row           =>
            Select_Row (Self.Surface.all, Index);

         when Rename_Row           =>
            Rename_Row (Self.Surface.all, Index);

         when End_Name_Edit        =>
            End_Name_Edit (Self.Surface.all);

         when End_Source_Name_Edit =>
            End_Source_Name_Edit (Self.Surface.all);
      end case;
   end Execute;
end Writing_VM.Actions;
