with Items.Windows;
with Viewer.Writing;
with Pomarine.Widgets;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Switches;

package body Viewer.Documents is

   function Grammar_Suggestions_Shown (Item : Session) return Boolean is
     (Pomarine.Widgets.Switches.Is_On (Item.Page_View.Grammar_Switch));

   function Grammar_Pending (Item : Session) return Boolean is
     (Item.Nav.Shown = Project and then Item.Toolbar.Mode = Write and then Item.Grammar_Checks.Enabled
      and then (for some Rank in 1 .. Item.Reading.Write_Count =>
                   not Item.Grammar_Checks.Documents (Rank).Finished));

   function Grammar_Running (Item : Session) return Natural is
      Total : Natural := 0;
   begin
      for Worker of Item.Grammar_Checks.Workers loop
         if Worker.Busy then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Grammar_Running;

   function Grammar_Count (Item : Session) return String is
     (Pomarine.Widgets.Buttons.Label (Item.Page_View.Grammar_Count));

   function Grammar_Highlights (Item : Session; Row : Positive) return Natural is
     (Pomarine.Widgets.Editors.Highlight_Count (Item.Docs.Pages (Row).Text));

   function Find_Sources_Enabled (Item : Session; Row : Positive) return Boolean is
     (Pomarine.Widgets.Editors.Assist_Is_Enabled (Item.Docs.Pages (Row).Text));

   procedure Find_Sources_Point
     (Item : Session; Row : Positive; Shown : out Boolean; X, Y : out Float)
   is
      Pixels : constant Float := Pomarine.Widgets.Density (Item.Root.Widgets);
   begin
      Pomarine.Widgets.Editors.Assist_Center (Item.Docs.Pages (Row).Text, Shown, X, Y);
      X := X / Pixels;
      Y := Y / Pixels;
   end Find_Sources_Point;

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

   function Sidebar_Width (Item : Session) return Float is (Item.Page_View.Sidebar_Wide);

   procedure Add_For_Section (Item : in out Session; Section : Positive) is
   begin
      Writing.Add_For_Section (Item, Section);
   end Add_For_Section;

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
