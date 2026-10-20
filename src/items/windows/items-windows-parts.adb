with Items.Sources;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Pomarine.Text_Areas;

package body Items.Windows.Parts is

   package Editors renames Pomarine.Widgets.Editors;
   package Views renames Pomarine.Widgets.Page_Views;

   use type Ada.Calendar.Time;

   function Day (Taken : Projects.Seconds) return String is
      Image : constant String :=
        Ada.Calendar.Formatting.Image
          (Ada.Calendar.Formatting.Time_Of (1970, 1, 1, Time_Zone => 0)
           + Duration (Taken),
           Time_Zone => 0);
      Months : constant array (1 .. 12) of String (1 .. 3) :=
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      Date  : constant Positive := Positive'Value (Image (9 .. 10));
   begin
      return Ada.Strings.Fixed.Trim (Date'Image, Ada.Strings.Both) & " "
        & Months (Positive'Value (Image (6 .. 7))) & " " & Image (1 .. 4);
   end Day;

   function Is_Unchosen (Item : Window) return Boolean is
     (Item.Details.Kind = Source and then Item.Details.Origin = Unchosen);

   function Is_Text_Source (Item : Window) return Boolean is
     (Item.Details.Kind = Source and then Item.Details.Origin /= Unchosen
      and then Items.Sources.Is_Text (Items.Extensions.To_String (Item.Details.Document)));

   function Is_Open_Source (Item : Window) return Boolean is
     (Item.Details.Kind = Source and then Item.Details.State = Open);

   function Across_Of (Item : Window) return Float is
     (if Item.Details.Kind = Source
      then (if Item.Paged then Views.Scrolled_Across (Item.Pages)
            else Pomarine.Widgets.Pictures.Scrolled_Across (Item.Picture)) else 0.0);

   function Scroll_Of (Item : in out Window) return Float is
     (if Item.Details.Kind = Source
      then (if Item.Paged then Views.Scrolled (Item.Pages)
            else Pomarine.Widgets.Pictures.Scrolled (Item.Picture))
      else Pomarine.Text_Areas.Scroll_Top (Editors.Area (Item.Body_Text).all));

   function Page_Status (Item : Window) return String is
     ("Page" & Item.Details.Page'Image & " of" & Item.Details.Page_Count'Image);

   procedure Clear_Recognized (Item : in out Window) is
   begin
      Pomarine.Widgets.Pictures.Set_Words (Item.Picture, null);
      Item.Recognized.Count := 0;
      Item.Recognized.Length := 0;
      Item.Recognized.Truncated := False;
   end Clear_Recognized;

   function Shown_Marks_Version (Item : Window) return Natural is
     (if Item.Paged then Views.Marks_Version (Item.Pages)
      else Pomarine.Widgets.Pictures.Marks_Version (Item.Picture));

end Items.Windows.Parts;
