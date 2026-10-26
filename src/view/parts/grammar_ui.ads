with Grammar_VM;
with Pomarine.UI.Contexts;

package Grammar_UI is
   package Controls is new Pomarine.UI.Contexts (Grammar_VM.Commands, Grammar_VM.View_Model);
   package Correction is new Controls.Edit_Text (Grammar_VM.Correction, Grammar_VM.Set_Correction);
   package Prompt is new Controls.Read_Text (Grammar_VM.Prompt);
   package Entering is new Controls.Read_Flag (Grammar_VM.Is_Entering);
end Grammar_UI;
