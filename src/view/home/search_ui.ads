with Search_VM;
with Pomarine.UI.Contexts;

package Search_UI is
   package Controls is new Pomarine.UI.Contexts (Search_VM.Commands, Search_VM.View_Model);
   package Query is new Controls.Edit_Text (Search_VM.Term, Search_VM.Set_Term);
   package Summary is new Controls.Read_Text (Search_VM.Summary);
   package Showing is new Controls.Read_Flag (Search_VM.Is_Showing);
end Search_UI;
