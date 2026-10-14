with Items;
with Projects;
with Vision;

--  The table of the words found in sources' pictures, one row to a word.
package Repository.Word is

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none.

   procedure Replace
     (Store   : in out Projects.Store;
      Key     : Items.Id;
      Found   : Vision.Result;
      At_Time : Projects.Seconds;
      Version : Natural)
     with Pre => Projects.Is_Open (Store);
   --  Keep the words, in place of any kept before for the item, and say
   --  (see Repository.Item.Set_Recognized) that was at At_Time, as
   --  Version has them put in order. All or none are kept.

   procedure Load
     (Store : Projects.Store; Key : Items.Id; Into : in out Vision.Result)
     with Pre => Projects.Is_Open (Store);
   --  The words kept for the item, in order; none if there are none.

   procedure Delete (Store : in out Projects.Store; Key : Items.Id)
     with Pre => Projects.Is_Open (Store);
   --  The words kept for the item, and nothing of the item's row: see
   --  Repository.Item.Set_Recognized.

end Repository.Word;
