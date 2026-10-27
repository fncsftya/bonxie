with Writing_Sources_VM;
with Items.Marks;
with Items.Readers;

package body View.Sources is

   function Source_Count (Item : Session) return Natural
   is (Writing_Sources_VM.Count (Item.Reading.Sources));

   function Source_Title (Item : Session; Row : Positive) return String
   is (Projects.Titles.To_String
         (Items.Models.Details (Item.Models (Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row))).Title));

   function Source_Is_Open (Item : Session; Row : Positive) return Boolean
   is (Item.Reading.Pinned_Slot = Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row)
       or else Items."="
                 (Items.Readers.Details (Item.Reading.Readers (Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row)))
                    .State,
                  Items.Open));

   function Source_Marks (Item : Session; Row : Positive) return Natural is
      Kept : Items.Marks.Mark_List;
   begin
      Items.Readers.Get_Marks (Item.Reading.Readers (Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row)), Kept);
      return Kept.Count;
   end Source_Marks;

   function Pinned_Source (Item : Session) return Natural is
   begin
      for Row in 1 .. Writing_Sources_VM.Count (Item.Reading.Sources) loop
         if Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row) = Item.Reading.Pinned_Slot then
            return Row;
         end if;
      end loop;
      return 0;
   end Pinned_Source;

end View.Sources;
