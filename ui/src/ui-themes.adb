package body UI.Themes is

   function Mix (From, To : Color; Amount : Float) return Color is
      subtype Component is SDL3.Windows.Renderers.Color_Component;

      function Channel (A, B : Component) return Component is
        (Component
           (Float'Rounding
              (Float (A) + (Float (B) - Float (A)) * Amount)));
   begin
      return (Red   => Channel (From.Red, To.Red),
              Green => Channel (From.Green, To.Green),
              Blue  => Channel (From.Blue, To.Blue),
              Alpha => Channel (From.Alpha, To.Alpha));
   end Mix;

end UI.Themes;
