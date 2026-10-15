with Ebook;

package body Items.Vector_Pages is

   use type Pomarine.Pages.Page_Access;

   overriding procedure Build
     (Item    : in out File_Source;
      Index   : Positive;
      Content : out Pomarine.Pages.Page_Access;
      Found   : in out Pomarine.Words.Result;
      Ok      : out Boolean)
   is
      Message : String (1 .. Ebook.Max_Message);
      Last    : Natural;
   begin
      Ebook.Build_Page (Item.Name (1 .. Item.Length), Index, Content, Found, Message, Last);
      Ok := Content /= null;
   end Build;

   procedure Open
     (Shown   : in out Pomarine.Widgets.Page_Views.Page_View;
      Sizes   : in out Pomarine.Pages.Size_Array_Access;
      Origin  : aliased in out File_Source;
      File    : String;
      Count   : Positive;
      Message : out String;
      Last    : out Natural) is
   begin
      Close (Shown, Sizes);
      Last := Message'First - 1;
      if File'Length > Path_Capacity then
         Message (Message'First .. Message'First + 15) := "the path is long";
         Last := Message'First + 15;
         return;
      end if;
      Origin.Length := File'Length;
      Origin.Name (1 .. File'Length) := File;
      Ebook.Document_Sizes (File, Count, Sizes, Message, Last);
      if Sizes /= null then
         Pomarine.Widgets.Page_Views.Set_Document (Shown, Sizes, Origin'Unchecked_Access);
      end if;
   end Open;

   procedure Close
     (Shown : in out Pomarine.Widgets.Page_Views.Page_View;
      Sizes : in out Pomarine.Pages.Size_Array_Access) is
   begin
      Pomarine.Widgets.Page_Views.Clear_Document (Shown);
      Pomarine.Pages.Free (Sizes);
   end Close;

end Items.Vector_Pages;
