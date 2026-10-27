--  Where words are read from, on a page that is not one column: lines
--  are cut apart at the empty gutters between columns and the gaps
--  between bands (an "XY-cut"), and read down each column in turn.

package Vision.Layout is

   procedure Reading_Order (Item : in out Result; Aspect : Float)
   with Pre => Aspect > 0.0;
   --  Put Item's words in reading order and number their lines again: a
   --  line is a run of words side by side with no gutter in it. The
   --  words are as they were found, in lines of words left to right (a
   --  line's are together). Aspect is the picture's height over its
   --  width, so that distances across and down can be compared, as the
   --  words' boxes are fractions of each.

end Vision.Layout;
