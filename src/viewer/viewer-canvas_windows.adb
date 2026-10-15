with Items.Sources;
with Items.Windows;
with Pomarine.Widgets.Pictures;
with Viewer.Canvas_Items;

package body Viewer.Canvas_Windows is

   function Window (Item : Session; Row : Positive) return Items.Slot is
     (Canvas_Items.Nth (Item, Row));
   --  The window of the Rowth item.

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
     (Items.Windows.Details (Item.Windows (Window (Item, Row))).Origin);

   procedure Pick_File (Item : in out Session; Row : Positive; Path : String) is
   begin
      Canvas_Items.File_Picked (Item, Window (Item, Row), Path);
   end Pick_File;

   function Item_Text_Selected (Item : Session; Row : Positive) return String is
     (Items.Windows.Selected_Shown_Text (Item.Windows (Window (Item, Row))));

   function Item_Shown_Text (Item : Session; Row : Positive) return String is
     (Items.Windows.Shown_Text (Item.Windows (Window (Item, Row))));

   function Item_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Windows.Details (Item.Windows (Window (Item, Row))).Title));

   function Item_Text (Item : Session; Row : Positive) return String is
     (Items.Windows.Text (Item.Windows (Window (Item, Row))));

   function Item_Kind (Item : Session; Row : Positive) return Items.Kinds is
     (Items.Windows.Details (Item.Windows (Window (Item, Row))).Kind);

   function Item_Status (Item : Session; Row : Positive) return String is
     (Items.Windows.Status (Item.Windows (Window (Item, Row))));

   function Item_State (Item : Session; Row : Positive) return Items.States is
     (Items.Windows.Details (Item.Windows (Window (Item, Row))).State);

   function Item_Frame (Item : Session; Row : Positive) return Items.Frame is
     (Items.Windows.Details (Item.Windows (Window (Item, Row))).Where);

   function Item_Box (Item : Session; Row : Positive) return Items.Frame is
     (Items.Windows.Box (Item.Windows (Window (Item, Row))));

   function Is_Editing_Title (Item : Session; Row : Positive) return Boolean is
     (Items.Windows.Is_Editing_Title (Item.Windows (Window (Item, Row))));

   function Item_Words (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Words (Item.Windows (Window (Item, Row))));

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
     (Items.Windows.Details (Item.Windows (Window (Item, Row))).Zoom);

   function Item_Picture_File (Item : Session; Row : Positive) return String
   is
     (Items.Sources.Image_File
        (Item.Nav.Store, Item.Opened.Current,
         Items.Windows.Details (Item.Windows (Window (Item, Row))).Key));

   function Item_Recognized (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Recognized_Count (Item.Windows (Window (Item, Row))));

   function Item_Selected_Text (Item : Session; Row : Positive) return String
   is
     (Items.Windows.Selected_Text (Item.Windows (Window (Item, Row))));

   function Item_Marks (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Mark_Count (Item.Windows (Window (Item, Row))));

   function Item_Highlighting (Item : Session; Row : Positive) return Boolean
   is
     (Pomarine.Widgets.Pictures."=" (Items.Windows.Tool
        (Item.Windows (Window (Item, Row))),
         Pomarine.Widgets.Pictures.Highlighter));

   function Item_Erasing (Item : Session; Row : Positive) return Boolean is
     (Pomarine.Widgets.Pictures."=" (Items.Windows.Tool
        (Item.Windows (Window (Item, Row))), Pomarine.Widgets.Pictures.Eraser));

end Viewer.Canvas_Windows;
