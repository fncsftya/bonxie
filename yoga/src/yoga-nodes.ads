private with Ada.Finalization;
private with System;

package Yoga.Nodes is

   type Tree is limited private;
   --  Owns a root node and every node created below it; all are freed
   --  when the Tree goes out of scope.

   type Node is private;
   --  Non-owning handle to a node in a Tree. Do not use after the Tree
   --  it came from has been finalized.

   function Root (Item : Tree) return Node;

   function New_Child (Parent : Node) return Node;
   --  Create a node and append it to Parent's children.

   --  Style

   procedure Set_Flex_Direction (Item : Node; Value : Flex_Direction);
   procedure Set_Justify_Content (Item : Node; Value : Justify);
   procedure Set_Align_Items (Item : Node; Value : Align);
   procedure Set_Align_Self (Item : Node; Value : Align);
   procedure Set_Wrap (Item : Node; Value : Wrap_Mode);
   procedure Set_Flex_Grow (Item : Node; Value : Float);
   procedure Set_Flex_Shrink (Item : Node; Value : Float);
   procedure Set_Width (Item : Node; Value : Float);
   procedure Set_Height (Item : Node; Value : Float);
   procedure Set_Margin (Item : Node; Side : Edge; Value : Float);
   procedure Set_Padding (Item : Node; Side : Edge; Value : Float);
   procedure Set_Gap (Item : Node; Which : Gutter; Value : Float);

   --  Layout

   procedure Calculate_Layout
     (Item             : Tree;
      Available_Width  : Float;
      Available_Height : Float);
   --  Compute the layout of the whole tree within the available size.

   function Left (Item : Node) return Float;
   function Top (Item : Node) return Float;
   function Width (Item : Node) return Float;
   function Height (Item : Node) return Float;
   --  Results of the last Calculate_Layout; Left/Top are relative to
   --  the node's parent.

private

   type Node is record
      Handle : System.Address := System.Null_Address;
   end record;

   type Tree is new Ada.Finalization.Limited_Controlled with record
      Root_Node : Node;
   end record;

   overriding procedure Initialize (Item : in out Tree);
   overriding procedure Finalize (Item : in out Tree);

end Yoga.Nodes;
