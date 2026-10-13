with Ada.Finalization;
with Interfaces;
with CoreText.Shaping;
with CoreText.Shaping.Glyphs;
with SDL3.Windows.Renderers;
with SDL3.Windows.Renderers.Textures;

--  Draws shaped text from glyphs rasterized once each into atlas
--  textures, a quad to a glyph batched a page at a time: a screenful
--  of text is a few draw calls, and a glyph is rasterized again only
--  when it is wanted at another size.
--
--  Glyphs are drawn at the sizes CoreText rasterized them. While the
--  size changes continuously, as when zooming, they are made at a few
--  steps and scaled between, to keep the number of sizes down; once it
--  is Settled they are made at the size.
package Typeset.Glyph_Atlas is

   type Atlas is limited private;
   --  Declare it after the Renderer it draws to, so that its textures
   --  are destroyed first, and always draw it to the same Renderer.

   Page_Size : constant := 1024;
   --  Pixels a side of a page of the atlas.

   Max_Pages : constant := 8;
   --  When all are full, the least recently drawn from is emptied. Pages
   --  are made as they are needed, so the atlas holds 4 MB of texture
   --  for each page in use, at most 32 MB.

   Slots_Kept : constant := 2 ** 16;
   --  Room to know where this many glyphs are, drawn or blank; it is
   --  made once, with the atlas. When it is three quarters full every
   --  page is emptied.

   procedure Begin_Frame (Item : in out Atlas);
   --  Call before drawing a frame, so that the atlas knows which pages
   --  are in use.

   procedure Draw
     (Item     : in out Atlas;
      Reg      : CoreText.Shaping.Registry;
      Target   : SDL3.Windows.Renderers.Renderer;
      Line     : CoreText.Shaping.Glyph_Array;
      X        : Float;
      Baseline : Float;
      Scale    : Float;
      Size     : Float;
      Value    : SDL3.Windows.Renderers.Color;
      Settled  : Boolean)
     with Pre => Scale > 0.0 and then Size > 0.0;
   --  Draw a line of glyphs, its start X pixels and its baseline
   --  Baseline pixels from the target's top left. The glyphs' positions
   --  are in units that are Scale pixels each; their font is Size
   --  pixels. The glyphs are batched: Flush before drawing anything
   --  that should be over them or under them.

   procedure Draw
     (Item     : in out Atlas;
      Reg      : CoreText.Shaping.Registry;
      Target   : SDL3.Windows.Renderers.Renderer;
      Line     : CoreText.Shaping.Shaped;
      X        : Float;
      Baseline : Float;
      Scale    : Float;
      Size     : Float;
      Value    : SDL3.Windows.Renderers.Color;
      Settled  : Boolean)
     with Pre => Scale > 0.0 and then Size > 0.0;
   --  The same, of a line as shaped.

   procedure Flush
     (Item   : in out Atlas;
      Target : SDL3.Windows.Renderers.Renderer);
   --  Draw all the glyphs batched.

   function Glyphs_Made (Item : Atlas) return Natural;
   --  How many glyphs have been rasterized, for measuring.

   function Pages_Used (Item : Atlas) return Natural;

private

   use SDL3.Windows.Renderers;

   type Slot is record
      Page        : Natural := 0;  --  0 for a glyph with nothing to draw
      X, Y, W, H  : Natural := 0;
      Left, Top   : Integer := 0;
      Color       : Boolean := False;
   end record;

   No_Key : constant Interfaces.Unsigned_64 := 0;
   --  No glyph has it: its size is part of its key, and never 0.

   type Known is record
      Key  : Interfaces.Unsigned_64 := No_Key;
      Spot : Slot;
   end record;

   type Slot_Index is mod Slots_Kept;
   type Slot_Table is array (Slot_Index) of Known;
   type Slot_Table_Access is access Slot_Table;
   --  Open addressing, probed linearly from where a key hashes to: one
   --  probe, mostly, to find a glyph, and no container to check.

   type Vertex_Access is access Textures.Vertex_Array;

   type Page_Record is limited record
      Image    : Textures.Texture;
      Cursor_X : Natural := 0;
      Row_Y    : Natural := 0;
      Row_H    : Natural := 0;
      Used     : Natural := 0;  --  the frame last drawn from
      Vertices : Vertex_Access;
      Quads    : Natural := 0;
   end record;

   type Page_Array is array (1 .. Max_Pages) of Page_Record;

   type Atlas is new Ada.Finalization.Limited_Controlled with record
      Pages  : Page_Array;
      Count  : Natural := 0;
      Slots  : Slot_Table_Access;
      Filled : Natural := 0;  --  of Slots
      Frame  : Natural := 0;
      Made   : Natural := 0;
      Scratch : CoreText.Shaping.Glyphs.Image;
   end record;

   overriding procedure Finalize (Item : in out Atlas);

end Typeset.Glyph_Atlas;
