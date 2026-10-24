with Items;
with Items.Records;

package body Home_VM.Stored is

   use type Items.Kinds;

   procedure Open (Self : in out Projects_Kept; Store : not null access Projects.Store) is
   begin
      Self.Store := Store.all'Unrestricted_Access;
   end Open;

   overriding procedure Recent (Self : in out Projects_Kept; Into : out Projects.Recent_List) is
   begin
      Projects.Recent (Self.Store.all, Into);
   end Recent;

   overriding procedure Count_Items
     (Self : in out Projects_Kept; Key : Projects.Id; Documents, Sources : out Natural)
   is
      Found : Items.Info_List;
   begin
      Documents := 0;
      Sources := 0;
      Items.Records.Load (Self.Store.all, Key, Found);
      for Each of Found.Slice loop
         if Each.Kind = Items.Source then
            Sources := Sources + 1;
         else
            Documents := Documents + 1;
         end if;
      end loop;
   end Count_Items;

   overriding procedure Rename (Self : in out Projects_Kept; Key : Projects.Id; Words : String) is
   begin
      Projects.Rename (Self.Store.all, Key, Words);
   end Rename;

   overriding procedure Delete (Self : in out Projects_Kept; Key : Projects.Id) is
   begin
      Projects.Delete (Self.Store.all, Key);
   end Delete;

end Home_VM.Stored;
