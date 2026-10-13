with Items;
with SDL3.Windows.Renderers;
with UI.Themes;
with UI.Widgets;

--  A picture of a project's canvas, small: its open items, where they are,
--  as white cards on a ground of dots, each with a line for its title (a
--  source's after a square of its colour) and a few for its text. It takes
--  no events, and fits all of them in its box.
package Previews is

   Max_Shown : constant := 12;
   --  Items drawn, the earliest made first; the rest are left out.

   type Preview is new UI.Widgets.Widget with private;

   type Card is record
      Where : Items.Frame;
      Kind  : Items.Kinds := Items.Note;
      Ink   : UI.Themes.Color := (0, 0, 0, 255);
      --  Of a source: its colour.
   end record;

   type Card_Array is array (Positive range <>) of Card;

   procedure Set_Cards (Item : in out Preview; To : Card_Array)
     with Pre => To'Length <= Max_Shown;
   --  Show these, in place of any before.

   procedure Clear (Item : in out Preview);
   --  Show none: the ground only.

   overriding procedure Draw
     (Item   : in out Preview;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : UI.Themes.Theme);

private

   type Preview is new UI.Widgets.Widget with record
      Count : Natural range 0 .. Max_Shown := 0;
      Cards : Card_Array (1 .. Max_Shown);
   end record;

end Previews;
