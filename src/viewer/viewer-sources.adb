with Items.Marks;
with Items.Readers;
with Items.Windows;

package body Viewer.Sources is

   function Source_Count (Item : Session) return Natural is
     (Item.Reading.Source_Total);

   function Source_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Windows.Details
           (Item.Windows (Item.Reading.Source_Order (Row))).Title));

   function Source_Is_Open (Item : Session; Row : Positive) return Boolean is
     (Item.Reading.Pinned_Slot = Item.Reading.Source_Order (Row)
      or else Items."="
                (Items.Readers.Details
                   (Item.Reading.Readers
                      (Item.Reading.Source_Order (Row))).State,
                 Items.Open));

   function Source_Marks (Item : Session; Row : Positive) return Natural is
      Kept : Items.Marks.Mark_List;
   begin
      Items.Readers.Get_Marks
        (Item.Reading.Readers (Item.Reading.Source_Order (Row)), Kept);
      return Kept.Count;
   end Source_Marks;

   function Pinned_Source (Item : Session) return Natural is
   begin
      for Row in 1 .. Item.Reading.Source_Total loop
         if Item.Reading.Source_Order (Row) = Item.Reading.Pinned_Slot then
            return Row;
         end if;
      end loop;
      return 0;
   end Pinned_Source;

end Viewer.Sources;
