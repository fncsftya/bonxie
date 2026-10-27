with Grammar_VM;
with Pomarine.UI.Contexts;

package Grammar_UI is
   package Controls is new Pomarine.UI.Contexts (Grammar_VM.Commands, Grammar_VM.View_Model);
   Correction : constant Controls.Text_Property :=
     Controls.Editing (Grammar_VM.Correction'Access, Grammar_VM.Set_Correction'Access);
   Prompt     : constant Controls.Text_Property := Controls.Showing (Grammar_VM.Prompt'Access);
   Entering   : constant Controls.Flag_Property := Controls.Showing (Grammar_VM.Is_Entering'Access);

end Grammar_UI;
