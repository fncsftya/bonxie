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

   type Position_Mode is (Static, Relative, Absolute);
   --  Absolute takes no room in its parent's layout, and is placed by its
   --  edges (Set_Position) from the parent's, over its other children.

   type Display_Mode is (Flex, None, Contents);
   --  None takes no room and shows nothing, nor do its children.

end Yoga;
