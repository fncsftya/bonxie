with Publish_VM;
with Pomarine.UI.Contexts;

package Publish_UI is
   package Controls is new Pomarine.UI.Contexts (Publish_VM.Commands, Publish_VM.View_Model);
   Sections : constant Controls.Flag_Property := Controls.Showing (Publish_VM.Section_Headings'Access);
   Copy_Caption : constant Controls.Text_Property := Controls.Showing (Publish_VM.Copy_Caption'Access);
   Documents : constant Controls.Flag_Property := Controls.Showing (Publish_VM.Document_Headings'Access);

end Publish_UI;
