with Items.Models;
with Items.Sources;
with Items.Windows;
with View.Canvas_Items;

package body View.Canvas_Windows is

   use type Items.Models.Tools;

   function Window (Item : Session; Row : Positive) return Items.Slot is
     (Canvas_Items.Nth (Item, Row));
   --  The window of the Rowth item.

   function Search_In_Item (Item : Session; Row : Positive) return Boolean is
     (Search_VM.Is_Showing (Item.Searching.Model) and then Items.Windows.Owns
        (Item.Windows (Window (Item, Row)), Item.Searching.Field'Unrestricted_Access));

   procedure Search_Button_Point (Item : Session; Button : Positive; X, Y : out Float) is
      package Widgets renames Pomarine.Widgets;
      Part : constant Widgets.Widget_Access :=
        (case Button is
           when 1 => Item.Searching.Previous'Unrestricted_Access,
           when 2 => Item.Searching.Next'Unrestricted_Access,
           when others => Item.Searching.Close'Unrestricted_Access);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      X := (Widgets.Left_Of (Part.all) + Widgets.Width_Of (Part.all) / 2.0) / Pixels;
      Y := (Widgets.Top_Of (Part.all) + Widgets.Height_Of (Part.all) / 2.0) / Pixels;
   end Search_Button_Point;

   function Item_Count (Item : Session) return Natural is
     (Canvas_Items.Count (Item));

   procedure Add_Unchosen_Source
     (Item : in out Session; Name : String := "Untitled source") is
   begin
      Canvas_Items.Add (Item, Name, Items.Source);
   end Add_Unchosen_Source;

   procedure Add_Item
     (Item : in out Session;
      Name : String := "Untitled item";
      Kind : Items.Kinds := Items.Note)
   is
      Before : constant Natural := Canvas_Items.Count (Item);
   begin
      Canvas_Items.Add (Item, Name, Kind);
      if Items."=" (Kind, Items.Source) and then Canvas_Items.Count (Item) > Before then
         Canvas_Items.Choose_Origin
           (Item, Window (Item, Canvas_Items.Count (Item)), Items.Remote);
      end if;
   end Add_Item;

   function Item_Origin (Item : Session; Row : Positive) return Items.Origins is
     (Items.Models.Details (Item.Models (Window (Item, Row))).Origin);

   procedure Pick_File (Item : in out Session; Row : Positive; Path : String) is
   begin
      Canvas_Items.File_Picked (Item, Window (Item, Row), Path);
   end Pick_File;

   function Item_Text_Selected (Item : Session; Row : Positive) return String is
     (Items.Windows.Selected_Shown_Text (Item.Windows (Window (Item, Row))));

   function Item_Shown_Text (Item : Session; Row : Positive) return String is
     (Items.Models.Shown_Text (Item.Models (Window (Item, Row))));

   function Item_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Models.Details (Item.Models (Window (Item, Row))).Title));

   function Item_Text (Item : Session; Row : Positive) return String is
     (Items.Models.Text (Item.Models (Window (Item, Row))));

   function Item_Stored_Text (Item : Session; Row : Positive) return String is
     (Items.Models.Stored_Text (Item.Models (Window (Item, Row))));

   function Item_Kind (Item : Session; Row : Positive) return Items.Kinds is
     (Items.Models.Details (Item.Models (Window (Item, Row))).Kind);

   function Item_Status (Item : Session; Row : Positive) return String is
     (Items.Models.Status (Item.Models (Window (Item, Row))));

   function Item_State (Item : Session; Row : Positive) return Items.States is
     (Items.Models.Details (Item.Models (Window (Item, Row))).State);

   function Item_Frame (Item : Session; Row : Positive) return Items.Frame is
     (Items.Models.Details (Item.Models (Window (Item, Row))).Where);

   function Item_Box (Item : Session; Row : Positive) return Items.Frame is
     (Items.Windows.Box (Item.Windows (Window (Item, Row))));

   function Is_Editing_Title (Item : Session; Row : Positive) return Boolean is
     (Items.Windows.Is_Editing_Title (Item.Windows (Window (Item, Row))));

   function Search_Is_Open (Item : Session) return Boolean is (Search_VM.Is_Showing (Item.Searching.Model));
   function Search_Count (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Search_Count (Item.Windows (Window (Item, Row))));
   function Search_Current (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Search_Current (Item.Windows (Window (Item, Row))));

   function Item_Words (Item : Session; Row : Positive) return Natural is
     (Items.Models.Words (Item.Models (Window (Item, Row))));

   procedure Dictate_Live
     (Item : in out Session; Row : Positive; Said : String) is
   begin
      Items.Windows.Set_Live_Dictation
        (Item.Windows (Window (Item, Row)), Said);
   end Dictate_Live;

   procedure Dictate_Into
     (Item : in out Session; Row : Positive; Said : String) is
   begin
      Items.Windows.Add_Dictation (Item.Windows (Window (Item, Row)), Said);
   end Dictate_Into;

   procedure Pin_Capture_Time (Item : in out Session; To : Projects.Seconds) is
   begin
      Item.Nav.Pinned_Time := To;
   end Pin_Capture_Time;

   function Is_Capturing (Item : Session) return Boolean is
     (Canvas_Items.Busy (Item));

   function Item_Zoom (Item : Session; Row : Positive) return Float is
     (Items.Models.Details (Item.Models (Window (Item, Row))).Zoom);

   function Item_Picture_File (Item : Session; Row : Positive) return String
   is
     (Items.Sources.Image_File
        (Item.Nav.Store, Open_Key (Item),
         Items.Models.Details (Item.Models (Window (Item, Row))).Key));

   function Item_Is_Paged (Item : Session; Row : Positive) return Boolean is
     (Items.Models.Is_Paged (Item.Models (Window (Item, Row))));

   function Item_Recognized (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Recognized_Count (Item.Windows (Window (Item, Row))));

   function Item_Selected_Text (Item : Session; Row : Positive) return String
   is
     (Items.Windows.Selected_Text (Item.Windows (Window (Item, Row))));

   function Item_Marks (Item : Session; Row : Positive) return Natural is
     (Items.Models.Mark_Count (Item.Models (Window (Item, Row))));

   function Item_Highlighting (Item : Session; Row : Positive) return Boolean
   is
     (Items.Models.Tool (Item.Models (Window (Item, Row))) = Items.Models.Highlighter);

   function Item_Erasing (Item : Session; Row : Positive) return Boolean is
     (Items.Models.Tool (Item.Models (Window (Item, Row))) = Items.Models.Eraser);

end View.Canvas_Windows;
