with Publish_VM;
with Pomarine.UI.Contexts;

package Publish_UI is
   package Controls is new Pomarine.UI.Contexts (Publish_VM.Commands, Publish_VM.View_Model);
   package Sections is new Controls.Read_Flag (Publish_VM.Section_Headings);
   package Copy_Caption is new Controls.Read_Text (Publish_VM.Copy_Caption);
   package Documents is new Controls.Read_Flag (Publish_VM.Document_Headings);
end Publish_UI;
