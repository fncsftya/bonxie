with Projects.Sections;
with Texts.Documents;
with Pomarine.Widgets.Switches;
with Viewer.Outlines;
with Viewer.Section_Links;
with Viewer.Writing.Support;

package body Viewer.Writing.Publishing is

   package Windows renames Items.Windows;
   package Docs renames Texts.Documents;

   procedure Refresh_Publish (Item : in out Session) is
      View : Publish_Parts renames Item.Publish_View;
      Started : Boolean := False;
      Previous_Section : Natural := 0;

      procedure Append (Words : String; Kind : Texts.Paragraph_Kind := Texts.Plain) is
         First : Positive := Words'First;
         Last : Natural := Words'Last;
         Para : Positive;
      begin
         while First <= Last and then Words (First) in ASCII.LF | ASCII.CR loop
            First := First + 1;
         end loop;
         while Last >= First and then Words (Last) in ASCII.LF | ASCII.CR loop
            Last := Last - 1;
         end loop;
         if First > Last then
            return;
         end if;
         Para := Docs.Count (View.Doc) + (if Started then 1 else 0);
         Docs.Replace
           (View.Doc, Docs.Text_End (View.Doc), Docs.Text_End (View.Doc),
            (if Started then ASCII.LF & Words (First .. Last) else Words (First .. Last)),
            Recorded => False, Explicit_Formats => True);
         Docs.Set_Kind (View.Doc, Para, Kind);
         if Kind in Texts.Heading_2 | Texts.Heading_3 then
            Docs.Set_Format (View.Doc, (Para, 1), Docs.Paragraph_End (View.Doc, Para), Docs.Bold, True);
         end if;
         Started := True;
      end Append;
   begin
      Docs.Load (View.Doc, "");
      for Rank in 1 .. Item.Reading.Write_Count loop
         declare
            Which : constant Items.Slot := Item.Reading.Write_Order (Rank);
            Section : constant Natural := Section_Links.Section_Of (Item, Which);
         begin
            if Pomarine.Widgets.Switches.Is_On (View.Section_Headings)
              and then Section /= 0 and then Section /= Previous_Section
            then
               Append
                 (Projects.Sections.Title_Texts.To_String (Outlines.Section_At (Item, Section).Title),
                  Texts.Heading_2);
            end if;
            Previous_Section := Section;
            if Pomarine.Widgets.Switches.Is_On (View.Document_Headings) then
               Append (Support.Title_Of (Item, Which), Texts.Heading_3);
            end if;
            Append (Docs.Whole (Windows.Content_Document (Item.Windows (Which)).all));
         end;
      end loop;
      Widgets.Invalidate (View.Text);
   end Refresh_Publish;

   procedure Publish_Options_Changed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Refresh_Publish (Item);
   end Publish_Options_Changed;

end Viewer.Writing.Publishing;
