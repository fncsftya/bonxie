--  Tests of what an item is, alone: no window, no display, no event. See Goldens.
package Item_Model_Tests is

   procedure Notes;
   --  A note: its title and text as kept, the words, and how its dictation is told, until the text is changed.

   procedure Placing;
   --  Moving and sizing: where it is, not under the least, what the corner asked for, and when it is written.

   procedure Sources;
   --  A source: what it says as its picture stands, its pages, its zoom and tool, and the marks it keeps.

   procedure Writing;
   --  What is written, and when: not while it is being typed in, nor marked on, nor zoomed.

end Item_Model_Tests;
