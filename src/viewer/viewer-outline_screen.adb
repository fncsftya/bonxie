with Texts.Documents;
with Items.Windows;
with Projects;
with Viewer.Outlines;
with Viewer.Section_Links;

package body Viewer.Outline_Screen is

   function Section_Count (Item : Session) return Natural is
     (Outlines.Section_Count (Item));

   function Section_Title (Item : Session; Row : Positive) return String is
     (Outlines.Section_Title (Item, Row));

   function Project_Title (Item : Session) return String is
     (Texts.Documents.Whole (Item.Outline_View.Name_Doc));

   function Project_Description (Item : Session) return String is
     (Texts.Documents.Whole (Item.Outline_View.Desc_Doc));

   function Section_Colour (Item : Session; Row : Positive) return Natural is
     (Outlines.Section_At (Item, Row).Colour);

   function Section_Item (Item : Session; Row : Positive) return String is
      Key : constant Long_Integer := Outlines.Section_At (Item, Row).Linked;
   begin
      for Each of Item.Windows loop
         if Items.Windows.Is_Assigned (Each) and then Long_Integer (Items.Windows.Details (Each).Key) = Key
           and then Key /= 0
         then
            return Projects.Titles.To_String (Items.Windows.Details (Each).Title);
         end if;
      end loop;
      return "";
   end Section_Item;

   procedure Open_Link_Menu (Item : in out Session; Which : Items.Slot) is
   begin
      Section_Links.Open (Item, Which);
   end Open_Link_Menu;

   function Link_Menu_Rows (Item : Session) return Natural is (Section_Links.Row_Count (Item));

   function Link_Menu_Row_Enabled (Item : Session; Row : Positive) return Boolean is
     (Section_Links.Row_Enabled (Item, Row));

   function Link_Menu_Row_Checked (Item : Session; Row : Positive) return Boolean is
     (Section_Links.Row_Checked (Item, Row));

   procedure Choose_Link_Row (Item : in out Session; Row : Positive) is
   begin
      Section_Links.Choose (Item, Row);
   end Choose_Link_Row;

   function Generate_Enabled (Item : Session) return Boolean is
     (Outlines.Generate_Enabled (Item));

   function Take_Reply (Item : in out Session; Reply : String) return Boolean is
     (Outlines.Take_Reply (Item, Reply));

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
