with SDL3.Windows.Renderers;

--  A small mark to say something of a thing, beside it: a count, white
--  in a dark square (as how many there are of what a button opens); or a
--  tag, faint small text in a tinted box, outlined (as when a source's
--  picture was taken). It takes no events.
package UI.Widgets.Badges is

   Text_Capacity : constant := 48;
   --  Bytes of a tag's text.

   type Kind is (Number, Tag);

   type Badge is new Widget with private;

   procedure Set_Kind (Item : in out Badge; To : Kind);

   procedure Set_Count (Item : in out Badge; To : Natural)
     with Post => Count_Of (Item) = To;
   --  Of a count: what it shows.

   function Count_Of (Item : Badge) return Natural;

   procedure Set_Text (Item : in out Badge; Value : String)
     with Pre => Value'Length <= Text_Capacity;
   --  Of a tag: what it says.

   function Text (Item : Badge) return String;

   function Natural_Width (Item : Badge) return Float
     with Pre => Is_Attached (Item);
   --  In points: as wide as what it shows, and its padding, as the tree's
   --  text measures it (a square, for a count of one figure).

   Count_Size : constant Float := 16.0;
   --  In points, a side of the square of a count; a tag is as high as its
   --  box.

   overriding procedure Draw
     (Item   : in out Badge;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

private

   type Badge is new Widget with record
      Form    : Kind := Number;
      Value   : Natural := 0;
      Content : String (1 .. Text_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Text_Capacity := 0;
   end record;

end UI.Widgets.Badges;
