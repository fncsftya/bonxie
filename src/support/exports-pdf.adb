with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Exports.Pdf is

   use type Interfaces.C.int;

   RS : constant Character := Character'Val (16#1E#);
   GS : constant Character := Character'Val (16#1D#);
   US : constant Character := Character'Val (16#1F#);

   type Bytes is array (Positive) of Character with Convention => C;

   type Bytes_Access is access all Bytes with Convention => C;

   function Render
     (Data    : System.Address;
      Length  : Interfaces.C.size_t;
      Title   : Interfaces.C.Strings.chars_ptr;
      Width   : Interfaces.C.double;
      Height  : Interfaces.C.double;
      Output  : out Bytes_Access;
      Written : out Interfaces.C.size_t) return Interfaces.C.int
   with Import, Convention => C, External_Name => "bonxie_pdf_render";

   procedure Free (Item : Bytes_Access)
   with Import, Convention => C, External_Name => "free";

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   --  Words with the characters that separate the fields, and any other control character but a tab, made spaces.
   function Clean (Words : String) return String
   is [for C of Words => (if C < ' ' and then C /= ASCII.HT then ' ' else C)];

   function Marks_Of (Each : Span) return Natural
   is (Boolean'Pos (Each.Marks (Italic))
       + 2 * Boolean'Pos (Each.Marks (Bold))
       + 4 * Boolean'Pos (Each.Marks (Struck))
       + 8 * Boolean'Pos (Each.Marks (Underlined))
       + 16 * Boolean'Pos (Each.Marks (Linked)));

   function Serialized (Item : Texts.Documents.Document) return String is
      Made  : Unbounded.Unbounded_String;
      First : Boolean := True;
   begin
      for Each of Blocks_Of (Item) loop
         if not First then
            Unbounded.Append (Made, RS);
         end if;
         First := False;
         Unbounded.Append
           (Made,
            Image (Block_Kinds'Pos (Each.Kind))
            & US
            & Image (Each.Level)
            & US
            & Image (Each.Indent)
            & US
            & (if Each.Quoted then "1" else "0")
            & US
            & Clean (Unbounded.To_String (Each.Figure)));
         for Part of Each.Spans loop
            Unbounded.Append
              (Made,
               GS
               & Image (Marks_Of (Part))
               & US
               & Clean (Unbounded.To_String (Part.Address))
               & US
               & Clean (Unbounded.To_String (Part.Words)));
         end loop;
      end loop;
      return Unbounded.To_String (Made);
   end Serialized;

   function Of_Document (Item : Texts.Documents.Document; Title : String; Paper : Paper_Sizes := A4) return String is
      Blocks  : constant String := Serialized (Item);
      Name    : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Clean (Title));
      Output  : Bytes_Access;
      Written : Interfaces.C.size_t;
      Result  : Interfaces.C.int;
   begin
      Result :=
        Render
          (Data    => (if Blocks'Length = 0 then System.Null_Address else Blocks (Blocks'First)'Address),
           Length  => Interfaces.C.size_t (Blocks'Length),
           Title   => Name,
           Width   =>
             (case Paper is
                when Letter => 612.0,
                when A4     => 595.0),
           Height  =>
             (case Paper is
                when Letter => 792.0,
                when A4     => 842.0),
           Output  => Output,
           Written => Written);
      Interfaces.C.Strings.Free (Name);
      if Result /= 0 or else Output = null then
         raise Failed with "PDF error" & Result'Image;
      end if;
      declare
         Whole : constant String (1 .. Natural (Written)) := String (Output (1 .. Natural (Written)));
      begin
         Free (Output);
         return Whole;
      end;
   end Of_Document;

end Exports.Pdf;
