--  Tests of the outline view, as a person would use it: the title and
--  description of the project, and its sections, in an order that can be
--  changed, all kept. See Goldens.
package Outline_Tests is

   procedure Starting;
   procedure Sections;
   procedure Form;
   procedure Generating;
   --  Generate Sections: the button, and what is done with replies.
   procedure Replies;
   procedure Naming;
   --  Linking gives an item without a name of its own the section's.
   procedure Menu_Fitting;
   --  The menu with long titles, many sections, and little room.
   procedure Linking;
   --  Link to Outline: the menu, the colours, and what is kept.

end Outline_Tests;
