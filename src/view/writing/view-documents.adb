with Confirm_VM;
with Pomarine.UI;
with Writing_VM;
with View.Deletion;
with View.Grammar;
with View.Writing;
with Pomarine.Widgets;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Switches;

package body View.Documents is

   function Search_Count (Item : Session) return Natural
   is (Search_VM.Found (Item.Searching.Model).Total);
   function Search_Current (Item : Session) return Natural
   is (Search_VM.Found (Item.Searching.Model).Current);
   function Search_Document (Item : Session) return Natural
   is (Item.Searching.Rank);
   function Search_Highlights (Item : Session; Row : Positive) return Natural
   is (Pomarine.Widgets.Editors.Search_Count (Item.Docs.Pages (Row).Text));

   function Grammar_Suggestions_Shown (Item : Session) return Boolean
   is (Pomarine.Widgets.Switches.Is_On (Item.Page_View.Grammar_Switch));

   function Grammar_Pending (Item : Session) return Boolean
   is (Screen (Item) = Project
       and then View_Mode (Item) = Write
       and then Item.Grammar_Checks.Enabled
       and then (for some Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) =>
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

   function Grammar_Count (Item : Session) return String
   is (Pomarine.Widgets.Buttons.Label (Item.Page_View.Grammar_Count));

   function Grammar_Marking (Item : Session; Marked : String) return Natural
   is (Grammar.Marking (Item, Marked));
   function Grammar_Made_By_Rule (Item : Session; Marked : String) return Natural
   is (Grammar.Made_By_Rule (Item, Marked));
   function Grammar_First_Suggestion (Item : Session; Marked : String) return String
   is (Grammar.First_Suggestion (Item, Marked));
   procedure Grammar_Expand (Item : in out Session; Marked : String) is
   begin
      Grammar.Expand (Item, Marked);
   end Grammar_Expand;

   procedure Grammar_Begin_Rule (Item : in out Session; Marked : String) is
   begin
      Grammar.Begin_Rule (Item, Marked);
   end Grammar_Begin_Rule;

   procedure Grammar_Show (Item : in out Session) is
   begin
      Grammar.Show (Item);
   end Grammar_Show;

   function Grammar_First_Card_Made_By_Rule (Item : Session) return Boolean
   is (Grammar.First_Card_Made_By_Rule (Item));

   function Grammar_Rule_Count (Item : Session) return Natural
   is (Grammar.Rule_Count (Item));

   procedure Grammar_Ignore (Item : in out Session; Marked : String) is
   begin
      Grammar.Ignore (Item, Marked);
   end Grammar_Ignore;

   procedure Grammar_Correct (Item : in out Session; Marked, To : String) is
   begin
      Grammar.Correct (Item, Marked, To);
   end Grammar_Correct;

   procedure Grammar_Remove_Rule (Item : in out Session; Marked : String) is
   begin
      Grammar.Remove_Rule (Item, Marked);
   end Grammar_Remove_Rule;

   function Grammar_Highlights (Item : Session; Row : Positive) return Natural
   is (Pomarine.Widgets.Editors.Highlight_Count (Item.Docs.Pages (Row).Text));

   procedure Ask_Delete_Directory (Item : in out Session; Dir : Positive) is
   begin
      Deletion.Confirm_Node (Item, (Kind => Directory_Node, Dir => Dir, Doc => 0));
   end Ask_Delete_Directory;

   function Delete_Documents_Checked (Item : Session) return Boolean
   is (Confirm_VM.Delete_Documents (Item.Dialog_Model.Model));

   procedure Deletion_Points (Item : Session; Check_X, Check_Y, Delete_X, Delete_Y : out Float) is
      package Widgets renames Pomarine.Widgets;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Form   : Pomarine.UI.View renames Screen_Of (Item, Confirm_Region).all;
      Check  : Widgets.Widget'Class renames Pomarine.UI.Named (Form, Delete_Documents_Check).all;
      Delete : Widgets.Widget'Class renames Pomarine.UI.Named (Form, Confirm_Delete_Button).all;
   begin
      Check_X := (Widgets.Left_Of (Check) + 10.0 * Pixels) / Pixels;
      Check_Y := (Widgets.Top_Of (Check) + Widgets.Height_Of (Check) / 2.0) / Pixels;
      Delete_X := (Widgets.Left_Of (Delete) + Widgets.Width_Of (Delete) / 2.0) / Pixels;
      Delete_Y := (Widgets.Top_Of (Delete) + Widgets.Height_Of (Delete) / 2.0) / Pixels;
   end Deletion_Points;

   function Directory_Row (Item : Session; Dir : Positive) return Natural is
   begin
      for Row in 1 .. Trees.Count (Item.Docs.Ordering) loop
         if Trees.Element (Item.Docs.Ordering, Row).Kind = Directory_Node
           and then Trees.Element (Item.Docs.Ordering, Row).Dir = Dir
         then
            return Row;
         end if;
      end loop;
      return 0;
   end Directory_Row;

   function Context_Open (Item : Session) return Boolean
   is (Item.Context.Context_Kind /= No_Context);

   function Document_Count (Item : Session) return Natural
   is (Trees.Page_Count (Item.Docs.Ordering));

   function Document_Title (Item : Session; Row : Positive) return String
   is (Projects.Titles.To_String (Items.Models.Details (Item.Models (Trees.Page_At (Item.Docs.Ordering, Row))).Title));

   procedure Move_Document (Item : in out Session; From, To : Positive) is
   begin
      Writing.Move (Item, From, To);
   end Move_Document;

   function Sidebar_Width (Item : Session) return Float
   is (Item.Page_View.Sidebar_Wide);

   procedure Add_For_Section (Item : in out Session; Section : Positive) is
   begin
      Writing.Add_For_Section (Item, Section);
   end Add_For_Section;

   function Directory_Count (Item : Session) return Natural
   is (Item.Docs.Dirs.Count);

   function Directory_Parent (Item : Session; Row : Positive) return Natural is
      use type Items.Id;
   begin
      for Each in 1 .. Item.Docs.Dirs.Count loop
         if Item.Docs.Dirs (Each).Key = Item.Docs.Dirs (Row).Parent then
            return Each;
         end if;
      end loop;
      return 0;
   end Directory_Parent;

   function Directory_Title (Item : Session; Row : Positive) return String
   is (Projects.Titles.To_String (Item.Docs.Dirs (Row).Title));

   procedure Add_Directory (Item : in out Session; Name : String := "Untitled folder") is
   begin
      Writing.Make_Directory (Item, Name);
   end Add_Directory;

   function Document_Directory (Item : Session; Row : Positive) return Natural
   is (Trees.Directory_Of (Item.Docs.Ordering, Trees.Page_At (Item.Docs.Ordering, Row)));

   procedure Move_Document_To (Item : in out Session; Row : Positive; Directory : Natural) is
   begin
      Writing.Move_To_Directory (Item, Row, Directory);
   end Move_Document_To;

   function Shown_Directory (Item : Session) return Natural
   is (Writing_VM.Shown (Item.Docs.Navigation, Item.Docs.Dirs));

   procedure Show_Directory (Item : in out Session; Directory : Natural) is
   begin
      Writing.Select_Directory (Item, Directory);
   end Show_Directory;

end View.Documents;
