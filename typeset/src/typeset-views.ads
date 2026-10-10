with Ada.Containers.Hashed_Maps;
with Ada.Finalization;
with Typeset.Documents;
with CoreText.Shaping;
with Typeset.Glyph_Atlas;
with SDL3.Windows.Renderers;

--  Draws a Document into a Renderer: the visible paragraphs are laid
--  out, their lines shaped (once each: the shaped lines are kept) and
--  drawn from the glyph atlas. Scrolling, and zooming, are changes to
--  what it is asked to draw.
package Typeset.Views is

   type View is limited private;
   --  Declare it after the Renderer it draws to, and always draw it to
   --  that Renderer.

   Lines_Kept : constant := 4096;
   --  How many shaped lines a view keeps. Past that it drops those not
   --  drawn lately.

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
     with Pre => Documents.Is_Configured (Doc) and then Scale > 0.0
                 and then Anchor <= Documents.Count (Doc);
   --  Draw the page in colour Value into the part of the target Width x
   --  Height pixels with its top left at Left, Top (the left of the
   --  page is at Left). The top of what is shown is Offset layout units
   --  below the top of paragraph Anchor, which are renormalized. Scale
   --  is the pixels to a layout unit: the display's density times the
   --  zoom. Settled says the scale is no longer changing. The glyphs are
   --  flushed.

   function Lines_Shaped (Item : View) return Natural;
   --  How many lines have been shaped, for measuring.

   function Glyphs_Made (Item : View) return Natural;

private

   use type Ada.Containers.Hash_Type;

   type Line_Key is record
      Layout : Positive;
      Number : Positive;
   end record;

   function Hash (Key : Line_Key) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (Key.Layout) * 16#9E37_79B1#
      + Ada.Containers.Hash_Type (Key.Number));

   type Kept is record
      Line : CoreText.Shaping.Shaped;
      Used : Natural := 0;  --  the frame last drawn
   end record;

   type Kept_Access is access Kept;

   package Line_Maps is new Ada.Containers.Hashed_Maps
     (Line_Key, Kept_Access, Hash, "=");

   type View is new Ada.Finalization.Limited_Controlled with record
      Reg    : CoreText.Shaping.Registry;
      Atlas  : Glyph_Atlas.Atlas;
      Lines  : Line_Maps.Map;
      Frame  : Natural := 0;
      Shaped : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out View);

end Typeset.Views;
