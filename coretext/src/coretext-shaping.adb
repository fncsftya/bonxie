with Interfaces.C;
with System.Storage_Elements;
with CoreText.Core;
with CoreText.Thin;

package body CoreText.Shaping is

   use type System.Address;
   use type Interfaces.C.long;
   use type Interfaces.Unsigned_32;

   type Id_Array is array (Positive range <>) of Interfaces.Unsigned_16;
   type Position_Array is array (Positive range <>) of Thin.CG_Point;

   function Hash (Key : System.Address) return Ada.Containers.Hash_Type is
      use type Ada.Containers.Hash_Type;
      use type System.Storage_Elements.Integer_Address;
      Bits : constant System.Storage_Elements.Integer_Address :=
        System.Storage_Elements.To_Integer (Key);
   begin
      --  Objects are 16-byte aligned: the low bits say nothing.
      return Ada.Containers.Hash_Type'Mod (Bits / 16) * 16#9E37_79B1#;
   end Hash;

   function Register_By_Name
     (Reg : in out Registry; Font : Thin.Ref) return Font_Id;
   --  The id of the run font Font, found by its name, adding it if it is
   --  new.

   function Register_By_Name
     (Reg : in out Registry; Font : Thin.Ref) return Font_Id
   is
      Name_Ref : Thin.Ref := Thin.CT_Font_Copy_PostScript_Name (Font);
   begin
      if Name_Ref = Thin.Null_Ref then
         raise Error with "CTFontCopyPostScriptName failed";
      end if;

      declare
         Name   : constant String := Core.To_Ada (Name_Ref);
         Cursor : constant Name_Maps.Cursor := Reg.Names.Find (Name);
      begin
         Core.Release (Name_Ref);
         if Name_Maps.Has_Element (Cursor) then
            return Name_Maps.Element (Cursor);
         end if;

         declare
            Unit : constant Thin.Ref :=
              Thin.CT_Font_Create_Copy_With_Attributes
                (Font, 1.0, System.Null_Address, Thin.Null_Ref);
         begin
            if Unit = Thin.Null_Ref then
               raise Error with "CTFontCreateCopyWithAttributes failed";
            end if;
            Reg.Fonts.Append
              (Font_Entry'
                 (Handle => Unit,
                  Color  =>
                    (Thin.CT_Font_Get_Symbolic_Traits (Unit)
                     and Thin.Color_Glyphs_Trait) /= 0));
            Reg.Names.Insert (Name, Reg.Fonts.Last_Index);
            return Reg.Fonts.Last_Index;
         end;
      end;
   end Register_By_Name;

   function Register
     (Reg : in out Registry; Font : Thin.Ref) return Font_Id;
   --  The id of the run font Font, adding it if it is new.

   function Register
     (Reg : in out Registry; Font : Thin.Ref) return Font_Id
   is
      Cursor : constant Handle_Maps.Cursor := Reg.Seen.Find (Font);
   begin
      if Handle_Maps.Has_Element (Cursor) then
         return Handle_Maps.Element (Cursor);
      end if;

      declare
         Id : constant Font_Id := Register_By_Name (Reg, Font);
      begin
         if Natural (Reg.Seen.Length) < Max_Seen then
            Reg.Seen.Insert (Thin.CF_Retain (Font), Id);
         end if;
         return Id;
      end;
   end Register;

   procedure Shape
     (Reg    : in out Registry;
      Using  : Fonts.Font;
      Text   : Strings.Text;
      First, Stop : Natural;
      Result : out Shaped)
   is
      Length : constant Natural := Strings.Length (Text);
      Sub    : Thin.Ref := Thin.Null_Ref;
      Attr   : Thin.Ref;
      Line   : Thin.Ref;
      Ascent, Descent : aliased Interfaces.C.double;
   begin
      Result.Glyphs.Clear;
      Result.Width := 0.0;
      if First = Stop then
         return;
      end if;

      if First /= 0 or else Stop /= Length then
         Sub := Thin.CF_String_Create_With_Substring
           (Thin.Null_Ref, Strings.Handle (Text),
            (Location => Interfaces.C.long (First),
             Length   => Interfaces.C.long (Stop - First)));
      end if;
      Attr := Thin.CF_Attributed_String_Create
        (Thin.Null_Ref,
         (if Sub = Thin.Null_Ref then Strings.Handle (Text) else Sub),
         Fonts.Attributes (Using));
      Core.Release (Sub);
      if Attr = Thin.Null_Ref then
         raise Error with "CFAttributedStringCreate failed";
      end if;
      Line := Thin.CT_Line_Create (Attr);
      Core.Release (Attr);
      if Line = Thin.Null_Ref then
         raise Error with "CTLineCreateWithAttributedString failed";
      end if;

      Result.Glyphs.Reserve_Capacity
        (Ada.Containers.Count_Type (Thin.CT_Line_Get_Glyph_Count (Line)));
      Result.Width := Float
        (Thin.CT_Line_Typographic_Bounds
           (Line, Ascent'Address, Descent'Address, System.Null_Address));

      declare
         Runs : constant Thin.Ref := Thin.CT_Line_Get_Glyph_Runs (Line);
      begin
         for R in 0 .. Thin.CF_Array_Get_Count (Runs) - 1 loop
            declare
               Run   : constant Thin.Ref :=
                 Thin.CF_Array_Get_Value_At_Index (Runs, R);
               Count : constant Natural :=
                 Natural (Thin.CT_Run_Get_Glyph_Count (Run));
               Font  : constant Thin.Ref :=
                 Thin.CF_Dictionary_Get_Value
                   (Thin.CT_Run_Get_Attributes (Run),
                    Thin.Font_Attribute_Name);
            begin
               if Count > 0 then
                  if Font = Thin.Null_Ref then
                     raise Error with "run has no font";
                  end if;
                  declare
                     Id : constant Font_Id := Register (Reg, Font);
                     --  A run is at most a line's glyphs: few enough for
                     --  the stack.
                     Ids : Id_Array (1 .. Count);
                     Positions : Position_Array (1 .. Count);
                     Whole : constant Thin.CF_Range := (0, 0);
                  begin
                     Thin.CT_Run_Get_Glyphs (Run, Whole, Ids (1)'Address);
                     Thin.CT_Run_Get_Positions
                       (Run, Whole, Positions (1)'Address);
                     for I in 1 .. Count loop
                        Result.Glyphs.Append
                          (Glyph'(Id   => Ids (I),
                                  Font => Id,
                                  X    => Float (Positions (I).X)));
                     end loop;
                  end;
               end if;
            end;
         end loop;
      end;
      Core.Release (Line);
   end Shape;

   function Is_Color (Reg : Registry; Item : Font_Id) return Boolean is
     (Reg.Fonts (Item).Color);

   function Font_Count (Reg : Registry) return Natural is
     (Natural (Reg.Fonts.Length));

   overriding procedure Finalize (Item : in out Registry) is
   begin
      for Each of Item.Fonts loop
         declare
            Handle : Thin.Ref := Each.Handle;
         begin
            Core.Release (Handle);
         end;
      end loop;
      for Position in Item.Seen.Iterate loop
         declare
            Handle : Thin.Ref := Handle_Maps.Key (Position);
         begin
            Core.Release (Handle);
         end;
      end loop;
      Item.Seen.Clear;
      Item.Fonts.Clear;
      Item.Names.Clear;
   end Finalize;

end CoreText.Shaping;
