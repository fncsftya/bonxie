with Canvas_VM;
with Items;
with Items.Links;
with View.Canvas_Items;
with View.Links;

package body View.Canvas_Links is

   use type Items.Id;

   function Link_Count (Item : Session) return Natural
   is (Canvas_VM.Link_Count (Item.Canvas_Model.Model));

   procedure Link_Items (Item : in out Session; From, To : Positive) is
   begin
      Canvas_VM.Join
        (Item.Canvas_Model.Model,
         Canvas_Items.Nth (Item, From),
         Canvas_Items.Nth (Item, To),
         Items.Links.Top,
         Items.Links.Top);
   end Link_Items;

   function Link_Selected (Item : Session) return Boolean
   is (Canvas_VM.Selected_Link (Item.Canvas_Model.Model) /= 0);

   function Link_Description (Item : Session; Number : Positive) return String is
      Each : constant Items.Links.Link := Canvas_VM.Link_At (Item.Canvas_Model.Model, Number);
   begin
      return
        Items.Links.Strokes'Image (Each.Stroke)
        & ' '
        & Items.Links.Endings'Image (Each.Ending)
        & ' '
        & Integer'Image (Each.Color)
        & ' '
        & Items.Links.Sides'Image (Each.To_Side);
   end Link_Description;

   function Pin_Count (Item : Session) return Natural
   is (Links.Shown_Pins (Item));

end View.Canvas_Links;
