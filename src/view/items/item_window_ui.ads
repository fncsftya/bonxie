with Item_Window_VM;
with Pomarine.UI.Contexts;

package Item_Window_UI is
   package Controls is new Pomarine.UI.Contexts (Item_Window_VM.Commands, Item_Window_VM.Model);
   package Previous_Flag is new Controls.Read_Flag (Item_Window_VM.Previous_Allowed);
   package Next_Flag is new Controls.Read_Flag (Item_Window_VM.Next_Allowed);
   package Zoom_Value is new Controls.Edit_Fraction (Item_Window_VM.Zoom_Fraction, Item_Window_VM.Set_Zoom_Fraction);
   package Pointer_Flag is new Controls.Read_Flag (Item_Window_VM.Pointer_Selected);
   package Marker_Flag is new Controls.Read_Flag (Item_Window_VM.Marker_Selected);
   package Eraser_Flag is new Controls.Read_Flag (Item_Window_VM.Eraser_Selected);
end Item_Window_UI;
