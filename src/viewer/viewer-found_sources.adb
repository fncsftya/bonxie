with Items.Readers;
with Items.Windows;
with Projects;
with Pomarine.Semantics;
with Pomarine.Widgets;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Toasts;
with Viewer.Canvas_Items;
with Viewer.Find_Sources;

package body Viewer.Found_Sources is

   package Toasts renames Pomarine.Widgets.Toasts;
   package Menus renames Pomarine.Widgets.Menus;

   function Toast_Shown (Item : Session) return Boolean is (Item.Finder.Shown);

   function Toast_Message (Item : Session) return String is (Toasts.Message (Item.Finder.Toast));

   function Toast_Action (Item : Session) return String is (Toasts.Action (Item.Finder.Toast));

   procedure Toast_Action_Point (Item : Session; X, Y : out Float) is
      Pixels : constant Float := Pomarine.Widgets.Density (Item.Root.Widgets);
      Toast  : Toasts.Toast renames Item.Finder.Toast;
   begin
      X := (Pomarine.Widgets.Left_Of (Toast) + Pomarine.Widgets.Width_Of (Toast)) / Pixels - 24.0;
      Y := (Pomarine.Widgets.Top_Of (Toast) + Pomarine.Widgets.Height_Of (Toast) / 2.0) / Pixels - 1.0;
   end Toast_Action_Point;

   function Review_Shown (Item : Session) return Boolean is (Item.Finder.Review_Open);

   function Review_Row_Count (Item : Session) return Natural is (Menus.Row_Count (Item.Finder.Review));

   function Review_Row (Item : Session; Row : Positive) return String is
     (Menus.Text_Of (Item.Finder.Review, Row));

   function Preview_Shown (Item : Session) return Boolean is
     (Items.Readers.Is_Assigned (Item.Finder.Preview)
      and then Items."=" (Items.Readers.Details (Item.Finder.Preview).State, Items.Open));

   function Preview_Index (Item : Session) return Natural is (Item.Finder.Previewing);

   function Preview_Is_Paged (Item : Session) return Boolean is
     (Items.Extensions."/="
        (Items.Readers.Details (Item.Finder.Preview).Document, Items.Extensions.Null_Text));

   function Preview_Title (Item : Session) return String is
     (Projects.Titles.To_String (Items.Readers.Details (Item.Finder.Preview).Title));

   procedure Preview_Point (Item : Session; X, Y : out Float) is
      Pixels : constant Float := Pomarine.Widgets.Density (Item.Root.Widgets);
      Box    : constant Items.Frame := Items.Readers.Box (Item.Finder.Preview);
   begin
      X := (Box.Left + Box.Width / 2.0) / Pixels;
      Y := (Box.Top + Box.Height / 2.0) / Pixels;
   end Preview_Point;

   procedure Review_Row_Point (Item : Session; Row : Positive; X, Y : out Float) is
      Pixels : constant Float := Pomarine.Widgets.Density (Item.Root.Widgets);
      Facts  : Pomarine.Semantics.Description;
      Box    : Pomarine.Semantics.Rectangle;
   begin
      Menus.Describe_Part (Item.Finder.Review, Row, Facts, Box);
      X := (Box.Left + Box.Right) / 2.0 / Pixels;
      Y := (Box.Top + Box.Bottom) / 2.0 / Pixels;
   end Review_Row_Point;

   function Window_Of (Item : Session; Row : Positive) return Items.Slot is
     (Canvas_Items.Nth (Item, Row));

   procedure Adopt (Item : in out Session; Row : Positive) is
   begin
      Item.Finder.Owner := True;
      Item.Finder.Notice := False;
      Item.Finder.Project := Item.Opened.Current;
      Item.Finder.Note := Items.Windows.Details (Item.Windows (Window_Of (Item, Row))).Key;
   end Adopt;

   procedure Start (Item : in out Session; Row : Positive) is
   begin
      Find_Sources.Start (Item, Window_Of (Item, Row));
   end Start;

end Viewer.Found_Sources;
