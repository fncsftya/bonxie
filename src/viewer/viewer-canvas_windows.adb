with Items.Windows;
with UI.Widgets.Pictures;
with Viewer.Canvas_Items;

package body Viewer.Canvas_Windows is

   function Window (Item : Session; Row : Positive) return Items.Slot is
     (Canvas_Items.Nth (Item, Row));
   --  The window of the Rowth item.

   function Item_Count (Item : Session) return Natural is
     (Canvas_Items.Count (Item));

   procedure Add_Item
     (Item : in out Session;
      Name : String := "Untitled item";
      Kind : Items.Kinds := Items.Note)
     renames Canvas_Items.Add;

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
     (Canvas_Items.Capturing (Item));

   function Item_Zoom (Item : Session; Row : Positive) return Float is
     (Items.Windows.Details (Item.Windows (Window (Item, Row))).Zoom);

   function Item_Picture_File (Item : Session; Row : Positive) return String
   is
     (Items.Image_File
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
     (UI.Widgets.Pictures."=" (Items.Windows.Tool
        (Item.Windows (Window (Item, Row))),
         UI.Widgets.Pictures.Highlighter));

   function Item_Erasing (Item : Session; Row : Positive) return Boolean is
     (UI.Widgets.Pictures."=" (Items.Windows.Tool
        (Item.Windows (Window (Item, Row))), UI.Widgets.Pictures.Eraser));

end Viewer.Canvas_Windows;
