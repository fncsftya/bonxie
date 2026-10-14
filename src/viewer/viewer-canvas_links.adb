with Items;
with Items.Links;
with Items.Windows;
with Viewer.Canvas_Items;
with Viewer.Links;

package body Viewer.Canvas_Links is

   use type Items.Id;

   function Link_Count (Item : Session) return Natural is
     (Item.Linking.Link_Set.Count);

   procedure Link_Items (Item : in out Session; From, To : Positive) is
      Added : Boolean;
   begin
      Items.Links.Add_Link
        (Item.Nav.Store,
         (From => Items.Windows.Details
                    (Item.Windows (Canvas_Items.Nth (Item, From))).Key,
          To   => Items.Windows.Details
                    (Item.Windows (Canvas_Items.Nth (Item, To))).Key,
          others => <>),
         Added);
      Links.Reload (Item);
   end Link_Items;

   function Link_Selected (Item : Session) return Boolean is
     (Item.Linking.Link_Key /= 0);

   function Link_Description
     (Item : Session; Number : Positive) return String
   is
      Each : Items.Links.Link renames Item.Linking.Link_Set.Links (Number);
   begin
      return Items.Links.Strokes'Image (Each.Stroke) & ' '
        & Items.Links.Endings'Image (Each.Ending) & ' '
        & Integer'Image (Each.Color) & ' '
        & Items.Links.Sides'Image (Each.To_Side);
   end Link_Description;

   function Pin_Count (Item : Session) return Natural is
     (Links.Shown_Pins (Item));

end Viewer.Canvas_Links;
