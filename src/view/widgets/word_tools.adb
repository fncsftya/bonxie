with GNAT.OS_Lib;
with Icon_Set;
with Pomarine.Text_Areas;
with Texts;
with Texts.Documents;

package body Word_Tools is

   package Editors renames Pomarine.Widgets.Editors;

   procedure Add (Item : in out Pomarine.Widgets.Editors.Editor) is
   begin
      Editors.Set_Edit_Icon (Item, Editors.Bulleted, Icon_Set.List_Bullet);
      Editors.Set_Edit_Icon (Item, Editors.Numbered, Icon_Set.Numbered_List);
      --  The drawings in dedent.svg and indent.svg are the other way about (the arrow of dedent.svg points
      --  into the text), so the buttons take them by what they show.
      Editors.Set_Edit_Icon (Item, Editors.Outdent, Icon_Set.Indent);
      Editors.Set_Edit_Icon (Item, Editors.Indent, Icon_Set.Dedent);
      Editors.Set_Edit_Icon (Item, Editors.Link, Icon_Set.Link);
      Pomarine.Widgets.Editors.Add_Tool (Item, "Fade", Key => 'd', Needs_Selection => True);
      Pomarine.Widgets.Editors.Add_Tool (Item, "Reword", Key => 'r', Needs_Selection => True);
   end Add;

   procedure Use_Tool (Source : in out Pomarine.Widgets.Widget'Class; Tool : Natural) is
      Item : Editors.Editor'Class renames Editors.Editor'Class (Source);
   begin
      if not Editors.Has_Document (Item) then
         return;
      elsif Tool = Fade then
         Pomarine.Text_Areas.Toggle_Format (Editors.Area (Item).all, Texts.Documents.Faded);
         Pomarine.Widgets.Invalidate (Item);
      elsif Tool = Reword then
         Editors.Begin_Version (Item);
      end if;
   end Use_Tool;

   Longest_Word   : constant := 64;
   --  Of what is looked up (Harper.Max_Word).
   Longest_Phrase : constant := 3;
   --  Words of it.

   procedure Find_Word
     (Item : in out Editors.Editor; From, To : out Texts.Position; State : out Thesaurus_States; Word : out Natural);
   --  Where the selected word is, if State is One_Word; Word is then its length.

   procedure Find_Word
     (Item : in out Editors.Editor; From, To : out Texts.Position; State : out Thesaurus_States; Word : out Natural)
   is
      use type Texts.Position;
      Area : Pomarine.Text_Areas.Text_Area renames Editors.Area (Item).all;
      Doc  : constant Texts.Documents.Document_Access := Pomarine.Text_Areas.Document (Area);
   begin
      From := Pomarine.Text_Areas.Caret (Area);
      To := Pomarine.Text_Areas.Mark (Area);
      Word := 0;
      State := Unavailable;
      if not Pomarine.Text_Areas.Has_Selection (Area)
        or else Pomarine.Text_Areas.Is_Read_Only (Area)
        or else Pomarine.Text_Areas.Is_Composing (Area)
      then
         return;
      end if;
      State := Several_Words;
      if To < From then
         declare
            Swap : constant Texts.Position := From;
         begin
            From := To;
            To := Swap;
         end;
      end if;
      if From.Paragraph /= To.Paragraph then
         return;
      end if;
      declare
         Selected : constant String := Texts.Documents.Between (Doc.all, From, To);
         First    : Positive := Selected'First;
         Last     : Natural := Selected'Last;
      begin
         while First <= Last and then Selected (First) in ' ' | ASCII.HT loop
            First := First + 1;
         end loop;
         while Last >= First and then Selected (Last) in ' ' | ASCII.HT loop
            Last := Last - 1;
         end loop;
         --  A word is letters, digits, and an apostrophe or hyphen inside it; any byte of UTF-8
         --  beyond ASCII is taken to be a letter. Up to Longest_Phrase words, a space between each.
         if First > Last or else Last - First + 1 > Longest_Word then
            return;
         end if;
         declare
            Spaces : Natural := 0;
         begin
            for Each in First .. Last loop
               declare
                  C : constant Character := Selected (Each);
               begin
                  if C = ' ' then
                     Spaces := Spaces + 1;
                     if Selected (Each - 1) = ' ' then
                        return;
                     end if;
                  elsif C not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | ''' | '-' and then C < Character'Val (128) then
                     return;
                  end if;
               end;
            end loop;
            if Spaces >= Longest_Phrase or else Selected (First) in ''' | '-' or else Selected (Last) in ''' | '-' then
               return;
            end if;
         end;
         To := (Paragraph => From.Paragraph, Index => From.Index + (Last - Selected'First + 1));
         From := (Paragraph => From.Paragraph, Index => From.Index + (First - Selected'First));
         Word := Last - First + 1;
      end;
      --  Text with versions is one word only if that is all of it.
      declare
         Run : constant Natural := Texts.Documents.Version_Overlapping (Doc.all, From, To);
      begin
         if Run /= 0
           and then not (Texts.Documents.Run (Doc.all, Run).From = From
                         and then Texts.Documents.Run (Doc.all, Run).To = To)
         then
            return;
         end if;
      end;
      State := One_Word;
   end Find_Word;

   function Thesaurus_State (Item : in out Pomarine.Widgets.Editors.Editor) return Thesaurus_States is
      From, To : Texts.Position;
      State    : Thesaurus_States;
      Word     : Natural;
   begin
      Find_Word (Item, From, To, State, Word);
      return State;
   end Thesaurus_State;

   function Selected_Word (Item : in out Pomarine.Widgets.Editors.Editor) return String is
      From, To : Texts.Position;
      State    : Thesaurus_States;
      Word     : Natural;
   begin
      Find_Word (Item, From, To, State, Word);
      if State /= One_Word then
         return "";
      end if;
      return Texts.Documents.Between (Pomarine.Text_Areas.Document (Editors.Area (Item).all).all, From, To);
   end Selected_Word;

   procedure Use_Synonym (Item : in out Pomarine.Widgets.Editors.Editor; Word : String) is
      From, To : Texts.Position;
      State    : Thesaurus_States;
      Length   : Natural;
   begin
      Find_Word (Item, From, To, State, Length);
      if State = One_Word then
         Pomarine.Text_Areas.Add_Version (Editors.Area (Item).all, From, To, Texts.Documents.Escaped (Word));
         Pomarine.Widgets.Invalidate (Item);
      end if;
   end Use_Synonym;

   procedure Follow (Source : in out Pomarine.Widgets.Widget'Class) is
      Address : constant String := Editors.Followed (Editors.Editor'Class (Source));
      Opener  : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("open");
      Args    : GNAT.OS_Lib.Argument_List (1 .. 2);
      Pid     : GNAT.OS_Lib.Process_Id;
      use type GNAT.OS_Lib.String_Access;
   begin
      if Opener /= null and then Pomarine.Text_Areas.Is_Address (Address) then
         Args := [new String'("--"), new String'(Address)];
         Pid := GNAT.OS_Lib.Non_Blocking_Spawn (Opener.all, Args);
         pragma Unreferenced (Pid);
         GNAT.OS_Lib.Free (Args (1));
         GNAT.OS_Lib.Free (Args (2));
      end if;
      GNAT.OS_Lib.Free (Opener);
   end Follow;

end Word_Tools;
