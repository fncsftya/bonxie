with Ada.Containers.Bounded_Hashed_Maps;
with Ada.Finalization;
with CoreText.Shaping;
with Typeset.Glyph_Atlas;
with Typeset.Layouts;
with SDL3.Windows.Renderers;

--  Draws a document, as a layout has it, into a Renderer: the visible
--  paragraphs are laid out, their lines shaped (once each: the shaped
--  lines are kept) and drawn from the glyph atlas. Scrolling, and
--  zooming, are changes to what it is asked to draw.
package Typeset.Views is

   type View is limited private;
   --  Declare it after the Renderer it draws to, and always draw it to
   --  that Renderer.

   Lines_Kept  : constant := 4096;
   Glyphs_Kept : constant := 64 * Lines_Kept;
   --  How many shaped lines a view keeps, and their glyphs between them:
   --  the room for them is made once, when the view is. Past either it
   --  drops those not drawn lately.

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
      Settled : Boolean;
      Rows_From : Float := Float'First;
      Rows_To   : Float := Float'Last)
     with Pre => Layouts.Is_Synced (Laid, Doc) and then Scale > 0.0
                 and then Anchor <= Layouts.Count (Laid);
   --  Draw the page in colour Value into the part of the target Width x
   --  Height pixels with its top left at Left, Top (the left of the
   --  page is at Left). The top of what is shown is Offset layout units
   --  below the top of paragraph Anchor, which are renormalized. Scale
   --  is the pixels to a layout unit: the display's density times the
   --  zoom. Settled says the scale is no longer changing. The glyphs are
   --  flushed.
   --
   --  Only the lines that touch the rows of the target from Rows_From to
   --  Rows_To are drawn, for when no more is to show: the rest of the
   --  page is not looked at.

   type Shared_Resources is limited record
      Reg   : aliased CoreText.Shaping.Registry;
      Atlas : aliased Glyph_Atlas.Atlas;
   end record;
   --  Shared font registry and glyph atlas that can be used across
   --  multiple views drawing to the same target renderer.

   type Shared_Access is access all Shared_Resources;

   procedure Set_Shared
     (Item   : in out View;
      Shared : not null Shared_Access);
   --  Direct Item to shape and rasterize into Shared, sharing glyphs
   --  and font handles with other views using the same resources.

   function Lines_Drawn (Item : View) return Natural;
   --  How many lines have been drawn, for measuring.

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
      First : Positive := 1;  --  of its glyphs, in the active slab
      Count : Natural := 0;
      Used  : Natural := 0;  --  the frame last drawn
   end record;

   package Line_Maps is new Ada.Containers.Bounded_Hashed_Maps
     (Line_Key, Kept, Hash, "=");

   subtype Slab is CoreText.Shaping.Glyph_Array (1 .. Glyphs_Kept);
   type Slab_Access is access Slab;
   type Slab_Index is mod 2;
   type Slab_Pair is array (Slab_Index) of Slab_Access;
   --  The glyphs of the kept lines are in the active slab, one line's
   --  after another's. When it is full those of lines drawn lately are
   --  copied to the other, which becomes active, and the rest dropped.

   type View is new Ada.Finalization.Limited_Controlled with record
      Shared  : Shared_Access := null;
      Reg     : aliased CoreText.Shaping.Registry;
      Atlas   : aliased Glyph_Atlas.Atlas;
      Lines   : Line_Maps.Map
                  (Capacity => Lines_Kept,
                   Modulus  => Line_Maps.Default_Modulus (Lines_Kept));
      Slabs   : Slab_Pair;
      Active  : Slab_Index := 0;
      Filled  : Natural := 0;  --  of the active slab
      Scratch : CoreText.Shaping.Shaped;
      --  A line as shaped, before it is kept: it holds on to its room.
      Frame   : Natural := 0;
      Shaped  : Natural := 0;
      Drawn   : Natural := 0;
   end record;

   overriding procedure Initialize (Item : in out View);
   overriding procedure Finalize (Item : in out View);

end Typeset.Views;
