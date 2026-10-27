with Goldens;
with Pomarine.Words;
with Vision.Layout;
with Vision;

package body Layout_Tests is

   --  A page of two columns, with a line under both, as Vision finds it:
   --  a line at a time, down the page, the left of each before the right.

   procedure Columns is
      Page : Vision.Result;
      Used : Natural := 0;

      procedure Add (Text : String; Line : Positive; Left, Top : Float) is
      begin
         Page.Count := Page.Count + 1;
         Pomarine.Words.Reserve (Page, Page.Count, Used + Text'Length);
         Page.Text (Used + 1 .. Used + Text'Length) := Text;
         Page.Words (Page.Count) :=
           (Line   => Line,
            First  => Used + 1,
            Last   => Used + Text'Length,
            Left   => Left,
            Top    => Top,
            Width  => 0.1,
            Height => 0.01);
         Used := Used + Text'Length;
         Page.Length := Used;
      end Add;

      function Reading return String is
         Result : String (1 .. 200);
         Last   : Natural := 0;
      begin
         for Index in 1 .. Page.Count loop
            declare
               Text : constant String := Vision.Image (Page.Words (Index), Page);
               Mark : constant String :=
                 (if Index = 1 then "" elsif Page.Words (Index).Line = Page.Words (Index - 1).Line then " " else "/");
            begin
               Result (Last + 1 .. Last + Mark'Length + Text'Length) := Mark & Text;
               Last := Last + Mark'Length + Text'Length;
            end;
         end loop;
         return Result (1 .. Last);
      end Reading;
   begin
      --  Down the page, left then right, as a plain sort would have them.
      Add ("L1", 1, 0.05, 0.10);
      Add ("R1", 2, 0.55, 0.10);
      Add ("L2", 3, 0.05, 0.13);
      Add ("R2", 4, 0.55, 0.13);
      Add ("L3", 5, 0.05, 0.16);
      Add ("R3", 6, 0.55, 0.16);
      --  Across the page: no gutter in it.
      Add ("foot", 7, 0.05, 0.50);
      Add ("ends", 7, 0.16, 0.50);
      Add ("here", 7, 0.27, 0.50);
      Add ("past", 7, 0.38, 0.50);
      Add ("it", 7, 0.49, 0.50);
      Add ("far", 7, 0.60, 0.50);
      Vision.Layout.Reading_Order (Page, Aspect => 2.0);
      Goldens.Check_Text ("columns-read", "L1/L2/L3/R1/R2/R3/foot ends here past it far", Reading);

      --  A line Vision made of both columns is cut at the gutter.
      Page.Count := 0;
      Used := 0;
      Add ("L1", 1, 0.05, 0.10);
      Add ("R1", 1, 0.55, 0.10);
      Add ("L2", 2, 0.05, 0.13);
      Add ("R2", 2, 0.55, 0.13);
      Vision.Layout.Reading_Order (Page, Aspect => 2.0);
      Goldens.Check_Text ("columns-split", "L1/L2/R1/R2", Reading);

      --  One column is read down.
      Page.Count := 0;
      Used := 0;
      Add ("b", 2, 0.05, 0.20);
      Add ("a", 1, 0.05, 0.10);
      Add ("c", 3, 0.05, 0.30);
      Vision.Layout.Reading_Order (Page, Aspect => 2.0);
      Goldens.Check_Text ("columns-one", "a/b/c", Reading);
   end Columns;

end Layout_Tests;
