with Reader_VM;
with Pomarine.UI.Contexts;

package Reader_UI is
   package Controls is new Pomarine.UI.Contexts (Reader_VM.Commands, Reader_VM.Model);
   package Zoom_Value is new Controls.Edit_Fraction (Reader_VM.Zoom_Fraction, Reader_VM.Set_Zoom_Fraction);
   package Pointer_Flag is new Controls.Read_Flag (Reader_VM.Pointer_Selected);
   package Marker_Flag is new Controls.Read_Flag (Reader_VM.Marker_Selected);
   package Eraser_Flag is new Controls.Read_Flag (Reader_VM.Eraser_Selected);
end Reader_UI;
