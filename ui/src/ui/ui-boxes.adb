package body UI.Boxes is

   use SDL3.Windows.Renderers;

   Dash : constant Float := 4.0;
   Gap  : constant Float := 3.0;
   --  In points, of a dashed outline.

   procedure Outline
     (Target  : SDL3.Windows.Renderers.Renderer;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Thick   : Float;
      Dashed  : Boolean := False;
      Density : Float := 1.0)
   is
      procedure Across (Y : Float) is
         Place : Float := 0.0;
         Step  : constant Float := Float'Rounding ((Dash + Gap) * Density);
         Long  : constant Float := Float'Rounding (Dash * Density);
      begin
         if not Dashed then
            Fill_Rect (Target, Ink, Left, Y, Width, Thick);
            return;
         end if;
         while Place < Width loop
            Fill_Rect (Target, Ink, Left + Place, Y,
                       Float'Min (Long, Width - Place), Thick);
            Place := Place + Step;
         end loop;
      end Across;

      procedure Down (X : Float) is
         Place : Float := 0.0;
         Step  : constant Float := Float'Rounding ((Dash + Gap) * Density);
         Long  : constant Float := Float'Rounding (Dash * Density);
      begin
         if not Dashed then
            Fill_Rect (Target, Ink, X, Top, Thick, Height);
            return;
         end if;
         while Place < Height loop
            Fill_Rect (Target, Ink, X, Top + Place, Thick,
                       Float'Min (Long, Height - Place));
            Place := Place + Step;
         end loop;
      end Down;
   begin
      Across (Top);
      Across (Top + Height - Thick);
      Down (Left);
      Down (Left + Width - Thick);
   end Outline;

   procedure Draw
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Look;
      Left, Top, Width, Height : Float;
      Density : Float)
   is
      Off  : constant Float := Inset (Item, Density);
      Wide : constant Float := Width - Off;
      High : constant Float := Height - Off;
   begin
      if Item.Shadowed then
         Fill_Rect (Target, Item.Shadow, Left + Off, Top + Off, Wide, High);
      end if;
      if Item.Filled then
         Fill_Rect (Target, Item.Fill, Left, Top, Wide, High);
      end if;
      if Item.Bordered then
         Outline (Target, Item.Border, Left, Top, Wide, High, Edge (Density),
                  Item.Dashed, Density);
      end if;
   end Draw;

   procedure Bevel
     (Target  : SDL3.Windows.Renderers.Renderer;
      Light   : Themes.Color;
      Dark    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False)
   is
      Thick : constant Float := Edge (Density);
      Lit   : constant Themes.Color := (if Sunken then Dark else Light);
      Dim   : constant Themes.Color := (if Sunken then Light else Dark);
   begin
      if Width < 2.0 * Thick or else Height < 2.0 * Thick then
         return;
      end if;
      --  The foot and right over the ends of the top and left, as a
      --  light from the top left falls.
      Fill_Rect (Target, Lit, Left, Top, Width, Thick);
      Fill_Rect (Target, Lit, Left, Top, Thick, Height);
      Fill_Rect (Target, Dim, Left, Top + Height - Thick, Width, Thick);
      Fill_Rect (Target, Dim, Left + Width - Thick, Top, Thick, Height);
   end Bevel;

   procedure Raised_Face
     (Item    : Raised_Look;
      Left, Top, Width, Height : Float;
      Density : Float;
      Face_Left, Face_Top, Face_Width, Face_Height : out Float)
   is
      Room  : constant Float := Lift (Density);
      Moved : constant Float :=
        (if Item.Pressed and then not Item.Flat then Shift (Density)
         else 0.0);
   begin
      Face_Left := Left + Moved;
      Face_Top := Top + Moved;
      Face_Width := Float'Max (0.0, Width - Room);
      Face_Height := Float'Max (0.0, Height - Room);
   end Raised_Face;

   procedure Draw_Raised
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Raised_Look;
      Left, Top, Width, Height : Float;
      Density : Float)
   is
      Thick : constant Float := Edge (Density);
      X, Y, Wide, High : Float;
   begin
      Raised_Face (Item, Left, Top, Width, Height, Density, X, Y, Wide, High);
      Fill_Rect (Target, Item.Face, X, Y, Wide, High);
      Outline (Target, Item.Border, X, Y, Wide, High, Thick);
      if not Item.Flat then
         if Item.Edges_Given then
            Bevel (Target, Item.Lit, Item.Shaded, X + Thick, Y + Thick,
                   Wide - 2.0 * Thick, High - 2.0 * Thick, Density,
                   Sunken => Item.Pressed);
         else
            Bevel (Target, Themes.Highlight (Item.Face),
                   Themes.Shade (Item.Face), X + Thick, Y + Thick,
                   Wide - 2.0 * Thick, High - 2.0 * Thick, Density,
                   Sunken => Item.Pressed);
         end if;
      end if;
   end Draw_Raised;

end UI.Boxes;
