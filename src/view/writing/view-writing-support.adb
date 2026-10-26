with Writing_Sources_VM;
with Writing_VM;
with Items.Models;
with Ada.Strings.Fixed;
with View.Outlines;

package body View.Writing.Support is

   package Windows renames Items.Windows;

   package Models renames Items.Models;

   use type Items.Kinds;

   function Is_Note (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Models.Details (Item.Models (Which)).Kind = Items.Note);

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Models.Details (Item.Models (Which)).Kind = Items.Source);

   function Is_Section (Item : Session; Dir : Natural) return Boolean is
     (Dir /= 0 and then Item.Docs.Dirs (Dir).Section /= 0);

   function Parent_Of (Item : Session; Dir : Natural) return Natural is
     (Writing_VM.Parent_Of (Item.Docs.Dirs, Dir));

   function Depth (Item : Session; Dir : Natural) return Natural is
     (Writing_VM.Depth (Item.Docs.Dirs, Dir));

   function Section_Directory (Item : Session; Dir : Natural) return Natural is
     (Writing_VM.Section_Directory (Item.Docs.Dirs, Dir));

   function Within (Item : Session; Dir, Ancestor : Natural) return Boolean is
     (Writing_VM.Within (Item.Docs.Dirs, Dir, Ancestor));

   function Title_Of (Item : Session; Which : Items.Slot) return String is
     (Projects.Titles.To_String
        (Models.Details (Item.Models (Which)).Title));

   function Rank_Of (Item : Session; Which : Items.Slot) return Natural is
     (Trees.Rank_Of (Item.Docs.Ordering, Which));

   function Row_Of (Item : Session; Which : Items.Slot) return Natural is
     (Writing_Sources_VM.Row_Of (Item.Reading.Sources, Which));

   function In_View (Item : Session; Which : Items.Slot) return Boolean is
     (Writing_VM.In_View (Item.Docs.Navigation, Item.Docs.Dirs, Trees.Directory_Of (Item.Docs.Ordering, Which)));

   function Leaf_Row (Item : Session; Which : Items.Slot) return Natural is
     (Trees.Leaf_Row (Item.Docs.Ordering, Which));

   function Dir_Row (Item : Session; Dir : Positive) return Natural is
     (Trees.Dir_Row (Item.Docs.Ordering, Dir));

   function Documents_In (Item : Session; Dir : Positive) return Natural is
      Total : Natural := 0;
   begin
      for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
         if Within (Item, Trees.Directory_Of (Item.Docs.Ordering, Trees.Page_At (Item.Docs.Ordering, Rank)), Dir) then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Documents_In;

   function Block_End (Item : Session; Row : Positive) return Positive is
     (Trees.Block_End (Item.Docs.Ordering, Item.Docs.Dirs, Row));

   function Count_Image (Number : Natural) return String is
     (Ada.Strings.Fixed.Trim (Number'Image, Ada.Strings.Both));

   function Dir_Of_Section (Item : Session; Section : Positive) return Natural is
   begin
      for Dir in 1 .. Item.Docs.Dirs.Count loop
         if Item.Docs.Dirs (Dir).Section
            = Long_Integer (Outlines.Section_At (Item, Section).Key)
         then
            return Dir;
         end if;
      end loop;
      return 0;
   end Dir_Of_Section;

   function In_Writing (Item : Session) return Boolean is
     (Takes_Gestures (Item) and then View_Mode (Item) = Write);

end View.Writing.Support;
