with Item_Window_VM;
with Pomarine.UI.Contexts;

package Item_Window_UI is
   package Controls is new Pomarine.UI.Contexts (Item_Window_VM.Commands, Item_Window_VM.Model);
   Previous_Flag : constant Controls.Flag_Property := Controls.Showing (Item_Window_VM.Previous_Allowed'Access);
   Next_Flag : constant Controls.Flag_Property := Controls.Showing (Item_Window_VM.Next_Allowed'Access);
   Zoom_Value : constant Controls.Fraction_Property :=
     Controls.Editing (Item_Window_VM.Zoom_Fraction'Access, Item_Window_VM.Set_Zoom_Fraction'Access);
   Pointer_Flag : constant Controls.Flag_Property := Controls.Showing (Item_Window_VM.Pointer_Selected'Access);
   Marker_Flag : constant Controls.Flag_Property := Controls.Showing (Item_Window_VM.Marker_Selected'Access);
   Eraser_Flag : constant Controls.Flag_Property := Controls.Showing (Item_Window_VM.Eraser_Selected'Access);

end Item_Window_UI;
