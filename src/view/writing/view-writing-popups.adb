with Writing_Sources_VM;
with Pomarine.UI.Menus;
with Items.Models;
with Items.Links;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Menus;
with View.Canvas_Items;
with View.Writing.Support;

package body View.Writing.Popups is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Rows renames Pomarine.UI.Menus;
   package Menus renames Pomarine.Widgets.Menus;
   package Models renames Items.Models;

   Heading_Words : constant String := "LINKED TO ";

   procedure Close_Menu (Item : in out Session) is
   begin
      if Item.Page_View.Menu_Page /= 0 then
         Buttons.Set_Selected
           (Item.Docs.Pages (Item.Page_View.Menu_Page).Sources_Button, False);
      end if;
      Item.Page_View.Menu_Page := 0;
      Widgets.Set_Visible (Item.Page_View.Menu, False);
   end Close_Menu;

   procedure Close_Context (Item : in out Session) is
   begin
      Item.Context.Context_Kind := No_Context;
      Item.Context.Context_Node := (others => <>);
      Widgets.Set_Visible (Item.Context.Context_Menu, False);
   end Close_Context;

   function Heading_For (Name : String) return String;
   --  The menu's heading: of the document's title, in capitals (of the
   --  letters of ASCII: the bytes of others are left as they are).

   function Heading_For (Name : String) return String is
      Shown : String := Name;
   begin
      for C of Shown loop
         if C in 'a' .. 'z' then
            C := Character'Val (Character'Pos (C) - 32);
         end if;
      end loop;
      return Heading_Words & Shown;
   end Heading_For;

   function Add_Row (Item : Session) return Positive is
     (Rows_Before + Natural'Max (1, Item.Page_View.Menu_Count) + 2);

   procedure Open_Menu (Item : in out Session; Rank : Positive) is
      Which_Doc : constant Items.Slot := Trees.Page_At (Item.Docs.Ordering, Rank);
      Key : constant Items.Id :=
        Models.Details (Item.Models (Which_Doc)).Key;
   begin
      if Item.Page_View.Menu_Page = Rank then
         Close_Menu (Item);
         return;
      end if;
      Close_Menu (Item);
      declare
         Content : Rows.Content :=
           [Rows.Row (Menus.Heading, Heading_For (Support.Title_Of (Item, Which_Doc)))];
      begin
         Item.Page_View.Menu_Count := 0;
         for Row in 1 .. Writing_Sources_VM.Count (Item.Reading.Sources) loop
            declare
               Which : constant Items.Slot := Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row);
            begin
               if Items.Links.Is_Linked
                    (Item.Nav.Store, Key,
                     Models.Details (Item.Models (Which)).Key)
               then
                  Item.Page_View.Menu_Count := Item.Page_View.Menu_Count + 1;
                  Item.Page_View.Menu_Slots (Item.Page_View.Menu_Count) := Which;
                  Content.Append
                    (Rows.Row (Menus.Check, Support.Title_Of (Item, Which),
                               Checked => Item.Reading.Pinned_Slot = Which,
                               Swatch => Canvas_Items.Source_Ink (Item, Which)));
               end if;
            end;
         end loop;
         if Item.Page_View.Menu_Count = 0 then
            Content.Append (Rows.Row (Menus.Note, "No linked sources"));
         end if;
         Content.Append (Rows.Row (Menus.Separator));
         Content.Append
           (Rows.Row (Menus.Action, "Add source", Menus.Primary, Icon => Pomarine.Icons.Shown (Icon_Set.Plus)));
         Rows.Set_Content (Item.Page_View.Menu, Content);
      end;
      pragma Assert (Menus.Row_Count (Item.Page_View.Menu) = Add_Row (Item));
      Item.Page_View.Menu_Page := Rank;
      Item.Page_View.Menu_Left := -1.0E9;
      Buttons.Set_Selected (Item.Docs.Pages (Rank).Sources_Button, True);
      Widgets.Set_Visible (Item.Page_View.Menu, True);
      Widgets.Raise_To_Front (Item.Page_View.Menu);
   end Open_Menu;

end View.Writing.Popups;
