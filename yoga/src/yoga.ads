--  Ada-style interface to the Yoga flexbox layout engine.
--  The C binding is hidden in Yoga.Thin.
package Yoga is

   type Flex_Direction is (Column, Column_Reverse, Row, Row_Reverse);

   type Justify is
     (Flex_Start, Center, Flex_End, Space_Between, Space_Around,
      Space_Evenly);

   type Align is
     (Auto, Flex_Start, Center, Flex_End, Stretch, Baseline, Space_Between,
      Space_Around, Space_Evenly);

   type Wrap_Mode is (No_Wrap, Wrap, Wrap_Reverse);

   type Edge is
     (Left, Top, Right, Bottom, Start, Edge_End, Horizontal, Vertical,
      All_Edges);

   type Gutter is (Column, Row, All_Gutters);

end Yoga;
