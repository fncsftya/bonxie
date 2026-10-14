with Items.Windows;
with Viewer.Writing;

package body Viewer.Documents is

   function Document_Count (Item : Session) return Natural is
     (Item.Reading.Write_Count);

   function Document_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Windows.Details
           (Item.Windows (Item.Reading.Write_Order (Row))).Title));

   procedure Move_Document (Item : in out Session; From, To : Positive) is
   begin
      Writing.Move (Item, From, To);
   end Move_Document;

   function Directory_Count (Item : Session) return Natural is
     (Item.Docs.Dirs.Count);

   function Directory_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String (Item.Docs.Dirs.Directories (Row).Title));

   procedure Add_Directory
     (Item : in out Session; Name : String := "Untitled folder") is
   begin
      Writing.Make_Directory (Item, Name);
   end Add_Directory;

   function Document_Directory
     (Item : Session; Row : Positive) return Natural is
     (Item.Docs.Doc_Dir (Item.Reading.Write_Order (Row)));

   procedure Move_Document_To
     (Item : in out Session; Row : Positive; Directory : Natural) is
   begin
      Writing.Move_To_Directory (Item, Row, Directory);
   end Move_Document_To;

   function Shown_Directory (Item : Session) return Natural is
     (Item.Docs.Shown_Dir);

   procedure Show_Directory (Item : in out Session; Directory : Natural) is
   begin
      Writing.Select_Directory (Item, Directory);
   end Show_Directory;

end Viewer.Documents;
