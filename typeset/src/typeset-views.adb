with Ada.Unchecked_Deallocation;

package body Typeset.Views is

   procedure Free is new Ada.Unchecked_Deallocation (Slab, Slab_Access);

   procedure Compact (Item : in out View; Since : Natural);
   --  Keep the lines drawn since frame Since, their glyphs copied to the
   --  front of the other slab, which becomes active; drop the rest.

   procedure Compact (Item : in out View; Since : Natural) is
      From     : constant Slab_Access := Item.Slabs (Item.Active);
      To       : constant Slab_Access := Item.Slabs (Item.Active + 1);
      Filled   : Natural := 0;
      Position : Line_Maps.Cursor := Item.Lines.First;
   begin
      while Line_Maps.Has_Element (Position) loop
         declare
            Following : constant Line_Maps.Cursor :=
              Line_Maps.Next (Position);
            Line : constant Kept := Line_Maps.Element (Position);
         begin
            if Line.Used < Since then
               Item.Lines.Delete (Position);
            else
               To (Filled + 1 .. Filled + Line.Count) :=
                 From (Line.First .. Line.First + Line.Count - 1);
               Item.Lines.Replace_Element
                 (Position, (Line with delta First => Filled + 1));
               Filled := Filled + Line.Count;
            end if;
            Position := Following;
         end;
      end loop;
      Item.Active := Item.Active + 1;
      Item.Filled := Filled;
   end Compact;

   procedure Keep
     (Item     : in out View;
      Key      : Line_Key;
      Position : out Line_Maps.Cursor);
   --  Keep the line in Scratch, making room if need be; No_Element if
   --  there is no room for it even so.

   procedure Keep
     (Item     : in out View;
      Key      : Line_Key;
      Position : out Line_Maps.Cursor)
   is
      Count : constant Natural := Natural (Item.Scratch.Glyphs.Length);

      function Room return Boolean is
        (Natural (Item.Lines.Length) < Lines_Kept
         and then Item.Filled + Count <= Glyphs_Kept);
   begin
      if not Room then
         Compact (Item, Since => Item.Frame - 1);
         --  Keeping the lines drawn lately would leave too little room,
         --  and soon compact again: keep none. Those of this frame are
         --  drawn already.
         if Natural (Item.Lines.Length) > Lines_Kept / 2
           or else Item.Filled > Glyphs_Kept / 2
         then
            Compact (Item, Since => Item.Frame + 1);
         end if;
      end if;

      if not Room then
         Position := Line_Maps.No_Element;
         return;
      end if;

      declare
         Into : Slab renames Item.Slabs (Item.Active).all;
         At_Glyph : Positive := Item.Filled + 1;
         Inserted : Boolean;
      begin
         for G of Item.Scratch.Glyphs loop
            Into (At_Glyph) := G;
            At_Glyph := At_Glyph + 1;
         end loop;
         Item.Lines.Insert
           (Key, (First => Item.Filled + 1, Count => Count, Used => 0),
            Position, Inserted);
         pragma Assert (Inserted);
         Item.Filled := Item.Filled + Count;
      end;
   end Keep;

   procedure Draw
     (Item   : in out View;
      Laid   : in out Layouts.Layout;
      Doc    : Layouts.Document;
      Target : SDL3.Windows.Renderers.Renderer;
      Value  : SDL3.Windows.Renderers.Color;
      Anchor : in out Positive;
      Offset : in out Float;
      Left   : Float;
      Top    : Float;
      Width  : Natural;
      Height : Natural;
      Scale  : Float;
      Settled : Boolean)
   is
      pragma Unreferenced (Width);
      Line_High : constant Float := Layouts.Line_Height (Laid);
      Ascent    : constant Float := Layouts.Ascent (Laid);
      Font_Size : constant Float := Layouts.Font_Size (Laid);
      First, Last : Positive;
   begin
      Item.Frame := Item.Frame + 1;
      Glyph_Atlas.Begin_Frame (Item.Atlas);

      Layouts.Visible
        (Laid, Doc, Anchor, Offset, Float (Height) / Scale, First, Last);

      declare
         View_Top : constant Float := Layouts.Top (Laid, Anchor) + Offset;
      begin
         for Para in First .. Last loop
            declare
               Para_Y : constant Float :=
                 Top + (Layouts.Top (Laid, Para) - View_Top) * Scale;
               Lines  : constant Positive := Layouts.Line_Count (Laid, Para);
            begin
               for Number in 1 .. Lines loop
                  declare
                     Line_Y : constant Float :=
                       Para_Y + Float (Number - 1) * Line_High * Scale;
                  begin
                     if Line_Y + Line_High * Scale >= Top
                       and then Line_Y <= Top + Float (Height)
                     then
                        declare
                           Key      : constant Line_Key :=
                             (Layouts.Layout_Id (Laid, Para), Number);
                           Position : Line_Maps.Cursor :=
                             Item.Lines.Find (Key);
                           Baseline : constant Float :=
                             Line_Y + Ascent * Scale;
                        begin
                           if not Line_Maps.Has_Element (Position) then
                              Layouts.Shape_Line
                                (Laid, Doc, Item.Reg, Para, Number,
                                 Item.Scratch);
                              Item.Shaped := Item.Shaped + 1;
                              Keep (Item, Key, Position);
                           end if;

                           if Line_Maps.Has_Element (Position) then
                              declare
                                 Line : Kept renames
                                   Item.Lines.Reference (Position);
                              begin
                                 Line.Used := Item.Frame;
                                 Glyph_Atlas.Draw
                                   (Item.Atlas, Item.Reg, Target,
                                    Item.Slabs (Item.Active)
                                      (Line.First
                                       .. Line.First + Line.Count - 1),
                                    X => Left, Baseline => Baseline,
                                    Scale => Scale,
                                    Size => Font_Size * Scale,
                                    Value => Value, Settled => Settled);
                              end;
                           else
                              Glyph_Atlas.Draw
                                (Item.Atlas, Item.Reg, Target, Item.Scratch,
                                 X => Left, Baseline => Baseline,
                                 Scale => Scale, Size => Font_Size * Scale,
                                 Value => Value, Settled => Settled);
                           end if;
                        end;
                     end if;
                  end;
               end loop;
            end;
         end loop;
      end;
      Glyph_Atlas.Flush (Item.Atlas, Target);
   end Draw;

   function Lines_Shaped (Item : View) return Natural is (Item.Shaped);

   function Glyphs_Made (Item : View) return Natural is
     (Glyph_Atlas.Glyphs_Made (Item.Atlas));

   overriding procedure Initialize (Item : in out View) is
   begin
      Item.Slabs := [others => new Slab];
   end Initialize;

   overriding procedure Finalize (Item : in out View) is
   begin
      Item.Lines.Clear;
      for Each of Item.Slabs loop
         Free (Each);
      end loop;
   end Finalize;

end Typeset.Views;
