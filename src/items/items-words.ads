with Projects;
with Vision;

--  The text found in a source's picture, kept in a table of its own, one
--  row to a word, that goes with the item.

package Items.Words is

   procedure Save_Words (Store : in out Projects.Store; Key : Id; Found : Vision.Result; At_Time : Projects.Seconds)
   with Pre => Projects.Is_Open (Store) and then At_Time > 0;
   --  Keep the words found in the source's picture, in place of any kept
   --  before, and say that was at At_Time. They are in a table of their
   --  own, one row to a word, that goes with the item. Nothing is done if
   --  there is no such item.

   function Has_Words (Store : Projects.Store; Key : Id) return Boolean
   with Pre => Projects.Is_Open (Store);
   --  Whether the text of the source's picture has been found and kept,
   --  even if there was none in it: so that it is not looked for again.

   procedure Load_Words (Store : Projects.Store; Key : Id; Into : in out Vision.Result)
   with Pre => Projects.Is_Open (Store);
   --  The words kept for the source, as Save_Words had them; none if
   --  there are none.

   procedure Clear_Words (Store : in out Projects.Store; Key : Id)
   with Pre => Projects.Is_Open (Store);
   --  Forget the words kept for the source, so that they are looked for
   --  again.

end Items.Words;
