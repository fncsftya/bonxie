with Items;
with Pomarine.Boxes;
with SDL3.Painters;
with Pomarine.Themes;
with Pomarine.Widgets;

--  A picture of a project's canvas, small: its open items, where they are,
--  as white cards on a ground of dots, each with a line for its title (a
--  source's after a square of its colour) and a few for its text. It takes
--  no events, and fits all of them in its box.
package Previews is

   Max_Shown : constant := 12;
   --  Items drawn, the earliest made first; the rest are left out.

   type Preview is new Pomarine.Widgets.Widget with private;

   type Card is record
      Where : Items.Frame;
      Kind  : Items.Kinds := Items.Note;
      Ink   : Pomarine.Themes.Slot := Pomarine.Themes.Foreground;
      --  Of a source: its colour.
   end record;

   type Card_Array is array (Positive range <>) of Card;

   procedure Set_Cards (Item : in out Preview; To : Card_Array)
     with Pre => To'Length <= Max_Shown;
   --  Show these, in place of any before.

   procedure Set_Corners
     (Item : in out Preview; Radius : Float; Round : Pomarine.Boxes.Corner_Flags)
     with Pre => Radius >= 0.0;
   --  Cut the corners in Round of its ground by a circle of Radius points, as the corners of the box
   --  it is in are: a square one would show beyond the box's rounded outline.

   procedure Clear (Item : in out Preview);
   --  Show none: the ground only.

   overriding procedure Draw
     (Item   : in out Preview;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme);

private

   type Preview is new Pomarine.Widgets.Widget with record
      Radius : Float := 0.0;
      Round : Pomarine.Boxes.Corner_Flags := Pomarine.Boxes.All_Corners;
      Count : Natural range 0 .. Max_Shown := 0;
      Cards : Card_Array (1 .. Max_Shown);
   end record;

end Previews;
