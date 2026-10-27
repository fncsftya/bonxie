with Projects.Sections;
with Pomarine.Widgets.Grips;
with Pomarine.Themes;
with SDL3.Painters;
with Pomarine.Events;

--  Hue and brightness in a square, with saturation in the slider at its right.
--  Changes stay here until the owning popout's OK button keeps them.

package Section_Colour_Pickers is
   type Picker is new Pomarine.Widgets.Grips.Grip with private;
   function Colour (Item : Picker) return Projects.Sections.Colour_Value;
   function Changed (Item : Picker) return Boolean;
   procedure Set_Colour (Item : in out Picker; To : Pomarine.Themes.Color)
   with Pre => Natural (To.Alpha) = 255, Post => not Changed (Item);
   overriding
   procedure Handle (Item : in out Picker; Event : Pomarine.Events.Event; Handled : out Boolean);
   overriding
   procedure Draw (Item : in out Picker; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme);
private
   subtype Unit is Float range 0.0 .. 1.0;
   type Region is (None, Plane, Saturation);
   type Picker is new Pomarine.Widgets.Grips.Grip with record
      Hue        : Unit := 0.0;
      Brightness : Unit := 1.0;
      Purity     : Unit := 1.0;
      Selected   : Pomarine.Themes.Color := (255, 0, 0, 255);
      Original   : Pomarine.Themes.Color := (255, 0, 0, 255);
      Held       : Region := None;
   end record;
end Section_Colour_Pickers;
