--  Tests of the writing view, as a person would use it: the documents on
--  pages, in an order that can be changed and is kept; sources opened and
--  pinned; text typed on a page or on the canvas. See Goldens.

package Write_Tests is

   procedure Searching;
   procedure Pages;
   procedure Ordering;
   procedure Dragging;
   procedure Directories;
   procedure Many_Directories;
   procedure Context_Menus;
   procedure Context_Menus_Elsewhere;
   procedure Context_Menus_On_Canvas;
   procedure Adding;
   procedure Linked_Sources;
   procedure Typing;
   procedure Word_Tools;
   --  Fade and Reword on a page, by their keys: kept in the markup, and
   --  through the project being closed and opened.
   procedure Thesaurus;
   --  The context menu's Thesaurus rewords the selected word, and is off for more than one.
   procedure Publishing;
   --  Choosing Markdown in the publish view splits it.
   procedure Markdown;
   --  What the rich text features become in Markdown.
   procedure Sources;
   procedure Sharing_Marks;
   procedure Source_Documents;

end Write_Tests;
