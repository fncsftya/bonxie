--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2016 onox <denkpadje@gmail.com>
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Strings.Bounded;
with Ada.Strings.Unbounded;

package body JSON.Types is

   package SU renames Ada.Strings.Unbounded;

   function "+" (Text : String) return SU.Unbounded_String
     renames SU.To_Unbounded_String;

   function "+" (Text : SU.Unbounded_String) return String
     renames SU.To_String;

   function Unescape (Text : String) return String is
      --  Unicode escapes never expand beyond their source representation.
      package SB is new Ada.Strings.Bounded.Generic_Bounded_Length (Max => Text'Length + 1);

      Value : SB.Bounded_String;
      Index : Natural := Text'First;

      function Hex4 return Natural is
         Code : Natural := 0;
      begin
         for Each in 1 .. 4 loop
            if Index > Text'Last then
               raise Program_Error with "Incomplete Unicode escape";
            end if;
            Code := Code * 16
              + (case Text (Index) is
                   when '0' .. '9' => Character'Pos (Text (Index)) - Character'Pos ('0'),
                   when 'a' .. 'f' => Character'Pos (Text (Index)) - Character'Pos ('a') + 10,
                   when 'A' .. 'F' => Character'Pos (Text (Index)) - Character'Pos ('A') + 10,
                   when others => raise Program_Error with "Invalid Unicode escape");
            Index := Index + 1;
         end loop;
         return Code;
      end Hex4;

      procedure Append_Code (Code : Natural) is
         procedure Byte (Number : Natural) is
         begin
            SB.Append (Value, Character'Val (Number));
         end Byte;
      begin
         if Code < 16#80# then
            Byte (Code);
         elsif Code < 16#800# then
            Byte (16#C0# + Code / 64);
            Byte (16#80# + Code mod 64);
         elsif Code < 16#10000# then
            Byte (16#E0# + Code / 4096);
            Byte (16#80# + Code / 64 mod 64);
            Byte (16#80# + Code mod 64);
         else
            Byte (16#F0# + Code / 262_144);
            Byte (16#80# + Code / 4096 mod 64);
            Byte (16#80# + Code / 64 mod 64);
            Byte (16#80# + Code mod 64);
         end if;
      end Append_Code;

      use Ada.Characters.Latin_1;
   begin
      while Index <= Text'Last loop
         declare
            C : constant Character := Text (Index);
         begin
            Index := Index + 1;
            if C = '\' then
               if Index > Text'Last then
                  raise Program_Error with "Incomplete string escape";
               end if;
               declare
                  Escaped : constant Character := Text (Index);
               begin
                  Index := Index + 1;
                  case Escaped is
                     when '"' | '\' | '/' => SB.Append (Value, Escaped);
                     when 'b' => SB.Append (Value, BS);
                     when 'f' => SB.Append (Value, FF);
                     when 'n' => SB.Append (Value, LF);
                     when 'r' => SB.Append (Value, CR);
                     when 't' => SB.Append (Value, HT);
                     when 'u' =>
                        declare
                           Code : Natural := Hex4;
                        begin
                           if Code in 16#D800# .. 16#DBFF# then
                              if Index + 1 > Text'Last or else Text (Index) /= '\'
                                or else Text (Index + 1) /= 'u'
                              then
                                 raise Program_Error with "Missing low surrogate";
                              end if;
                              Index := Index + 2;
                              declare
                                 Low : constant Natural := Hex4;
                              begin
                                 if Low not in 16#DC00# .. 16#DFFF# then
                                    raise Program_Error with "Invalid low surrogate";
                                 end if;
                                 Code := 16#10000# + (Code - 16#D800#) * 1024 + (Low - 16#DC00#);
                              end;
                           elsif Code in 16#DC00# .. 16#DFFF# then
                              raise Program_Error with "Unexpected low surrogate";
                           end if;
                           Append_Code (Code);
                        end;
                     when others => raise Program_Error with "Invalid string escape";
                  end case;
               end;
            else
               if Ada.Characters.Handling.Is_Control (C) then
                  raise Program_Error with "Unexpected control character";
               end if;
               SB.Append (Value, C);
            end if;
         end;
      end loop;
      return SB.To_String (Value);
   end Unescape;

   -----------------------------------------------------------------------------
   --                             Memory allocator                            --
   -----------------------------------------------------------------------------

   function Create_Array
     (Object : Memory_Allocator;
      Depth  : Positive) return Array_Offset is
   begin
      if Depth > Object.Maximum_Depth then
         raise Constraint_Error with
           "Maximum depth (" & Object.Maximum_Depth'Image & ") exceeded";
      end if;
      return Array_Offset (Object.Array_Levels (Depth).Length);
   end Create_Array;

   function Create_Object
     (Object : Memory_Allocator;
      Depth  : Positive) return Array_Offset is
   begin
      if Depth > Object.Maximum_Depth then
         raise Constraint_Error with
           "Maximum depth (" & Object.Maximum_Depth'Image & ") exceeded";
      end if;
      return Array_Offset (Object.Object_Levels (Depth).Length);
   end Create_Object;

   -----------------------------------------------------------------------------
   --                              Constructors                               --
   -----------------------------------------------------------------------------

   function Create_String
     (Stream : Streams.Stream_Ptr;
      Offset, Length : Streams.AS.Stream_Element_Offset) return JSON_Value is
   begin
      return (Kind => String_Kind, Stream => Stream,
        String_Offset => Offset, String_Length => Length);
   end Create_String;

   function Create_Integer (Value : Integer_Type) return JSON_Value is
   begin
      return (Kind => Integer_Kind, Integer_Value => Value);
   end Create_Integer;

   function Create_Float (Value : Float_Type) return JSON_Value is
   begin
      return (Kind => Float_Kind, Float_Value => Value);
   end Create_Float;

   function Create_Boolean (Value : Boolean) return JSON_Value is
   begin
      return (Kind => Boolean_Kind, Boolean_Value => Value);
   end Create_Boolean;

   function Create_Null return JSON_Value is
   begin
      return (Kind => Null_Kind);
   end Create_Null;

   function Create_Array
     (Allocator : Memory_Allocator_Ptr;
      Depth     : Positive) return JSON_Value is
   begin
      return (Kind      => Array_Kind,
              Allocator => Allocator,
              Depth     => Depth,
              Offset    => Create_Array (Allocator.all, Depth),
              Length    => 0);
   end Create_Array;

   function Create_Object
     (Allocator : Memory_Allocator_Ptr;
      Depth     : Positive) return JSON_Value is
   begin
      return (Kind      => Object_Kind,
              Allocator => Allocator,
              Depth     => Depth,
              Offset    => Create_Object (Allocator.all, Depth),
              Length    => 0);
   end Create_Object;

   -----------------------------------------------------------------------------
   --                                  Value                                  --
   -----------------------------------------------------------------------------

   function "=" (Left : String; Right : JSON_Value) return Boolean is
     (if Right.Kind = String_Kind then
        Left = Unescape (Right.Stream.Get_String (Right.String_Offset, Right.String_Length))
      else
        False);

   function Value (Object : JSON_Value) return String is
   begin
      if Object.Kind = String_Kind then
         return Unescape (Object.Stream.Get_String
           (Object.String_Offset, Object.String_Length));
      else
         raise Invalid_Type_Error with "Value not a string";
      end if;
   end Value;

   function Value (Object : JSON_Value) return Boolean is
   begin
      if Object.Kind = Boolean_Kind then
         return Object.Boolean_Value;
      else
         raise Invalid_Type_Error with "Value not a boolean";
      end if;
   end Value;

   function Value (Object : JSON_Value) return Integer_Type is
   begin
      if Object.Kind = Integer_Kind then
         return Object.Integer_Value;
      else
         raise Invalid_Type_Error with "Value not a integer";
      end if;
   end Value;

   function Value (Object : JSON_Value) return Float_Type is
   begin
      if Object.Kind = Float_Kind then
         return Object.Float_Value;
      elsif Object.Kind = Integer_Kind then
         return Float_Type (Object.Integer_Value);
      else
         raise Invalid_Type_Error with "Value not a float";
      end if;
   end Value;

   -----------------------------------------------------------------------------

   function Length (Object : JSON_Value) return Natural is
   begin
      if Object.Kind in Array_Kind | Object_Kind then
         return Object.Length;
      else
         raise Invalid_Type_Error with "Value not an object or array";
      end if;
   end Length;

   function Contains (Object : JSON_Value; Key : String) return Boolean is
   begin
      if Object.Kind = Object_Kind then
         for Index in 1 .. Object.Length loop
            declare
               Pair : Key_Value_Pair renames Object.Allocator.Object_Levels
                 (Object.Depth).Element (Object.Offset + Index);
            begin
               if Key = Pair.Key then
                  return True;
               end if;
            end;
         end loop;

         return False;
      else
         raise Invalid_Type_Error with "Value not an object";
      end if;
   end Contains;

   function Get (Object : JSON_Value; Index : Positive) return JSON_Value is
   begin
      if Object.Kind = Array_Kind then
         return Object.Allocator.Array_Levels (Object.Depth).Element
           (Object.Offset + Index).Value;
      else
         raise Invalid_Type_Error with "Value not an array";
      end if;
   exception
      when Constraint_Error =>
         raise Constraint_Error with "JSON array has no element at index" & Index'Image;
   end Get;

   function Get (Object : JSON_Value; Key : String) return JSON_Value is
   begin
      if Object.Kind = Object_Kind then
         for Index in 1 .. Object.Length loop
            declare
               Pair : constant Key_Value_Pair := Object.Allocator.Object_Levels
                 (Object.Depth).Element (Object.Offset + Index);
            begin
               if Key = Pair.Key then
                  return Pair.Element;
               end if;
            end;
         end loop;
         raise Constraint_Error with "JSON object has no key '" & Key & "'";
      else
         raise Invalid_Type_Error with "Value not an object";
      end if;
   end Get;

   procedure Append (Object : in out JSON_Value; Value : JSON_Value) is
   begin
      declare
         Length : constant Natural
           := Natural (Object.Allocator.Array_Levels (Object.Depth).Length);
      begin
         --  Assert that Object is the last array in a particular level
         --  so that its elements form a continuous array
         pragma Assert (Length = Object.Offset + Object.Length);
      end;

      Object.Allocator.Array_Levels (Object.Depth).Append
        (Array_Value'(Kind => Value.Kind, Value => Value));
      Object.Length := Object.Length + 1;
   end Append;

   procedure Insert
     (Object : in out JSON_Value;
      Key    : JSON_Value;
      Value  : JSON_Value;
      Check_Duplicate_Keys : Boolean) is
   begin
      if Check_Duplicate_Keys and then Object.Contains (Key.Value) then
         raise Constraint_Error with "JSON object already has key '" & Key.Value & "'";
      end if;

      declare
         Length : constant Natural
           := Natural (Object.Allocator.Object_Levels (Object.Depth).Length);
      begin
         --  Assert that Object is the last object in a particular level
         --  so that its key-value pairs form a continuous array
         pragma Assert (Length = Object.Offset + Object.Length);
      end;
      pragma Assert (Key.Kind = String_Kind);

      Object.Allocator.Object_Levels (Object.Depth).Append
        (Key_Value_Pair'(Kind => Value.Kind, Key => Key, Element => Value));
      Object.Length := Object.Length + 1;
   end Insert;

   -----------------------------------------------------------------------------

   function Constant_Reference (Object : JSON_Value; Index : Positive)
     return JSON_Value renames Get;

   function Constant_Reference (Object : JSON_Value; Key : String)
     return JSON_Value renames Get;

   function Constant_Reference (Object : aliased JSON_Value; Position : Cursor)
     return JSON_Value is
   begin
      case Position.Kind is
         when Array_Kind =>
            return Object.Allocator.Array_Levels (Position.Data.Depth).Element
              (Position.Data.Offset + Position.Index).Value;
         when Object_Kind =>
            return Object.Allocator.Object_Levels (Position.Data.Depth).Element
              (Position.Data.Offset + Position.Index).Key;
      end case;
   end Constant_Reference;

   function Has_Element (Position : Cursor) return Boolean is
     (Position.Index <= Position.Data.Length);

   overriding
   function First (Object : Iterator) return Cursor is
   begin
      return (Kind => Object.Kind, Data => Object.Data, Index => 1);
   end First;

   overriding
   function Next
     (Object   : Iterator;
      Position : Cursor) return Cursor is
   begin
      return (Kind => Position.Kind, Data => Position.Data, Index => Position.Index + 1);
   end Next;

   function Iterate (Object : JSON_Value)
     return Value_Iterator_Interfaces.Forward_Iterator'Class is
   begin
      if Object.Kind in Array_Kind | Object_Kind then
         return Iterator'(Kind => Object.Kind, Data => Object);
      else
         raise Program_Error with "Can only iterate over an array or object";
      end if;
   end Iterate;

   -----------------------------------------------------------------------------
   --                                 Helpers                                 --
   -----------------------------------------------------------------------------

   function Get_Array_Or_Empty
     (Object : JSON_Value; Key : String) return JSON_Value is
   begin
      if Object.Contains (Key) then
         return Object.Get (Key);
      else
         return
           (Kind      => Array_Kind,
            Allocator => Object.Allocator,
            Depth     => Object.Allocator.Array_Levels'First,
            Offset    => 0,
            Length    => 0);
      end if;
   end Get_Array_Or_Empty;

   function Get_Object_Or_Empty
     (Object : JSON_Value; Key : String) return JSON_Value is
   begin
      if Object.Contains (Key) then
         return Object.Get (Key);
      else
         return
           (Kind      => Object_Kind,
            Allocator => Object.Allocator,
            Depth     => Object.Allocator.Object_Levels'First,
            Offset    => 0,
            Length    => 0);
      end if;
   end Get_Object_Or_Empty;

   function Get
     (Object  : JSON_Value;
      Key     : String;
      Default : Integer_Type) return JSON_Value is
   begin
      if Object.Contains (Key) then
         return Object.Get (Key);
      else
         return Create_Integer (Default);
      end if;
   end Get;

   function Get
     (Object  : JSON_Value;
      Key     : String;
      Default : Float_Type) return JSON_Value is
   begin
      if Object.Contains (Key) then
         return Object.Get (Key);
      else
         return Create_Float (Default);
      end if;
   end Get;

   function Get
     (Object  : JSON_Value;
      Key     : String;
      Default : Boolean) return JSON_Value is
   begin
      if Object.Contains (Key) then
         return Object.Get (Key);
      else
         return Create_Boolean (Default);
      end if;
   end Get;

   -----------------------------------------------------------------------------
   --                                  Image                                   -
   -----------------------------------------------------------------------------

   function Image_String (Object : JSON_Value) return String is
      Text : String renames Object.Stream.Get_String
        (Object.String_Offset, Object.String_Length);
   begin
      --  A string backed by a stream is always escaped. The tokenizer
      --  will verify that the string does not contain unexpected characters
      return '"' & Text & '"';
   end Image_String;

   function Image_Integer (Object : JSON_Value) return String is
      Result : constant String := Integer_Type'Image (Object.Integer_Value);
   begin
      if Object.Integer_Value < 0 then
         return Result;
      else
         return Result (2 .. Result'Last);
      end if;
   end Image_Integer;

   function Image_Float (Object : JSON_Value) return String is
      Result : constant String := Float_Type'Image (Object.Float_Value);
   begin
      if Object.Float_Value < 0.0 then
         return Result;
      else
         return Result (2 .. Result'Last);
      end if;
   end Image_Float;

   function Image_Boolean (Object : JSON_Value) return String is
     (if Object.Boolean_Value then "true" else "false");

   function Image_Array (Object : JSON_Value) return String is
      Index  : Natural             := 0;
      Result : SU.Unbounded_String := +"[";
   begin
      for Element of Object loop
         Index := Index + 1;
         if Index > 1 then
            SU.Append (Result, ",");
         end if;
         SU.Append (Result, Element.Image);
      end loop;
      SU.Append (Result, "]");
      return +Result;
   end Image_Array;

   function Image_Object (Object : JSON_Value) return String is
      Index  : Natural             := 0;
      Result : SU.Unbounded_String := +"{";
   begin
      for Key of Object loop
         Index := Index + 1;
         if Index > 1 then
            SU.Append (Result, ',');
         end if;
         SU.Append (Result, '"' & Key.Value & '"');
         SU.Append (Result, ':');
         SU.Append (Result, Object.Get (Key.Value).Image);
      end loop;
      SU.Append (Result, '}');
      return +Result;
   end Image_Object;

   function Image (Object : JSON_Value) return String is
   begin
      case Object.Kind is
         when Array_Kind =>
            return Image_Array (Object);
         when Object_Kind =>
            return Image_Object (Object);
         when String_Kind =>
            return Image_String (Object);
         when Integer_Kind =>
            return Image_Integer (Object);
         when Float_Kind =>
            return Image_Float (Object);
         when Boolean_Kind =>
            return Image_Boolean (Object);
         when Null_Kind =>
            return "null";
      end case;
   end Image;

end JSON.Types;
