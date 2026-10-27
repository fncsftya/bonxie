--  The sources listed beside the pages of the writing view, and the one
--  pinned: for tests.

package View.Sources is

   function Source_Count (Item : Session) return Natural
   with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many sources there are, listed beside the pages.

   function Source_Title (Item : Session; Row : Positive) return String
   with Pre => Is_Open (Item) and then Screen (Item) = Project and then Row <= Source_Count (Item);

   function Source_Is_Open (Item : Session; Row : Positive) return Boolean
   with Pre => Is_Open (Item) and then Screen (Item) = Project and then Row <= Source_Count (Item);
   --  Whether the Rowth source has a window in the writing view, or is
   --  pinned.

   function Source_Marks (Item : Session; Row : Positive) return Natural
   with Pre => Is_Open (Item) and then Screen (Item) = Project and then Row <= Source_Count (Item);
   --  How many highlights the Rowth source's picture has in the writing
   --  view.

   function Pinned_Source (Item : Session) return Natural
   with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Which of the sources is pinned, 0 if none.

end View.Sources;
