with Search_VM;
with Pomarine.UI.Contexts;

package Search_UI is
   package Controls is new Pomarine.UI.Contexts (Search_VM.Commands, Search_VM.View_Model);
   Query   : constant Controls.Text_Property := Controls.Editing (Search_VM.Term'Access, Search_VM.Set_Term'Access);
   Summary : constant Controls.Text_Property := Controls.Showing (Search_VM.Summary'Access);
   Showing : constant Controls.Flag_Property := Controls.Showing (Search_VM.Is_Showing'Access);

end Search_UI;
