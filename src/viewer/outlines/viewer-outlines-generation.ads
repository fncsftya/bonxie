with Pomarine.Themes;

--  Writing sections with the language model: its menu, the tries made, and the sections it gave.
private package Viewer.Outlines.Generation is

   use type Projects.Id;

   package Widgets renames Pomarine.Widgets;

   procedure Show_Note (Item : in out Session; Words : String; Ink : Pomarine.Themes.Slot);
   --  Say Words, as much as fits, under the heading in Ink; nothing if "".

   procedure Show_Generate (Item : in out Session);
   --  The button is on while AI is on and the model is not being asked.

   procedure Place_Menu (Item : in out Session);
   --  Put the menu under the button, its right edge by the button's.

   procedure Start_Try (Item : in out Session);
   --  Ask the model, thinking first, for the outline.

   procedure Give_Up (Item : in out Session; Words : String);
   --  The work is over, and did not come out: say why.

   procedure Finish_Try (Item : in out Session);
   --  The model has replied: use the sections, or ask again.

   procedure Apply (Item : in out Session; Wanted : Projects.Sections.Section_List)
     with Pre => Item.Opened.Current /= 0 and then Wanted.Count > 0;
   --  Make the outline the sections of Wanted, in order. A section that is
   --  already there, by its title, is kept, as it is; those the model left
   --  out go after the rest, and are not lost.

   procedure Generate_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

end Viewer.Outlines.Generation;
