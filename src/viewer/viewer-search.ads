private package Viewer.Search is
   procedure Build (Item : in out Session);
   procedure Handle (Item : in out Session; Event : Pomarine.Events.Event; Handled : out Boolean);
   procedure Update (Item : in out Session);
   procedure Reveal (Item : in out Session);
   procedure Close (Item : in out Session);
end Viewer.Search;
