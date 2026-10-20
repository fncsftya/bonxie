with Growing;
with Projects;

--  The lines between a project's items. They go with the items.
package Items.Links is

   type Sides is (Top, Right, Bottom, Left);
   --  The edges of an item's window, a link joining at the middle of one.

   type Strokes is (Solid, Dots, Dashed);
   type Endings is (Plain, Arrow);

   Link_Color_Count : constant := 5;
   subtype Link_Colors is Positive range 1 .. Link_Color_Count;
   --  Which of the application's few colours a link is drawn in.

   type Link is record
      Key      : Id := 0;
      From, To : Id := 0;
      From_Side, To_Side : Sides := Top;
      Stroke   : Strokes := Solid;
      Ending   : Endings := Plain;
      --  What is at its To end.
      Color    : Link_Colors := 1;
   end record;
   --  A line between two items of a project, from the middle of one side
   --  of the window of From to the middle of one of To. An item has no
   --  link to itself, and two items at most one between them (in either
   --  direction).

   package Link_Lists is new Growing (Link);
   subtype Link_List is Link_Lists.List;
   --  The earliest made first.

   function Is_Linked
     (Store : Projects.Store; A, B : Id) return Boolean
     with Pre => Projects.Is_Open (Store);
   --  Whether there is a link between the items, whichever way round.

   procedure Add_Link
     (Store : in out Projects.Store; Made : Link; Added : out Boolean)
     with Pre => Projects.Is_Open (Store) and then Made.From /= Made.To;
   --  Keep a link, if the items are not linked already, and say whether
   --  it was. They must be items of one project.

   procedure Delete_Link (Store : in out Projects.Store; Key : Id)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Link_Style
     (Store  : in out Projects.Store;
      Key    : Id;
      Stroke : Strokes;
      Ending : Endings;
      Color  : Link_Colors)
     with Pre => Projects.Is_Open (Store);

   procedure Move_Link
     (Store : in out Projects.Store;
      Key   : Id;
      To    : Id;
      Side  : Sides;
      Moved : out Boolean)
     with Pre => Projects.Is_Open (Store);
   --  Make the link end at the Side of To, which is not the item it
   --  starts from, if that is not joined by another link to it.

   procedure Load_Links
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Link_List)
     with Pre => Projects.Is_Open (Store);
   --  The links between the project's items. They go with the items.

end Items.Links;
