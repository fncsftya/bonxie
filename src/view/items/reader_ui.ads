with Reader_VM;
with Pomarine.UI.Contexts;

package Reader_UI is
   package Controls is new Pomarine.UI.Contexts (Reader_VM.Commands, Reader_VM.Model);
   Zoom_Value : constant Controls.Fraction_Property :=
     Controls.Editing (Reader_VM.Zoom_Fraction'Access, Reader_VM.Set_Zoom_Fraction'Access);
   Pointer_Flag : constant Controls.Flag_Property := Controls.Showing (Reader_VM.Pointer_Selected'Access);
   Marker_Flag : constant Controls.Flag_Property := Controls.Showing (Reader_VM.Marker_Selected'Access);
   Eraser_Flag : constant Controls.Flag_Property := Controls.Showing (Reader_VM.Eraser_Selected'Access);

end Reader_UI;
