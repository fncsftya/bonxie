package body UI.Widgets.Labels is

   use SDL3.Windows.Renderers;

   procedure Set_Text (Item : in out Label; Value : String) is
   begin
      if Value /= Text (Item) then
         Item.Length := Value'Length;
         Item.Content (1 .. Item.Length) := Value;
         Item.Fit_Width := -1.0;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Text;

   procedure Set_Style (Item : in out Label; To : Line_Texts.Style) is
      use type Line_Texts.Style;
   begin
      if To /= Item.Using then
         Item.Using := To;
         Item.Fit_Width := -1.0;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Style;

   procedure Set_Ink (Item : in out Label; To : Themes.Color) is
   begin
      if not Item.Inked or else Item.Ink /= To then
         Item.Inked := True;
         Item.Ink := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Ink;

   procedure Set_Centered (Item : in out Label; To : Boolean) is
   begin
      if To /= Item.Centered then
         Item.Centered := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Centered;

   procedure Set_Trailing (Item : in out Label; To : Boolean) is
   begin
      if To /= Item.Trailing then
         Item.Trailing := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Trailing;

   procedure Set_Scale (Item : in out Label; To : Float) is
   begin
      if To /= Item.Scaled then
         Item.Scaled := To;
         Item.Fit_Width := -1.0;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Scale;

   function Style (Item : Label) return Line_Texts.Style is (Item.Using);

   function Text (Item : Label) return String is
     (Item.Content (1 .. Item.Length));

   Ellipsis : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   --  In UTF-8.

   procedure Fit (Item : in out Label);
   --  Find how much of the text fits its box, as it is now.

   procedure Fit (Item : in out Label) is
      Scale : constant Float := Density (Item) * Item.Scaled;
      Room  : constant Float := Width_Of (Item);

      function Wide (Length : Natural; Cut : Boolean) return Float is
        (Line_Texts.Width
           (Text_Lines (Item).all,
            Item.Content (1 .. Length) & (if Cut then Ellipsis else ""),
            Scale, Item.Using));

      function Starts_Character (Index : Positive) return Boolean is
        (Character'Pos (Item.Content (Index)) not in 16#80# .. 16#BF#);
      --  Not a continuation byte of UTF-8: a place to cut before.

      Fits, Over : Natural;
   begin
      Item.Fit_Width := Room;
      Item.Fit_Length := Item.Length;
      Item.Fit_Cut := False;
      if Wide (Item.Length, Cut => False) <= Room then
         return;
      end if;
      --  The longest that fits, with the ellipsis: by halves, in bytes,
      --  and then back to where a character starts.
      Fits := 0;
      Over := Item.Length;
      while Over - Fits > 1 loop
         declare
            Middle : constant Natural := (Fits + Over) / 2;
         begin
            if Wide (Middle, Cut => True) <= Room then
               Fits := Middle;
            else
               Over := Middle;
            end if;
         end;
      end loop;
      while Fits > 0 and then Fits < Item.Length
        and then not Starts_Character (Fits + 1)
      loop
         Fits := Fits - 1;
      end loop;
      while Fits > 0 and then Item.Content (Fits) = ' ' loop
         Fits := Fits - 1;
      end loop;
      Item.Fit_Length := Fits;
      Item.Fit_Cut := True;
   end Fit;

   overriding procedure Draw
     (Item   : in out Label;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Scale : constant Positive :=
        Positive (Float'Max (1.0, Float'Rounding (Density (Item))));
      High  : constant Float := Float (Debug_Text_Size * Scale);
      Ink   : constant Themes.Color :=
        (if Item.Inked then Item.Ink else Colors.Foreground);
   begin
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         if Item.Fit_Width /= Width_Of (Item) then
            Fit (Item);
         end if;
         declare
            Shown : constant String :=
              Item.Content (1 .. Item.Fit_Length)
              & (if Item.Fit_Cut then Ellipsis else "");
            Room : constant Float :=
              (if Item.Centered or else Item.Trailing
               then Float'Max
                      (0.0,
                       Width_Of (Item)
                       - Line_Texts.Width
                           (Text_Lines (Item).all, Shown,
                            Density (Item) * Item.Scaled, Item.Using))
               else 0.0);
         begin
            Line_Texts.Draw
              (Text_Lines (Item).all, Target, Ink, Shown,
               Left_Of (Item)
               + (if Item.Centered then Room / 2.0 else Room),
               Top_Of (Item) + Height_Of (Item) / 2.0,
               Density (Item) * Item.Scaled, Item.Using);
         end;
      elsif Item.Length > 0 then
         Draw_Text
           (Target, Ink,
            Float'Rounding (Left_Of (Item)),
            Float'Rounding (Top_Of (Item) + (Height_Of (Item) - High) / 2.0),
            Text (Item), Scale);
      end if;
   end Draw;

end UI.Widgets.Labels;
