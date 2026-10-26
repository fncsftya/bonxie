with Publish_VM;
with Pomarine.View_Models;
with Items.Models;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Markdown_Export;
with Projects.Sections;
with Pomarine.UI.Menus;
with Texts.Documents;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Selects;
with View.Outlines;
with View.Section_Links;
with View.Style;
with View.Writing.Support;

package body View.Writing.Publishing is

   package Widgets renames Pomarine.Widgets;
   package Models renames Items.Models;
   package Docs renames Texts.Documents;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Menus renames Pomarine.Widgets.Menus;
   package Selects renames Pomarine.Widgets.Selects;

   Stored_Header : constant String := "<version>1</version>";
   --  What Docs.Stored starts with, before its paragraphs.

   procedure Refresh_Publish (Item : in out Session) is
      Pane : Publish_Parts renames Item.Publish_View;
      Body_Markup : Ada.Strings.Unbounded.Unbounded_String;
      Marks : Markdown_Export.Writer;
      Previous_Section : Natural := 0;

      function Is_Blank (Words : String) return Boolean is
        (for all C of Words => C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR);

      procedure Heading (Words : String; Level : Positive) is
      begin
         if not Is_Blank (Words) then
            Ada.Strings.Unbounded.Append
              (Body_Markup,
               "<p k=""" & Ada.Strings.Fixed.Trim (Level'Image, Ada.Strings.Both) & """><b>"
               & Docs.Escaped (Words) & "</b></p>");
            Markdown_Export.Add_Heading (Marks, Level, Words);
         end if;
      end Heading;

      procedure Append (From : Docs.Document) is
         Markup : constant String := Docs.Stored (From);
      begin
         pragma Assert (Markup'Length >= Stored_Header'Length
                        and then Markup (Markup'First .. Markup'First + Stored_Header'Length - 1) = Stored_Header);
         if not Is_Blank (Docs.Whole (From)) then
            Ada.Strings.Unbounded.Append (Body_Markup, Markup (Markup'First + Stored_Header'Length .. Markup'Last));
            Markdown_Export.Add_Document (Marks, From);
         end if;
      end Append;
   begin
      for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
         declare
            Which : constant Items.Slot := Trees.Page_At (Item.Docs.Ordering, Rank);
            Section : constant Natural := Section_Links.Section_Of (Item, Which);
         begin
            if Publish_VM.Section_Headings (Pane.Options)
              and then Section /= 0 and then Section /= Previous_Section
            then
               Heading (Projects.Sections.Title_Texts.To_String (Outlines.Section_At (Item, Section).Title), 2);
            end if;
            Previous_Section := Section;
            if Publish_VM.Document_Headings (Pane.Options) then
               Heading (Support.Title_Of (Item, Which), 3);
            end if;
            Append (Models.Content_Document (Item.Models (Which)).all);
         end;
      end loop;
      if Ada.Strings.Unbounded.Length (Body_Markup) = 0 then
         Docs.Load (Pane.Doc, "");
      else
         Docs.Load_Stored (Pane.Doc, Stored_Header & Ada.Strings.Unbounded.To_String (Body_Markup));
      end if;
      Docs.Load (Pane.Source_Doc, Markdown_Export.Text (Marks));
      Widgets.Invalidate (Pane.Text);
      Widgets.Invalidate (Pane.Source_Text);
   end Refresh_Publish;

   procedure Close_Format_Menu (Item : in out Session) is
      Pane : Publish_Parts renames Item.Publish_View;
   begin
      if Publish_VM.Format_Open (Pane.Options) then
         Publish_VM.Execute (Pane.Options, Publish_VM.Close_Format);
         Widgets.Set_Visible (Pane.Format_Menu, False);
         Selects.Set_Open (Pane.Format, False);
      end if;
   end Close_Format_Menu;

   procedure Show_Format (Item : in out Session) is
      Pane : Publish_Parts renames Item.Publish_View;
   begin
      Selects.Set_Value (Pane.Format, (if Publish_VM.Markdown (Pane.Options) then "Markdown" else "Choose a format"));
      Pomarine.UI.Menus.Set_Content
        (Pane.Format_Menu,
         [Pomarine.UI.Menus.Row (Menus.Check, "Markdown", Checked => Publish_VM.Markdown (Pane.Options))]);
      Widgets.Set_Visible (Pane.Source_Scroll, Publish_VM.Markdown (Pane.Options));
      Widgets.Set_Visible (Pane.Split_Rule, Publish_VM.Markdown (Pane.Options));
   end Show_Format;

   procedure Synchronize (Item : in out Session) is
      Pane : Publish_Parts renames Item.Publish_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Show_Format (Item);
      if Pomarine.View_Models.Changed (Pane.Content_Seen, Publish_VM.Content_Version (Pane.Options)) then
         Refresh_Publish (Item);
      end if;
      Selects.Set_Open (Pane.Format, Publish_VM.Format_Open (Pane.Options));
      Widgets.Set_Visible (Pane.Format_Menu, Publish_VM.Format_Open (Pane.Options));
      if Publish_VM.Format_Open (Pane.Options) then
         Layouts.Set_Layout
           (Pane.Format_Menu,
            Position =>
              (Left => Float'Rounding (Widgets.Left_Of (Pane.Format) - Widgets.Left_Of (Pane.View)),
               Top => Float'Rounding
                 (Widgets.Top_Of (Pane.Format) + Widgets.Height_Of (Pane.Format) - Widgets.Top_Of (Pane.View)
                  + Style.Menu_Gap * Pixels), others => <>), Unit => Layouts.Device_Pixels);
         Layouts.Set_Layout (Pane.Format_Menu, Width => Widgets.Width_Of (Pane.Format) / Pixels);
         Widgets.Raise_To_Front (Pane.Format_Menu);
      end if;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Synchronize;

   procedure Menu_Pressed (Item : in out Session; X, Y : Float) is
      Pane   : Publish_Parts renames Item.Publish_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      --  The select's own click puts the menu away, if it is pressed.
      if Publish_VM.Format_Open (Pane.Options)
        and then not Widgets.Contains (Pane.Format_Menu, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (Pane.Format, X * Pixels, Y * Pixels)
      then
         Close_Format_Menu (Item);
      end if;
   end Menu_Pressed;

end View.Writing.Publishing;
