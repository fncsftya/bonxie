--  The outline view: the form of the title and description, and the blocks of its sections.
private package View.Build.Outline_View is

   procedure Build_Outline (Item : in out Session);
   --  Add and style the outline view's widgets.

   procedure Make_Block (Item : in out Session; Index : Positive);
   --  Add and style the block of a section, in the outline.

end View.Build.Outline_View;
