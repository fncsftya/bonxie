with Ada.Strings.Fixed;
with Viewer.Gestures;
with Viewer.Outlines;

package body Viewer.Writing.Support is

   package Windows renames Items.Windows;

   use type Items.Kinds;

   function Is_Note (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Note);

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Source);

   function Is_Section (Item : Session; Dir : Natural) return Boolean is
     (Dir /= 0 and then Item.Docs.Dirs (Dir).Section /= 0);

   function Parent_Of (Item : Session; Dir : Natural) return Natural is
      use type Items.Id;
   begin
      if Dir /= 0 and then Item.Docs.Dirs (Dir).Parent /= 0 then
         for Each in 1 .. Item.Docs.Dirs.Count loop
            if Item.Docs.Dirs (Each).Key = Item.Docs.Dirs (Dir).Parent then
               return Each;
            end if;
         end loop;
      end if;
      return 0;
   end Parent_Of;

   function Depth (Item : Session; Dir : Natural) return Natural is
      At_Dir : Natural := Dir;
      Total : Natural := 0;
   begin
      while Parent_Of (Item, At_Dir) /= 0 loop
         At_Dir := Parent_Of (Item, At_Dir);
         Total := Total + 1;
         pragma Assert (Total < Item.Docs.Dirs.Count);
      end loop;
      return Total;
   end Depth;

   function Section_Directory (Item : Session; Dir : Natural) return Natural is
      At_Dir : Natural := Dir;
   begin
      for Step in 1 .. Item.Docs.Dirs.Count loop
         exit when At_Dir = 0 or else Is_Section (Item, At_Dir);
         At_Dir := Parent_Of (Item, At_Dir);
      end loop;
      return At_Dir;
   end Section_Directory;

   function Within (Item : Session; Dir, Ancestor : Natural) return Boolean is
      At_Dir : Natural := Dir;
   begin
      for Step in 0 .. Item.Docs.Dirs.Count loop
         if At_Dir = Ancestor then
            return True;
         end if;
         exit when At_Dir = 0;
         At_Dir := Parent_Of (Item, At_Dir);
      end loop;
      return False;
   end Within;

   function Title_Of (Item : Session; Which : Items.Slot) return String is
     (Projects.Titles.To_String
        (Windows.Details (Item.Windows (Which)).Title));

   function Rank_Of (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Rank in 1 .. Item.Reading.Write_Count loop
         if Item.Reading.Write_Order (Rank) = Which then
            return Rank;
         end if;
      end loop;
      return 0;
   end Rank_Of;

   function Row_Of (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Row in 1 .. Item.Reading.Source_Total loop
         if Item.Reading.Source_Order (Row) = Which then
            return Row;
         end if;
      end loop;
      return 0;
   end Row_Of;

   function In_View (Item : Session; Which : Items.Slot) return Boolean is
     (Item.Docs.Shown_Dir = 0
      or else Within (Item, Item.Docs.Doc_Dir (Which), Item.Docs.Shown_Dir));

   function Leaf_Row (Item : Session; Which : Items.Slot) return Natural is
   begin
      for Row in 1 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Kind = Document_Leaf
           and then Item.Docs.Tree (Row).Doc = Which
         then
            return Row;
         end if;
      end loop;
      return 0;
   end Leaf_Row;

   function Dir_Row (Item : Session; Dir : Positive) return Natural is
   begin
      for Row in 1 .. Item.Docs.Tree_Count loop
         if Item.Docs.Tree (Row).Kind = Directory_Node
           and then Item.Docs.Tree (Row).Dir = Dir
         then
            return Row;
         end if;
      end loop;
      return 0;
   end Dir_Row;

   function Documents_In (Item : Session; Dir : Positive) return Natural is
      Total : Natural := 0;
   begin
      for Rank in 1 .. Item.Reading.Write_Count loop
         if Within (Item, Item.Docs.Doc_Dir (Item.Reading.Write_Order (Rank)), Dir) then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Documents_In;

   function Block_End (Item : Session; Row : Positive) return Positive is
      Last : Positive := Row;
   begin
      if Item.Docs.Tree (Row).Kind = Directory_Node then
         while Last < Item.Docs.Tree_Count
           and then Item.Docs.Tree (Last + 1).Kind /= Overview_Node
           and then Within (Item, Item.Docs.Tree (Last + 1).Dir, Item.Docs.Tree (Row).Dir)
         loop
            Last := Last + 1;
         end loop;
      end if;
      return Last;
   end Block_End;

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
     (Gestures.Active (Item) and then Item.Toolbar.Mode = Write);

end Viewer.Writing.Support;
