with SDL3.Windows.Renderers.Images;

--  Golden images: renders compared with what they should look like.
--
--  The golden images are golden/<name>.png, beside bin/. A mismatch
--  writes out/<name>-actual.png and out/<name>-diff.png: the differing
--  pixels red over a dimmed copy of the golden. With UPDATE_GOLDEN=1 in
--  the environment the goldens are written instead, from what is drawn
--  now: look at them first.
--
--  The renders are in software, the same every time on one machine, so
--  by default no pixel may differ. CoreText may rasterize a little
--  differently on another release of macOS: then loosen Tolerance or
--  Max_Differing for the test, or regenerate the goldens.
package Goldens is

   package Images renames SDL3.Windows.Renderers.Images;

   procedure Check
     (Name          : String;
      Actual        : Images.Image;
      Tolerance     : Natural := 0;
      Max_Differing : Natural := 0)
     with Pre => Name'Length > 0 and then not Images.Is_Empty (Actual);
   --  That Actual is the golden image Name: no more than Max_Differing
   --  pixels with a channel more than Tolerance (of 255) off.

   procedure Check_Same
     (Name          : String;
      Expected      : Images.Image;
      Actual        : Images.Image;
      Tolerance     : Natural := 0;
      Max_Differing : Natural := 0)
     with Pre => Name'Length > 0
                 and then not Images.Is_Empty (Expected)
                 and then not Images.Is_Empty (Actual);
   --  That two renders, which should look alike, do: as Check, against
   --  Expected rather than a golden. A mismatch also writes
   --  out/<name>-expected.png.

   function Passed return Natural;
   function Failed return Natural;

end Goldens;
