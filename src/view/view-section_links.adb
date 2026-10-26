with Items.Models;
with Pomarine.UI.Menus;
with Items;
with Projects;
with Pomarine.Boxes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Menus;
with Projects.Sections;
with View.Canvas_Items;
with View.Style;
with Icon_Set;
with Pomarine.Icons;

package body View.Section_Links is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Rows renames Pomarine.UI.Menus;
   package Menus renames Pomarine.Widgets.Menus;

   use type Items.Kinds;

   Heading_Text : constant String := "LINK TO OUTLINE";
   Menu_Wide    : constant Float := 220.0;
   Max_Menu     : constant Float := 320.0;
   Min_Height   : constant Float := 80.0;
   --  Of the menu, in points: the most it is as tall as, and the least it
   --  is held to when there is little room.

   function Section_Of (Item : Session; Which : Items.Slot) return Natural is
     (Outlines.Section_Of_Item (Item, Long_Integer (Items.Models.Details (Item.Models (Which)).Key)));

   function Ink_Of (Item : Session; Section : Positive) return Pomarine.Themes.Slot is
     (Style.Section_Ink (Outlines.Section_At (Item, Section).Colour));

   function Is_Shown (Item : Session) return Boolean is (Item.Section_Menu.Which /= 0);

   function Is_Open_For (Item : Session; Which : Items.Slot) return Boolean is
     (Item.Section_Menu.Which = Which);

   function Changes (Item : Session) return Natural is (Item.Section_Menu.Changes);

   procedure Close (Item : in out Session) is
   begin
      Item.Section_Menu.Which := 0;
      Item.Section_Menu.Page := 0;
      Widgets.Set_Visible (Item.Section_Menu.Menu, False);
   end Close;

   procedure Place (Item : in out Session);
   --  Put the menu by its button: above it on the canvas, where the
   --  button is at the foot of a window, and below it on a page.

   procedure Place (Item : in out Session) is
      Parts  : Section_Menu_Parts renames Item.Section_Menu;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Edge   : constant Float := Pomarine.Boxes.Offset (Pixels);
      Box    : constant Items.Frame :=
        (if Parts.Page = 0
         then Items.Windows.Outline_Box (Item.Windows (Parts.Which))
         else (Left   => Widgets.Left_Of (Item.Docs.Pages (Parts.Page).Outline_Button),
               Top    => Widgets.Top_Of (Item.Docs.Pages (Parts.Page).Outline_Button),
               Width  => Widgets.Width_Of (Item.Docs.Pages (Parts.Page).Outline_Button),
               Height => Widgets.Height_Of (Item.Docs.Pages (Parts.Page).Outline_Button)));
      Wide   : constant Float := Menu_Wide * Pixels;
      Full   : constant Float := Menus.Height_For (Parts.Menu) * Pixels;
      Gap    : constant Float := Style.Menu_Gap * Pixels;
      Panel_Top : constant Float := Widgets.Top_Of (Content_Panel (Item).all);
      Panel_Left : constant Float := Widgets.Left_Of (Content_Panel (Item).all);
      Panel_Wide : constant Float := Widgets.Width_Of (Content_Panel (Item).all);
      --  What the menu has room in: above the button, or below it; never
      --  over it.
      Above  : constant Float := Float'Max (0.0, Box.Top - Panel_Top - Gap);
      Below  : constant Float :=
        Float'Max (0.0, Panel_Top + Widgets.Height_Of (Content_Panel (Item).all) - (Box.Top + Box.Height) - Gap);
      Up     : constant Boolean :=
        (if Above >= Full and then Below >= Full then Parts.Page = 0
         elsif Above >= Full then True
         elsif Below >= Full then False
         else Above > Below);
      --  Where the window is nearer an edge it opens from: the way with
      --  room for all of it, the one it is for if both have, or else the
      --  roomier, with the rows scrolled.
      Room   : constant Float := Float'Min (Max_Menu * Pixels, (if Up then Above else Below));
      Before : constant Float := Menus.Shown_Height (Parts.Menu);
      Left   : constant Float :=
        Float'Max (0.0, Float'Min (Box.Left + Box.Width + Edge - Wide - Panel_Left, Panel_Wide - Wide));
   begin
      Menus.Set_Max_Height
        (Parts.Menu, (if Full <= Room then 0.0 else Float'Max (Min_Height, Room / Pixels)));
      if Menus.Shown_Height (Parts.Menu) /= Before then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
      declare
         High : constant Float := Menus.Shown_Height (Parts.Menu) * Pixels;
         Top  : constant Float :=
           Float'Max (0.0, (if Up then Box.Top - Gap - High else Box.Top + Box.Height + Gap) - Panel_Top);
      begin
         if Float'Rounding (Left) /= Parts.Left or else Float'Rounding (Top) /= Parts.Top then
            Parts.Left := Float'Rounding (Left);
            Parts.Top := Float'Rounding (Top);
            Layouts.Set_Layout
              (Parts.Menu,
               Position => (Left => Parts.Left, Top => Parts.Top, others => <>),
               Unit => Layouts.Device_Pixels);
            Layouts.Set_Layout (Parts.Menu, Width => Menu_Wide);
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         end if;
      end;
   end Place;

   procedure Open (Item : in out Session; Which : Items.Slot; Page : Natural := 0) is
      Parts : Section_Menu_Parts renames Item.Section_Menu;
      Total : constant Natural := Outlines.Section_Count (Item);
      Own   : constant Natural := Section_Of (Item, Which);
      Content : Rows.Content := [Rows.Row (Menus.Heading, Heading_Text)];
   begin
      if Parts.Which = Which and then Parts.Page = Page then
         Close (Item);
         return;
      end if;
      Close (Item);
      for Each of Parts.Rows loop
         Each := 0;
      end loop;
      Parts.Remove := 0;
      for Each in 1 .. Total loop
         declare
            Section : constant Projects.Sections.Section := Outlines.Section_At (Item, Each);
            Row     : Positive;
         begin
            Content.Append
              (Rows.Row (Menus.Check, Projects.Sections.Title_Texts.To_String (Section.Title),
                         Checked => Each = Own, Swatch => Style.Section_Ink (Section.Colour)));
            Row := Rows.Count (Content);
            Parts.Rows (Row) := Each;
         end;
      end loop;
      if Total = 0 then
         Content.Append (Rows.Row (Menus.Note, "No sections yet"));
      end if;
      if Own /= 0 then
         Content.Append (Rows.Row (Menus.Separator));
         Content.Append (Rows.Row (Menus.Action, "Remove link", Icon => Pomarine.Icons.Shown (Icon_Set.Delete)));
         Parts.Remove := Rows.Count (Content);
      end if;
      Rows.Set_Content (Parts.Menu, Content);
      Parts.Which := Which;
      Parts.Page := Page;
      Parts.Left := -1.0E9;
      Widgets.Set_Visible (Parts.Menu, True);
      Widgets.Raise_To_Front (Parts.Menu);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Place (Item);
      if Own /= 0 then
         Menus.Reveal (Parts.Menu, Own + 1);
      end if;
   end Open;

   function Row_Count (Item : Session) return Natural is (Menus.Row_Count (Item.Section_Menu.Menu));

   function Row_Enabled (Item : Session; Row : Positive) return Boolean is
     (Menus.Is_Enabled (Item.Section_Menu.Menu, Row));

   function Row_Checked (Item : Session; Row : Positive) return Boolean is
     (Menus.Is_Checked (Item.Section_Menu.Menu, Row));

   procedure Name_After
     (Item : in out Session; Which : Items.Slot; Section : Projects.Sections.Section);
   --  Give the item the section's name, if it has none of its own: it is
   --  untitled, or called as a section is.

   procedure Name_After
     (Item : in out Session; Which : Items.Slot; Section : Projects.Sections.Section)
   is
      Own   : constant String := Projects.Titles.To_String (Items.Models.Details (Item.Models (Which)).Title);
      Name  : constant String := Projects.Sections.Title_Texts.To_String (Section.Title);
      Named : Boolean := Own = Canvas_Items.Untitled or else Own = Canvas_Items.Untitled_Document;
   begin
      for Each in 1 .. Outlines.Section_Count (Item) loop
         Named := Named
           or else Projects.Sections.Title_Texts.To_String (Outlines.Section_At (Item, Each).Title) = Own;
      end loop;
      if Named and then Name /= "" and then Name /= Own then
         Items.Models.Set_Title_Text (Item.Models (Which), Name);
      end if;
   end Name_After;

   procedure Link_To (Item : in out Session; Which : Items.Slot; Section : Positive) is
      Picked : constant Projects.Sections.Section := Outlines.Section_At (Item, Section);
   begin
      Projects.Sections.Link
        (Item.Nav.Store, Picked.Key, Long_Integer (Items.Models.Details (Item.Models (Which)).Key));
      Name_After (Item, Which, Picked);
      Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
      Outlines.Reload (Item);
      Update (Item);
   end Link_To;

   procedure Joined (Item : in out Session; Which : Items.Slot) is
      Own : Natural;
   begin
      Outlines.Reload (Item);
      Own := Section_Of (Item, Which);
      if Own /= 0 then
         Name_After (Item, Which, Outlines.Section_At (Item, Own));
      end if;
      Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
   end Joined;

   procedure Choose (Item : in out Session; Row : Positive) is
      Parts : Section_Menu_Parts renames Item.Section_Menu;
   begin
      if Parts.Which = 0 or else not Menus.Is_Enabled (Parts.Menu, Row) then
         return;
      end if;
      declare
         Which   : constant Items.Slot := Parts.Which;
         Section : constant Natural :=
           (if Row in 1 .. Parts.Rows.Count then Parts.Rows (Row) else 0);
         Own     : constant Natural := Section_Of (Item, Which);
      begin
         Close (Item);
         if Section /= 0 and then Section /= Own then
            Link_To (Item, Which, Section);
         elsif (Section = Own and then Own /= 0) or else Row = Parts.Remove then
            --  Ticked again, or the row to take it away: let go.
            Projects.Sections.Unlink
              (Item.Nav.Store, Long_Integer (Items.Models.Details (Item.Models (Which)).Key));
            Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
            Outlines.Reload (Item);
            Update (Item);
         end if;
      end;
   end Choose;

   procedure Open_Page_Menu (Item : in out Session; Rank : Positive) is
   begin
      if Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) then
         Open (Item, Trees.Page_At (Item.Docs.Ordering, Rank), Page => Rank);
      end if;
   end Open_Page_Menu;

   procedure Update (Item : in out Session) is
      Parts : Section_Menu_Parts renames Item.Section_Menu;
   begin
      for Which in 1 .. Item.Windows.Count loop
         if Items.Windows.Is_Assigned (Item.Windows (Which))
           and then Items.Models.Details (Item.Models (Which)).Kind = Items.Note
         then
            declare
               Section : constant Natural := Section_Of (Item, Which);
            begin
               Items.Windows.Set_Outline_Link
                 (Item.Windows (Which),
                  Linked => Section /= 0,
                  Ink    => (if Section /= 0 then Ink_Of (Item, Section) else Pomarine.Themes.Border),
                  Open   => Parts.Which = Which and then Parts.Page = 0);
            end;
         end if;
      end loop;
      for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
         Pomarine.Widgets.Buttons.Set_Selected
           (Item.Docs.Pages (Rank).Outline_Button, Parts.Which /= 0 and then Parts.Page = Rank);
      end loop;
      if Parts.Which /= 0 then
         if not Items.Windows.Is_Assigned (Item.Windows (Parts.Which)) then
            Close (Item);
         else
            Place (Item);
         end if;
      end if;
   end Update;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Parts  : Section_Menu_Parts renames Item.Section_Menu;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Parts.Which = 0 or else Widgets.Contains (Parts.Menu, X * Pixels, Y * Pixels) then
         return;
      end if;
      --  Its own button, pressed, is to put it away when clicked.
      if Parts.Page = 0 then
         declare
            Box : constant Items.Frame := Items.Windows.Outline_Box (Item.Windows (Parts.Which));
         begin
            if X * Pixels in Box.Left .. Box.Left + Box.Width
              and then Y * Pixels in Box.Top .. Box.Top + Box.Height
            then
               return;
            end if;
         end;
      elsif Widgets.Contains (Item.Docs.Pages (Parts.Page).Outline_Button, X * Pixels, Y * Pixels) then
         return;
      end if;
      Close (Item);
   end Pressed;

end View.Section_Links;
