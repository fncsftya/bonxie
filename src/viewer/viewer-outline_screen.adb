with Texts.Documents;
with Viewer.Outlines;

package body Viewer.Outline_Screen is

   function Section_Count (Item : Session) return Natural is
     (Outlines.Section_Count (Item));

   function Section_Title (Item : Session; Row : Positive) return String is
     (Outlines.Section_Title (Item, Row));

   function Project_Title (Item : Session) return String is
     (Texts.Documents.Whole (Item.Outline_View.Name_Doc));

   function Project_Description (Item : Session) return String is
     (Texts.Documents.Whole (Item.Outline_View.Desc_Doc));

   procedure Add_Section (Item : in out Session) is
   begin
      Outlines.Add_Section (Item);
   end Add_Section;

   procedure Move_Section (Item : in out Session; From, To : Positive) is
   begin
      Outlines.Move_Section (Item, From, To);
   end Move_Section;

   procedure Remove_Section (Item : in out Session; Row : Positive) is
   begin
      Outlines.Remove_Section (Item, Row);
   end Remove_Section;

end Viewer.Outline_Screen;
