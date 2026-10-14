with Repository.Item;
with Repository.Word;

package body Items.Words is

   Words_Version : constant := 1;
   --  Of how the words are put in order (see Vision.Layout): words kept
   --  by an earlier version are looked for again.

   procedure Clear_Words (Store : in out Projects.Store; Key : Id) is
   begin
      Repository.Word.Delete (Store, Key);
      Repository.Item.Set_Recognized (Store, Key, 0, 0);
   end Clear_Words;

   procedure Save_Words
     (Store   : in out Projects.Store;
      Key     : Id;
      Found   : Vision.Result;
      At_Time : Projects.Seconds) is
   begin
      Repository.Word.Replace (Store, Key, Found, At_Time, Words_Version);
   end Save_Words;

   function Has_Words
     (Store : Projects.Store; Key : Id) return Boolean is
     (Repository.Item.Is_Recognized (Store, Key, Words_Version));

   procedure Load_Words
     (Store : Projects.Store; Key : Id; Into : in out Vision.Result) is
   begin
      Repository.Word.Load (Store, Key, Into);
   end Load_Words;

end Items.Words;
