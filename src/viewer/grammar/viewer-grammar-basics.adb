with Ada.Strings;
with Ada.Strings.Fixed;
with Pomarine.Widgets;
with Grammar_VM;
with Pomarine.Widgets.Editors;

package body Viewer.Grammar.Basics is

   package Editors renames Pomarine.Widgets.Editors;

   use type Docs.Version;
   use type Harper.Request_Id;

   function Active (Item : Session) return Boolean is
     (Item.Nav.Shown = Project and then Item.Toolbar.Mode = Write and then Item.Grammar_Checks.Enabled);

   function Image (Total : Natural) return String is
     (Ada.Strings.Fixed.Trim (Total'Image, Ada.Strings.Both));

   function Valid (Item : Session; Row : Grammar_Row) return Boolean is
     (Row.Token /= 0 and then Row.Rank <= Item.Reading.Write_Count
      and then Row.Token = Item.Grammar_Checks.Documents (Row.Rank).Token
      and then Item.Grammar_Checks.Documents (Row.Rank).Serial =
        Docs.Serial (Editors.Document (Item.Docs.Pages (Row.Rank).Text).all)
      and then Item.Grammar_Checks.Documents (Row.Rank).Seen =
        Docs.Current (Editors.Document (Item.Docs.Pages (Row.Rank).Text).all));

   function Flagged (Item : Session; Row : Grammar_Row) return String is
      Doc : Docs.Document renames Editors.Document (Item.Docs.Pages (Row.Rank).Text).all;
      From : constant Texts.Position := Advance (Doc, Row.First, Row.Lint.Location.First);
      To   : constant Texts.Position := Advance (Doc, Row.First, Row.Lint.Location.Last);
   begin
      return (if From.Paragraph = To.Paragraph and then From.Index < To.Index
              then Docs.Slice (Doc, From.Paragraph, From.Index, To.Index) else "");
   end Flagged;

   procedure Load_Rules (Item : in out Session) is
   begin
      Grammar_VM.Open (Item.Grammar_Model.Model, Item.Opened.Current);
   end Load_Rules;

   function Advance (Doc : Docs.Document; From : Texts.Position; Bytes : Natural) return Texts.Position is
      At_Point : Texts.Position := From;
      Left     : Natural := Bytes;
   begin
      loop
         declare
            Remaining : constant Natural := Docs.Byte_Length (Doc, At_Point.Paragraph) - At_Point.Index + 1;
         begin
            if Left <= Remaining then
               At_Point.Index := At_Point.Index + Left;
               return At_Point;
            end if;
            pragma Assert (At_Point.Paragraph < Docs.Count (Doc));
            Left := Left - Remaining - 1;
            At_Point := (At_Point.Paragraph + 1, 1);
         end;
      end loop;
   end Advance;

end Viewer.Grammar.Basics;
