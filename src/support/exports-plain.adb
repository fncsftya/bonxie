package body Exports.Plain is

   Bullet_Mark : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#), ' '];

   function Of_Document (Item : Texts.Documents.Document) return String is
      Made     : Unbounded.Unbounded_String;
      Previous : Block_Kinds := Paragraph;
      Quoted   : Boolean := False;
      Begun    : Boolean := False;
   begin
      for Each of Blocks_Of (Item) loop
         declare
            Together : constant Boolean :=
              Begun and then Each.Kind in Bullet | Number and then Previous = Each.Kind and then Quoted = Each.Quoted;
            Lead     : constant String :=
              (if Each.Quoted then "> " else "")
              & [1 .. 2 * Each.Indent => ' ']
              & (case Each.Kind is
                   when Bullet => Bullet_Mark,
                   when Number => Unbounded.To_String (Each.Figure) & ". ",
                   when others => "");
         begin
            if Begun and then not Together then
               Unbounded.Append (Made, ASCII.LF);
            end if;
            Unbounded.Append (Made, Lead & Words_Of (Each) & ASCII.LF);
            Previous := Each.Kind;
            Quoted := Each.Quoted;
            Begun := True;
         end;
      end loop;
      return Unbounded.To_String (Made);
   end Of_Document;

end Exports.Plain;
