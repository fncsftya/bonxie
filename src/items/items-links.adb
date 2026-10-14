with Repository.Link;

package body Items.Links is

   function Is_Linked
     (Store : Projects.Store; A, B : Id) return Boolean is
     (Repository.Link.Exists (Store, A, B));

   procedure Add_Link
     (Store : in out Projects.Store; Made : Link; Added : out Boolean) is
   begin
      Added := not Is_Linked (Store, Made.From, Made.To);
      if Added then
         Repository.Link.Insert (Store, Made);
      end if;
   end Add_Link;

   procedure Delete_Link (Store : in out Projects.Store; Key : Id) is
   begin
      Repository.Link.Delete (Store, Key);
   end Delete_Link;

   procedure Set_Link_Style
     (Store  : in out Projects.Store;
      Key    : Id;
      Stroke : Strokes;
      Ending : Endings;
      Color  : Link_Colors) is
   begin
      Repository.Link.Set_Style (Store, Key, Stroke, Ending, Color);
   end Set_Link_Style;

   procedure Move_Link
     (Store : in out Projects.Store;
      Key   : Id;
      To    : Id;
      Side  : Sides;
      Moved : out Boolean) is
   begin
      Repository.Link.Move (Store, Key, To, Side, Moved);
   end Move_Link;

   procedure Load_Links
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Link_List) is
   begin
      Repository.Link.Load (Store, Project, Result);
   end Load_Links;

end Items.Links;
