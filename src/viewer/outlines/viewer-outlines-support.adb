with Outline_VM;
with Viewer.Build;
with Viewer.Gestures;

package body Viewer.Outlines.Support is

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

   procedure Reserve (Item : in out Session) is
   begin
      Build.Reserve_Sections (Item, Outline_VM.Count (Item.Outline_Model.Model));
   end Reserve;

end Viewer.Outlines.Support;
