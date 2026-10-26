with Items.Models;
with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Markdown_Export;
with Projects.Sections;
with SDL3.Dialogs;
with Pomarine.Events;
with Pomarine.UI.Menus;
with SDL3.Windows;
with Texts.Documents;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Switches;
with View.Outlines;
with View.Section_Links;
with View.Style;
with View.Writing.Support;

package body View.Writing.Publishing is

   package Models renames Items.Models;
   package Docs renames Texts.Documents;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Menus renames Pomarine.Widgets.Menus;
   package Selects renames Pomarine.Widgets.Selects;

   use type SDL3.Dialogs.States;
   use type Pomarine.Events.Milliseconds;
   use type Widgets.Clipboard_Access;

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
            if Pomarine.Widgets.Switches.Is_On (Pane.Section_Headings)
              and then Section /= 0 and then Section /= Previous_Section
            then
               Heading (Projects.Sections.Title_Texts.To_String (Outlines.Section_At (Item, Section).Title), 2);
            end if;
            Previous_Section := Section;
            if Pomarine.Widgets.Switches.Is_On (Pane.Document_Headings) then
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
      if Pane.Format_Open then
         Pane.Format_Open := False;
         Widgets.Set_Visible (Pane.Format_Menu, False);
         Selects.Set_Open (Pane.Format, False);
      end if;
   end Close_Format_Menu;

   procedure Show_Format (Item : in out Session) is
      Pane : Publish_Parts renames Item.Publish_View;
   begin
      Selects.Set_Value (Pane.Format, (if Pane.Markdown then "Markdown" else "Choose a format"));
      Pomarine.UI.Menus.Set_Content
        (Pane.Format_Menu, [Pomarine.UI.Menus.Row (Menus.Check, "Markdown", Checked => Pane.Markdown)]);
      Buttons.Set_Enabled (Pane.Export, Pane.Markdown);
      Buttons.Set_Enabled (Pane.Copy, Pane.Markdown);
      Widgets.Set_Visible (Pane.Source_Scroll, Pane.Markdown);
      Widgets.Set_Visible (Pane.Split_Rule, Pane.Markdown);
   end Show_Format;

   procedure Format_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Pane   : Publish_Parts renames Item.Publish_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Pane.Format_Open then
         Close_Format_Menu (Item);
      else
         Pane.Format_Open := True;
         Selects.Set_Open (Pane.Format, True);
         Pomarine.UI.Menus.Set_Content
           (Pane.Format_Menu, [Pomarine.UI.Menus.Row (Menus.Check, "Markdown", Checked => Pane.Markdown)]);
         Layouts.Set_Layout
           (Pane.Format_Menu,
            Position =>
              (Left => Float'Rounding (Widgets.Left_Of (Pane.Format) - Widgets.Left_Of (Pane.View)),
               Top  => Float'Rounding
                 (Widgets.Top_Of (Pane.Format) + Widgets.Height_Of (Pane.Format) - Widgets.Top_Of (Pane.View)
                  + Style.Menu_Gap * Pixels),
               others => <>),
            Unit => Layouts.Device_Pixels);
         Layouts.Set_Layout (Pane.Format_Menu, Width => Widgets.Width_Of (Pane.Format) / Pixels);
         Widgets.Set_Visible (Pane.Format_Menu, True);
         Widgets.Raise_To_Front (Pane.Format_Menu);
      end if;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Format_Clicked;

   procedure Format_Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pane : Publish_Parts renames Item.Publish_View;
   begin
      if Event.Row = 1 then
         Pane.Markdown := True;
         Close_Format_Menu (Item);
         Show_Format (Item);
         Refresh_Publish (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Format_Chosen;

   procedure Menu_Pressed (Item : in out Session; X, Y : Float) is
      Pane   : Publish_Parts renames Item.Publish_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      --  The select's own click puts the menu away, if it is pressed.
      if Pane.Format_Open
        and then not Widgets.Contains (Pane.Format_Menu, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (Pane.Format, X * Pixels, Y * Pixels)
      then
         Close_Format_Menu (Item);
      end if;
   end Menu_Pressed;

   procedure Export_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Publish_View.Markdown and then not Item.Nav.Export_Waiting
        and then SDL3.Dialogs.State /= SDL3.Dialogs.Waiting
        and then SDL3.Windows.Is_Open (Item.Host.Win)
      then
         SDL3.Dialogs.Reset;
         Item.Nav.Export_Waiting := True;
         SDL3.Dialogs.Save_File (Item.Host.Win, "Markdown", "md", "Export.md");
      end if;
   end Export_Clicked;

   procedure Save (Item : Session; Path : String) is
      Named : constant String :=
        (if (for some I in reverse Path'Range => Path (I) = '.' and then
               (for all J in I .. Path'Last => Path (J) /= '/'))
         then Path else Path & ".md");
      Words : constant String := Docs.Whole (Item.Publish_View.Source_Doc);
      File  : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Named);
      String'Write (Ada.Streams.Stream_IO.Stream (File), Words);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
   end Save;

   Copied_For : constant Pomarine.Events.Milliseconds := 2_500;

   procedure Copy_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Pane  : Publish_Parts renames Item.Publish_View;
      Words : constant String := Docs.Whole (Pane.Source_Doc);
      Board : constant Widgets.Clipboard_Access := Widgets.Clipboard (Pane.Copy);
   begin
      if Pane.Markdown and then Board /= null then
         Board.Set_Text (Words);
         if Board.Text = Words then
            Pane.Copied_Until := Pomarine.Events.Ticks + Copied_For;
            Buttons.Set_Label (Pane.Copy, "Copied");
         end if;
      end if;
   end Copy_Clicked;

   function Copy_Remaining (Item : Session) return Integer is
     (if Item.Publish_View.Copied_Until = 0 then -1
      else Integer (Long_Long_Integer'Max (0, Long_Long_Integer (Item.Publish_View.Copied_Until)
                                              - Long_Long_Integer (Pomarine.Events.Ticks))));

   procedure Poll_Export (Item : in out Session) is
   begin
      if Item.Publish_View.Copied_Until /= 0 and then Pomarine.Events.Ticks >= Item.Publish_View.Copied_Until then
         Item.Publish_View.Copied_Until := 0;
         Buttons.Set_Label (Item.Publish_View.Copy, "Copy to Clipboard");
      end if;
      if not Item.Nav.Export_Waiting then
         return;
      end if;
      case SDL3.Dialogs.State is
         when SDL3.Dialogs.Waiting =>
            null;
         when SDL3.Dialogs.Idle | SDL3.Dialogs.Cancelled | SDL3.Dialogs.Failed =>
            SDL3.Dialogs.Reset;
            Item.Nav.Export_Waiting := False;
         when SDL3.Dialogs.Chosen =>
            declare
               Path : constant String := SDL3.Dialogs.Path;
            begin
               SDL3.Dialogs.Reset;
               Item.Nav.Export_Waiting := False;
               Save (Item, Path);
            end;
      end case;
   end Poll_Export;

   procedure Publish_Options_Changed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Refresh_Publish (Item);
   end Publish_Options_Changed;

end View.Writing.Publishing;
