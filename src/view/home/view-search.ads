private package View.Search is
   function Valid (Item : Session; Where : Search_VM.Context) return Boolean;
   procedure Refresh_Engine
     (Item : in out Session; Where : Search_VM.Context; Term : String; Found : out Search_VM.Result);
   procedure Step_Engine (Item : in out Session; Where : Search_VM.Context; Backwards : Boolean);
   procedure Clear_Engine (Item : in out Session; Where : Search_VM.Context);

   procedure Build (Item : in out Session);
   procedure Handle (Item : in out Session; Event : Pomarine.Events.Event; Handled : out Boolean);
   procedure Update (Item : in out Session);
   procedure Reveal (Item : in out Session);
   procedure Close (Item : in out Session);
end View.Search;
