with GNAT.OS_Lib;
with Icon_Set;
with Pomarine.Text_Areas;
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
