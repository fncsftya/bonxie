with Ada.Containers.Vectors;

package body Exports.HTML is

   package Kind_Stacks is new Ada.Containers.Vectors (Positive, Block_Kinds);

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Opening (Which : Mark; Address : String) return String
   is (case Which is
         when Underlined => "<u>",
         when Struck     => "<s>",
         when Bold       => "<b>",
         when Italic     => "<i>",
         when Linked     => "<a href=""" & Escaped (Address) & """>");

   function Closing (Which : Mark) return String
   is (case Which is
         when Underlined => "</u>",
         when Struck     => "</s>",
         when Bold       => "</b>",
         when Italic     => "</i>",
         when Linked     => "</a>");

   function Inline (Spans : Span_Vectors.Vector) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for Each of Spans loop
         for Which in Mark loop
            if Each.Marks (Which) then
               Unbounded.Append (Made, Opening (Which, Unbounded.To_String (Each.Address)));
            end if;
         end loop;
         Unbounded.Append (Made, Escaped (Unbounded.To_String (Each.Words)));
         for Which in reverse Mark loop
            if Each.Marks (Which) then
               Unbounded.Append (Made, Closing (Which));
            end if;
         end loop;
      end loop;
      return Unbounded.To_String (Made);
   end Inline;

   function Body_Of (Items : Block_Vectors.Vector) return String is
      Made   : Unbounded.Unbounded_String;
      Lists  : Kind_Stacks.Vector;
      Quoted : Boolean := False;
      Headed : Natural := 0;

      function Tag (Kind : Block_Kinds) return String
      is (if Kind = Number then "ol" else "ul");

      procedure Close_Lists (Down_To : Natural) is
      begin
         while Natural (Lists.Length) > Down_To loop
            Unbounded.Append (Made, "</li></" & Tag (Lists.Last_Element) & ">");
            Lists.Delete_Last;
            if Lists.Is_Empty then
               Unbounded.Append (Made, ASCII.LF);
            end if;
         end loop;
      end Close_Lists;

      procedure Reach_Item (Kind : Block_Kinds; Level : Positive) is
      begin
         Close_Lists (Level);
         if Natural (Lists.Length) = Level and then Lists.Last_Element = Kind then
            Unbounded.Append (Made, "</li><li>");
            return;
         end if;
         Close_Lists (Level - 1);
         while Natural (Lists.Length) < Level loop
            Unbounded.Append (Made, "<" & Tag (Kind) & "><li>");
            Lists.Append (Kind);
         end loop;
      end Reach_Item;
   begin
      for Each of Items loop
         if Each.Kind not in Bullet | Number then
            Close_Lists (0);
         end if;
         if Each.Quoted /= Quoted then
            Close_Lists (0);
            Unbounded.Append (Made, (if Each.Quoted then "<blockquote>" else "</blockquote>") & ASCII.LF);
            Quoted := Each.Quoted;
         end if;
         case Each.Kind is
            when Heading         =>
               Headed := Headed + 1;
               declare
                  Level : constant String := Image (Each.Level);
               begin
                  Unbounded.Append
                    (Made,
                     "<h" & Level & " id=""s" & Image (Headed) & """>" & Inline (Each.Spans) & "</h" & Level & ">");
               end;

            when Paragraph       =>
               Unbounded.Append
                 (Made,
                  (if Each.Indent = 0 then "<p>" else "<p style=""margin-left:" & Image (2 * Each.Indent) & "em"">")
                  & Inline (Each.Spans)
                  & "</p>");

            when Bullet | Number =>
               Reach_Item (Each.Kind, Each.Indent + 1);
               Unbounded.Append (Made, Inline (Each.Spans));
         end case;
         if Each.Kind not in Bullet | Number then
            Unbounded.Append (Made, ASCII.LF);
         end if;
      end loop;
      Close_Lists (0);
      if Quoted then
         Unbounded.Append (Made, "</blockquote>" & ASCII.LF);
      end if;
      return Unbounded.To_String (Made);
   end Body_Of;

   function Body_Of (Item : Texts.Documents.Document) return String
   is (Body_Of (Blocks_Of (Item)));

   function Page (Item : Texts.Documents.Document; Title : String) return String
   is ("<!DOCTYPE html>"
       & ASCII.LF
       & "<html lang=""en"">"
       & ASCII.LF
       & "<head><meta charset=""utf-8""/><meta name=""viewport"" content=""width=device-width, initial-scale=1""/>"
       & ASCII.LF
       & "<title>"
       & Escaped (Title)
       & "</title>"
       & ASCII.LF
       & "<style>body{max-width:40em;margin:2em auto;padding:0 1em;font:1.1em/1.5 Georgia,serif}"
       & "blockquote{margin:1em 0 1em 1em;padding-left:1em;border-left:3px solid #bbb}</style>"
       & ASCII.LF
       & "</head>"
       & ASCII.LF
       & "<body>"
       & ASCII.LF
       & Body_Of (Item)
       & "</body>"
       & ASCII.LF
       & "</html>"
       & ASCII.LF);

end Exports.HTML;
