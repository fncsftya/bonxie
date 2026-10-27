with Editor_VM;
with Pomarine.Text_Areas;
with Items.Windows.Displays;

package body Items.Windows.Speaking is
   package Widgets renames Pomarine.Widgets;
   package Editors renames Pomarine.Widgets.Editors;
   package Areas renames Pomarine.Text_Areas;

   function Typing_In (Item : Window) return access Editors.Editor
   is (if Item.Dictate_In /= null then Item.Dictate_In else Item.Body_Text'Unrestricted_Access);

   type Window_Editor is limited new Editor_VM.Editor with record
      Owner : access Window;
   end record;
   overriding
   function Focused (Self : Window_Editor) return Boolean;
   overriding
   function Caret (Self : Window_Editor) return Texts.Position;
   overriding
   function Mark (Self : Window_Editor) return Texts.Position;
   overriding
   procedure Select_Range (Self : in out Window_Editor; From, To : Texts.Position);
   overriding
   procedure Insert (Self : in out Window_Editor; Text : String);
   overriding
   procedure Set_Faint (Self : in out Window_Editor; From, To : Texts.Position);
   overriding
   procedure Clear_Faint (Self : in out Window_Editor);

   overriding
   function Focused (Self : Window_Editor) return Boolean
   is (Widgets.Has_Focus (Typing_In (Self.Owner.all).all));
   overriding
   function Caret (Self : Window_Editor) return Texts.Position
   is (Areas.Caret (Editors.Area (Typing_In (Self.Owner.all).all).all));
   overriding
   function Mark (Self : Window_Editor) return Texts.Position
   is (Areas.Mark (Editors.Area (Typing_In (Self.Owner.all).all).all));
   overriding
   procedure Select_Range (Self : in out Window_Editor; From, To : Texts.Position) is
   begin
      Areas.Select_Range (Editors.Area (Typing_In (Self.Owner.all).all).all, From, To);
   end Select_Range;
   overriding
   procedure Insert (Self : in out Window_Editor; Text : String) is
   begin
      Areas.Insert (Editors.Area (Typing_In (Self.Owner.all).all).all, Text);
   end Insert;
   overriding
   procedure Set_Faint (Self : in out Window_Editor; From, To : Texts.Position) is
   begin
      Areas.Set_Faint (Editors.Area (Typing_In (Self.Owner.all).all).all, From, To);
   end Set_Faint;
   overriding
   procedure Clear_Faint (Self : in out Window_Editor) is
      Item : Window renames Self.Owner.all;
   begin
      Areas.Clear_Faint (Editors.Area (Item.Body_Text).all);
      if Item.Dictate_In /= null then
         Areas.Clear_Faint (Editors.Area (Item.Dictate_In.all).all);
      end if;
   end Clear_Faint;

   procedure Change (Item : in out Window; To : Items.Models.Dictations; Detail : String := "") is
      View : Window_Editor;
   begin
      View.Owner := Item'Unrestricted_Access;
      Items.Models.Change_Dictation (Item.Model.all, View, To, Detail);
      Displays.Show_Status (Item);
   end Change;

   procedure Show_Live (Item : in out Window; Said : String; Settled : Natural := 0) is
      View : Window_Editor;
   begin
      View.Owner := Item'Unrestricted_Access;
      Editor_VM.Show_Live (Items.Models.Editor (Item.Model.all).all, View, Said, Settled);
   end Show_Live;

   procedure Append_Said (Item : in out Window; Said : String) is
      View : Window_Editor;
   begin
      View.Owner := Item'Unrestricted_Access;
      Editor_VM.Append_Said (Items.Models.Editor (Item.Model.all).all, View, Said);
   end Append_Said;
end Items.Windows.Speaking;
