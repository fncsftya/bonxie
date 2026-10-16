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
      Result : String (1 .. 512);
      Last   : Natural := 0;
   begin
      for Each of Item.Windows loop
         if Items.Windows.Is_Assigned (Each)
           and then Outlines.Section_Of_Item (Item, Long_Integer (Items.Windows.Details (Each).Key)) = Row
         then
            declare
               Name : constant String := Projects.Titles.To_String (Items.Windows.Details (Each).Title);
            begin
               Result (Last + 1 .. Last + Name'Length + 1) := Name & ",";
               Last := Last + Name'Length + 1;
            end;
         end if;
      end loop;
      return Result (1 .. Last);
   end Section_Item;

   procedure Open_Link_Menu (Item : in out Session; Which : Items.Slot) is
   begin
      Section_Links.Open (Item, Which);
   end Open_Link_Menu;

   function Link_Menu_Open (Item : Session) return Boolean is (Section_Links.Is_Shown (Item));

   function Link_Menu_Rows (Item : Session) return Natural is (Section_Links.Row_Count (Item));

   function Link_Menu_Row_Enabled (Item : Session; Row : Positive) return Boolean is
     (Section_Links.Row_Enabled (Item, Row));

   function Link_Menu_Row_Checked (Item : Session; Row : Positive) return Boolean is
     (Section_Links.Row_Checked (Item, Row));

   procedure Choose_Link_Row (Item : in out Session; Row : Positive) is
   begin
      Section_Links.Choose (Item, Row);
   end Choose_Link_Row;

   function Section_Notes (Item : Session; Row : Positive) return String is
     (Outlines.Section_Notes (Item, Row));

   function Notes_Shown (Item : Session; Row : Positive) return Boolean is
     (Outlines.Notes_Shown (Item, Row));

   procedure Toggle_Notes (Item : in out Session; Row : Positive) is
   begin
      Outlines.Toggle_Notes (Item, Row);
   end Toggle_Notes;

   function Generate_Enabled (Item : Session) return Boolean is
     (Outlines.Generate_Enabled (Item));

   procedure Write_Notes_Point (Item : in out Session; Row : Positive; X, Y : out Float) is
      Button : Pomarine.Widgets.Buttons.Button renames Item.Section_View.Heads (Row).Notes;
      Pixels : constant Float := Pomarine.Widgets.Density (Item.Root.Widgets);
   begin
      X := (Pomarine.Widgets.Left_Of (Button) + Pomarine.Widgets.Width_Of (Button) / 2.0) / Pixels;
      Y := (Pomarine.Widgets.Top_Of (Button) + Pomarine.Widgets.Height_Of (Button) / 2.0) / Pixels;
   end Write_Notes_Point;

   function Generate_Label (Item : Session) return String is
     (Pomarine.Widgets.Buttons.Label (Item.Outline_View.Generate_Button));

   function Generate_Menu_Shown (Item : Session) return Boolean is
     (Outlines.Generate_Menu_Shown (Item));

   procedure Generate_Point (Item : in out Session; Caret : Boolean; X, Y : out Float) is
   begin
      Outlines.Generate_Point (Item, Caret, X, Y);
   end Generate_Point;

   procedure Choose_Generate (Item : in out Session; Row : Positive) is
   begin
      Outlines.Choose_Generate (Item, Row);
   end Choose_Generate;

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
