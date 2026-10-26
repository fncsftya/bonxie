with Pomarine.Text_Areas;

package body Items.Windows.Parts is

   package Editors renames Pomarine.Widgets.Editors;
   package Views renames Pomarine.Widgets.Page_Views;

   function Across_Of (Item : Window) return Float is
     (if Items.Models.Details (Item.Model.all).Kind = Source
      then (if Items.Models.Is_Paged (Item.Model.all) then Views.Scrolled_Across (Item.Pages)
            else Pomarine.Widgets.Pictures.Scrolled_Across (Item.Picture)) else 0.0);

   function Scroll_Of (Item : in out Window) return Float is
     (if Items.Models.Details (Item.Model.all).Kind = Source
      then (if Items.Models.Is_Paged (Item.Model.all) then Views.Scrolled (Item.Pages)
            else Pomarine.Widgets.Pictures.Scrolled (Item.Picture))
      else Pomarine.Text_Areas.Scroll_Top (Editors.Area (Item.Body_Text).all));

   function Shown_Marks_Version (Item : Window) return Natural is
     (if Items.Models.Is_Paged (Item.Model.all) then Views.Marks_Version (Item.Pages)
      else Pomarine.Widgets.Pictures.Marks_Version (Item.Picture));

end Items.Windows.Parts;
