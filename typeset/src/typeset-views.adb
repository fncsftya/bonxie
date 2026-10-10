with Ada.Unchecked_Deallocation;

package body Typeset.Views is

   procedure Free is new Ada.Unchecked_Deallocation (Kept, Kept_Access);

   procedure Drop_Lines (Item : in out View; Older_Than : Natural);
   --  Forget shaped lines not drawn since frame Older_Than.

   procedure Drop_Lines (Item : in out View; Older_Than : Natural) is
      Position : Line_Maps.Cursor := Item.Lines.First;
   begin
      while Line_Maps.Has_Element (Position) loop
         declare
            Following : constant Line_Maps.Cursor :=
              Line_Maps.Next (Position);
            Doomed : Kept_Access := Line_Maps.Element (Position);
         begin
            if Doomed.Used < Older_Than then
               Free (Doomed);
               Item.Lines.Delete (Position);
            end if;
            Position := Following;
         end;
      end loop;
   end Drop_Lines;

   procedure Draw
     (Item   : in out View;
      Doc    : in out Documents.Document;
      Target : SDL3.Windows.Renderers.Renderer;
      Value  : SDL3.Windows.Renderers.Color;
      Anchor : in out Documents.Paragraph_Number;
      Offset : in out Float;
      Left   : Float;
      Top    : Float;
      Width  : Natural;
      Height : Natural;
      Scale  : Float;
      Settled : Boolean)
   is
      pragma Unreferenced (Width);
      Line_High : constant Float := Documents.Line_Height (Doc);
      Ascent    : constant Float := Documents.Ascent (Doc);
      Font_Size : constant Float := Documents.Font_Size (Doc);
      First, Last : Documents.Paragraph_Number;
   begin
      Item.Frame := Item.Frame + 1;
      Glyph_Atlas.Begin_Frame (Item.Atlas);
      if Natural (Item.Lines.Length) > Lines_Kept then
         Drop_Lines (Item, Item.Frame - 1);
         if Natural (Item.Lines.Length) > Lines_Kept then
            Drop_Lines (Item, Item.Frame + 1);
         end if;
      end if;

      Documents.Visible
        (Doc, Anchor, Offset, Float (Height) / Scale, First, Last);

      declare
         View_Top : constant Float := Documents.Top (Doc, Anchor) + Offset;
      begin
         for Para in First .. Last loop
            declare
               Para_Y : constant Float :=
                 Top + (Documents.Top (Doc, Para) - View_Top) * Scale;
               Lines  : constant Positive := Documents.Line_Count (Doc, Para);
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
                           Key    : constant Line_Key :=
                             (Documents.Layout_Id (Doc, Para), Number);
                           Cursor : Line_Maps.Cursor := Item.Lines.Find (Key);
                           Made   : Kept_Access;
                           Inserted : Boolean;
                        begin
                           if not Line_Maps.Has_Element (Cursor) then
                              Made := new Kept;
                              Documents.Shape_Line
                                (Doc, Item.Reg, Para, Number, Made.Line);
                              Item.Shaped := Item.Shaped + 1;
                              Item.Lines.Insert (Key, Made, Cursor, Inserted);
                           end if;
                           Made := Line_Maps.Element (Cursor);
                           Made.Used := Item.Frame;
                           Glyph_Atlas.Draw
                             (Item.Atlas, Item.Reg, Target, Made.Line,
                              X => Left,
                              Baseline => Line_Y + Ascent * Scale,
                              Scale => Scale,
                              Size => Font_Size * Scale,
                              Value => Value,
                              Settled => Settled);
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

   overriding procedure Finalize (Item : in out View) is
   begin
      Drop_Lines (Item, Item.Frame + 1);
   end Finalize;

end Typeset.Views;
