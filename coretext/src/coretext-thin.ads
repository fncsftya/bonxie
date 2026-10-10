with Interfaces.C;
with System;

--  Minimal thin C binding to CoreFoundation, CoreText and CoreGraphics.
--  Internal: use the CoreText child packages.
private package CoreText.Thin is

   use Interfaces.C;

   subtype Ref is System.Address;
   --  Any CF object: CFStringRef, CTFontRef, CTLineRef and so on.
   Null_Ref : constant Ref := System.Null_Address;

   C_False : constant C_bool := C_bool'Val (0);
   C_True  : constant C_bool := C_bool'Val (1);

   UTF8 : constant Interfaces.Unsigned_32 := 16#0800_0100#;
   --  kCFStringEncodingUTF8

   Alpha_Premultiplied_Last : constant Interfaces.Unsigned_32 := 1;
   Byte_Order_32_Big        : constant Interfaces.Unsigned_32 := 16#4000#;

   type CF_Range is record
      Location, Length : long;
   end record
     with Convention => C_Pass_By_Copy;

   type CG_Point is record
      X, Y : double;
   end record
     with Convention => C_Pass_By_Copy;

   type CG_Rect is record
      X, Y, Width, Height : double;
   end record
     with Convention => C_Pass_By_Copy;

   Color_Glyphs_Trait : constant Interfaces.Unsigned_32 := 16#2000#;
   --  kCTFontTraitColorGlyphs

   --  Global constants exported by the frameworks.

   Font_Attribute_Name : constant Ref
     with Import, Convention => C, External_Name => "kCTFontAttributeName";

   Foreground_From_Context : constant Ref
     with Import, Convention => C,
          External_Name => "kCTForegroundColorFromContextAttributeName";

   Boolean_True : constant Ref
     with Import, Convention => C, External_Name => "kCFBooleanTrue";

   Color_Space_SRGB : constant Ref
     with Import, Convention => C, External_Name => "kCGColorSpaceSRGB";

   Dictionary_Key_Callbacks : aliased char
     with Import, Convention => C,
          External_Name => "kCFTypeDictionaryKeyCallBacks";

   Dictionary_Value_Callbacks : aliased char
     with Import, Convention => C,
          External_Name => "kCFTypeDictionaryValueCallBacks";

   --  CoreFoundation

   procedure CF_Release (Item : Ref)
     with Import, Convention => C, External_Name => "CFRelease";

   function CF_String_Create_With_Bytes
     (Allocator   : Ref;
      Bytes       : System.Address;
      Count       : long;
      Encoding    : Interfaces.Unsigned_32;
      Is_External : C_bool) return Ref
     with Import, Convention => C,
          External_Name => "CFStringCreateWithBytes";

   function CF_String_Get_Length (Item : Ref) return long
     with Import, Convention => C, External_Name => "CFStringGetLength";

   function CF_String_Get_C_String
     (Item        : Ref;
      Buffer      : System.Address;
      Buffer_Size : long;
      Encoding    : Interfaces.Unsigned_32) return C_bool
     with Import, Convention => C, External_Name => "CFStringGetCString";

   function CF_String_Composed_Range
     (Item : Ref; Index : long) return CF_Range
     with Import, Convention => C,
          External_Name => "CFStringGetRangeOfComposedCharactersAtIndex";

   function CF_Dictionary_Create
     (Allocator       : Ref;
      Keys            : System.Address;
      Values          : System.Address;
      Count           : long;
      Key_Callbacks   : System.Address;
      Value_Callbacks : System.Address) return Ref
     with Import, Convention => C, External_Name => "CFDictionaryCreate";

   function CF_Attributed_String_Create
     (Allocator : Ref; Text : Ref; Attributes : Ref) return Ref
     with Import, Convention => C,
          External_Name => "CFAttributedStringCreate";

   function CF_Array_Get_Count (Item : Ref) return long
     with Import, Convention => C, External_Name => "CFArrayGetCount";

   function CF_Array_Get_Value_At_Index (Item : Ref; Index : long) return Ref
     with Import, Convention => C,
          External_Name => "CFArrayGetValueAtIndex";

   --  CoreText

   function CT_Font_Manager_Family_Names return Ref
     with Import, Convention => C,
          External_Name => "CTFontManagerCopyAvailableFontFamilyNames";

   function CT_Font_Create_With_Name
     (Name : Ref; Size : double; Matrix : System.Address) return Ref
     with Import, Convention => C, External_Name => "CTFontCreateWithName";

   function CT_Font_Copy_Family_Name (Font : Ref) return Ref
     with Import, Convention => C, External_Name => "CTFontCopyFamilyName";

   function CT_Font_Get_Ascent (Font : Ref) return double
     with Import, Convention => C, External_Name => "CTFontGetAscent";

   function CT_Font_Get_Descent (Font : Ref) return double
     with Import, Convention => C, External_Name => "CTFontGetDescent";

   function CT_Font_Get_Leading (Font : Ref) return double
     with Import, Convention => C, External_Name => "CTFontGetLeading";

   function CT_Typesetter_Create (Text : Ref) return Ref
     with Import, Convention => C,
          External_Name => "CTTypesetterCreateWithAttributedString";

   function CT_Typesetter_Suggest_Line_Break
     (Typesetter : Ref; Start : long; Width : double) return long
     with Import, Convention => C,
          External_Name => "CTTypesetterSuggestLineBreak";

   function CT_Line_Create (Text : Ref) return Ref
     with Import, Convention => C,
          External_Name => "CTLineCreateWithAttributedString";

   function CT_Line_Typographic_Bounds
     (Line    : Ref;
      Ascent  : System.Address;
      Descent : System.Address;
      Leading : System.Address) return double
     with Import, Convention => C,
          External_Name => "CTLineGetTypographicBounds";

   function CT_Line_Offset_For_Index
     (Line      : Ref;
      Index     : long;
      Secondary : System.Address) return double
     with Import, Convention => C,
          External_Name => "CTLineGetOffsetForStringIndex";

   function CT_Line_Index_For_Position
     (Line : Ref; Position : CG_Point) return long
     with Import, Convention => C,
          External_Name => "CTLineGetStringIndexForPosition";

   procedure CT_Line_Draw (Line : Ref; Context : Ref)
     with Import, Convention => C, External_Name => "CTLineDraw";

   --  CoreGraphics

   function CG_Color_Space_Create (Name : Ref) return Ref
     with Import, Convention => C,
          External_Name => "CGColorSpaceCreateWithName";

   procedure CG_Color_Space_Release (Item : Ref)
     with Import, Convention => C, External_Name => "CGColorSpaceRelease";

   function CG_Bitmap_Context_Create
     (Data              : System.Address;
      Width, Height     : size_t;
      Bits_Per_Component : size_t;
      Bytes_Per_Row     : size_t;
      Color_Space       : Ref;
      Bitmap_Info       : Interfaces.Unsigned_32) return Ref
     with Import, Convention => C,
          External_Name => "CGBitmapContextCreate";

   procedure CG_Context_Release (Item : Ref)
     with Import, Convention => C, External_Name => "CGContextRelease";

   procedure CG_Context_Set_Fill_Color
     (Context : Ref; Red, Green, Blue, Alpha : double)
     with Import, Convention => C,
          External_Name => "CGContextSetRGBFillColor";

   procedure CG_Context_Set_Text_Position (Context : Ref; X, Y : double)
     with Import, Convention => C,
          External_Name => "CGContextSetTextPosition";

   procedure CG_Context_Set_Should_Smooth_Fonts
     (Context : Ref; Value : C_bool)
     with Import, Convention => C,
          External_Name => "CGContextSetShouldSmoothFonts";

   function CF_Retain (Item : Ref) return Ref
     with Import, Convention => C, External_Name => "CFRetain";

   function CF_String_Create_With_Substring
     (Allocator : Ref; Item : Ref; Within : CF_Range) return Ref
     with Import, Convention => C,
          External_Name => "CFStringCreateWithSubstring";

   function CF_Dictionary_Get_Value (Item : Ref; Key : Ref) return Ref
     with Import, Convention => C, External_Name => "CFDictionaryGetValue";

   function CT_Font_Copy_PostScript_Name (Font : Ref) return Ref
     with Import, Convention => C,
          External_Name => "CTFontCopyPostScriptName";

   function CT_Font_Create_Copy_With_Attributes
     (Font       : Ref;
      Size       : double;
      Matrix     : System.Address;
      Attributes : Ref) return Ref
     with Import, Convention => C,
          External_Name => "CTFontCreateCopyWithAttributes";

   function CT_Font_Get_Symbolic_Traits (Font : Ref)
      return Interfaces.Unsigned_32
     with Import, Convention => C,
          External_Name => "CTFontGetSymbolicTraits";

   function CT_Font_Bounding_Rects
     (Font        : Ref;
      Orientation : int;
      Glyphs      : System.Address;
      Rects       : System.Address;
      Count       : long) return CG_Rect
     with Import, Convention => C,
          External_Name => "CTFontGetBoundingRectsForGlyphs";

   procedure CT_Font_Draw_Glyphs
     (Font      : Ref;
      Glyphs    : System.Address;
      Positions : System.Address;
      Count     : size_t;
      Context   : Ref)
     with Import, Convention => C, External_Name => "CTFontDrawGlyphs";

   function CT_Line_Get_Glyph_Runs (Line : Ref) return Ref
     with Import, Convention => C, External_Name => "CTLineGetGlyphRuns";

   function CT_Run_Get_Glyph_Count (Run : Ref) return long
     with Import, Convention => C, External_Name => "CTRunGetGlyphCount";

   procedure CT_Run_Get_Glyphs
     (Run : Ref; Within : CF_Range; Buffer : System.Address)
     with Import, Convention => C, External_Name => "CTRunGetGlyphs";

   procedure CT_Run_Get_Positions
     (Run : Ref; Within : CF_Range; Buffer : System.Address)
     with Import, Convention => C, External_Name => "CTRunGetPositions";

   function CT_Run_Get_Attributes (Run : Ref) return Ref
     with Import, Convention => C, External_Name => "CTRunGetAttributes";

   procedure CG_Context_Set_Allows_Font_Subpixel_Positioning
     (Context : Ref; Value : C_bool)
     with Import, Convention => C,
          External_Name => "CGContextSetAllowsFontSubpixelPositioning";

   procedure CG_Context_Set_Should_Subpixel_Position_Fonts
     (Context : Ref; Value : C_bool)
     with Import, Convention => C,
          External_Name => "CGContextSetShouldSubpixelPositionFonts";

   procedure CG_Context_Set_Should_Subpixel_Quantize_Fonts
     (Context : Ref; Value : C_bool)
     with Import, Convention => C,
          External_Name => "CGContextSetShouldSubpixelQuantizeFonts";

end CoreText.Thin;
