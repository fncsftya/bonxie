with Viewer.Gestures;

package body Viewer.Outlines.Support is

   use type Projects.Sections.Section_Id;

   function In_Outline (Item : Session) return Boolean is
     (Gestures.Active (Item) and then Item.Toolbar.Mode = Outline);

   function Cut (Content : String; Most : Positive) return String is
      Last : Natural := Content'First - 1 + Natural'Min (Content'Length, Most);
   begin
      if Last < Content'Last then
         --  The next byte goes on a character that began in the part kept.
         while Last >= Content'First
           and then Character'Pos (Content (Last + 1)) in 16#80# .. 16#BF#
         loop
            Last := Last - 1;
         end loop;
      end if;
      return Content (Content'First .. Last);
   end Cut;

   function Trimmed (Content : String) return String is
      First : Positive := Content'First;
      Last  : Natural := Content'Last;
   begin
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      return Content (First .. Last);
   end Trimmed;

   procedure Load_Sections (Item : in out Session; Owner : Projects.Id) is
      View : Outline_Parts renames Item.Outline_View;
      Was  : constant Projects.Sections.Section_List := View.Order;
   begin
      Projects.Sections.Load (Item.Nav.Store, Owner, View.Order);
      Projects.Sections.Load_Links (Item.Nav.Store, Owner, View.Links);
      for Each in 1 .. View.Order.Count loop
         declare
            Section : Projects.Sections.Section renames View.Order.Items (Each);
         begin
            Section.Open := Projects.Sections.Note_Texts.Length (Section.Notes) > 0;
            for Before in 1 .. Was.Count loop
               if Was.Items (Before).Key = Section.Key then
                  Section.Open := Was.Items (Before).Open or else Section.Open;
               end if;
            end loop;
         end;
      end loop;
   end Load_Sections;

end Viewer.Outlines.Support;
