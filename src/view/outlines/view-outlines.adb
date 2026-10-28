with View.Writing;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;
with View.Outlines.Blocks;
with View.Outlines.Clicks;
with View.Outlines.Support;

package body View.Outlines is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Docs renames Texts.Documents;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Docs.Version;
   use type Projects.Id;
   use type Projects.Sections.Section_Id;

   function Section_Count (Item : Session) return Natural
   is (Outline_VM.Count (Item.Outline_Model.Model));

   function Section_Title (Item : Session; Which : Positive) return String
   is (Outline_VM.Title (Item.Outline_Model.Model, Which));

   function Section_At (Item : Session; Which : Positive) return Projects.Sections.Section
   is (Outline_VM.Section_At (Item.Outline_Model.Model, Which));

   function Index_Of_Key (Item : Session; Key : Projects.Sections.Section_Id) return Natural
   is (Outline_VM.Index_Of_Key (Item.Outline_Model.Model, Key));

   function Section_Of_Item (Item : Session; Key : Long_Integer) return Natural
   is (Outline_VM.Section_Of_Item (Item.Outline_Model.Model, Key));

   function Documents_In (Item : Session; Which : Positive) return Natural
   is (Outline_VM.Documents_In (Item.Outline_Model.Model, Which));

   procedure Sync (Item : in out Session) is
      Pane  : Outline_Parts renames Item.Outline_View;
      Model : Outline_VM.View_Model renames Item.Outline_Model.Model;
   begin
      if Open_Key (Item) = 0 or else not Outline_VM.Is_Entered (Model) then
         return;
      end if;
      if Docs.Current (Pane.Name_Doc) /= Pane.Name_Seen then
         Pane.Name_Seen := Docs.Current (Pane.Name_Doc);
         declare
            Kept : Boolean;
         begin
            --  A project is not left without a name; the toolbar shows what the view-model has.
            Outline_VM.Set_Project_Title (Model, Docs.Whole (Pane.Name_Doc), Kept);
            pragma Assert (Kept = (Outline_VM.Trimmed (Docs.Whole (Pane.Name_Doc)) /= ""));
         end;
      end if;
      if Docs.Current (Pane.Desc_Doc) /= Pane.Desc_Seen then
         Pane.Desc_Seen := Docs.Current (Pane.Desc_Doc);
         Outline_VM.Set_Project_Description (Model, Docs.Stored (Pane.Desc_Doc));
      end if;
      for Each in 1 .. Outline_VM.Count (Model) loop
         declare
            Block : Section_Block renames Pane.Blocks (Each);
         begin
            if Docs.Current (Block.Doc) /= Block.Seen then
               Block.Seen := Docs.Current (Block.Doc);
               Outline_VM.Set_Title (Model, Each, Docs.Whole (Block.Doc));
            end if;
            if Docs.Current (Block.Notes_Doc) /= Block.Notes_Seen then
               Block.Notes_Seen := Docs.Current (Block.Notes_Doc);
               Outline_VM.Set_Notes (Model, Each, Docs.Whole (Block.Notes_Doc), Docs.Stored (Block.Notes_Doc));
            end if;
         end;
      end loop;
   end Sync;

   procedure Load_Form (Item : in out Session);
   --  Show the project's title and description.

   procedure Load_Form (Item : in out Session) is
      Pane  : Outline_Parts renames Item.Outline_View;
      Model : Outline_VM.View_Model renames Item.Outline_Model.Model;
   begin
      Docs.Load (Pane.Name_Doc, Outline_VM.Project_Title (Model));
      Pane.Name_Seen := Docs.Current (Pane.Name_Doc);
      Docs.Load_Stored (Pane.Desc_Doc, Outline_VM.Project_Description (Model));
      Pane.Desc_Seen := Docs.Current (Pane.Desc_Doc);
   end Load_Form;

   procedure Reload (Item : in out Session) is
   begin
      if View_Mode (Item) = Outline then
         Sync (Item);
      end if;
      Outline_VM.Reload (Item.Outline_Model.Model);
      Support.Reserve (Item);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Reload;

   procedure Enter (Item : in out Session) is
      Pane : Outline_Parts renames Item.Outline_View;
   begin
      Pane.Drag_Block := 0;
      Pane.Drag_Moved := False;
      Pane.Drop_Before := 0;
      Load_Form (Item);
      Support.Reserve (Item);
      Blocks.Show_Blocks (Item);
      Blocks.Show_Drop_Line (Item);
   end Enter;

   procedure Leave (Item : in out Session) is
      Pane : Outline_Parts renames Item.Outline_View;
   begin
      Pane.Colour_Key := 0;
      Widgets.Set_Visible (Pane.Colour_Popout, False);
      Sync (Item);
      Pane.Drag_Block := 0;
      Pane.Drag_Moved := False;
      Pane.Drop_Before := 0;
      Blocks.Show_Drop_Line (Item);
      Blocks.Show_Ghost (Item);
   end Leave;

   procedure Shown (Item : in out Session) is
      Pane  : Outline_Parts renames Item.Outline_View;
      Model : Outline_VM.View_Model renames Item.Outline_Model.Model;
   begin
      Sync (Item);
      --  The project may have been renamed on the toolbar.
      Outline_VM.Reload_Project (Model);
      if Outline_VM.Project_Title (Model) /= Outline_VM.Trimmed (Docs.Whole (Pane.Name_Doc)) then
         Docs.Load (Pane.Name_Doc, Outline_VM.Project_Title (Model));
         Pane.Name_Seen := Docs.Current (Pane.Name_Doc);
      end if;
   end Shown;

   --  What is done to the sections: the view-model does it (its buttons are the view's, bound to it), and says
   --  so, around it (Outline_VM.Effects).

   procedure Going (Item : in out Session; What : Outline_VM.Command) is
      pragma Unreferenced (What);
   begin
      Sync (Item);
   end Going;

   procedure Show_Notes (Item : in out Session; Which : Positive; Focus : Boolean) is
      Pane     : Outline_Parts renames Item.Outline_View;
      Block    : Section_Block renames Pane.Blocks (Which);
      Now_Open : constant Boolean := Outline_VM.Is_Open (Item.Outline_Model.Model, Which);
   begin
      Buttons.Set_Selected (Block.Notes, Now_Open);
      Widgets.Set_Visible (Block.Notes_Sheet, Now_Open);
      Widgets.Request_Layout (Block.Row);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if Now_Open and then Focus then
         Widgets.Focus (Block.Notes_Text);
      end if;
   end Show_Notes;

   procedure Show_Added (Item : in out Session) is
      Pane  : Outline_Parts renames Item.Outline_View;
      Model : Outline_VM.View_Model renames Item.Outline_Model.Model;
   begin
      Support.Reserve (Item);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      declare
         Block  : Section_Block renames Pane.Blocks (Outline_VM.Count (Model));
         Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      begin
         Scrollers.Scroll_To
           (Pane.Scroll,
            Float'Max
              (0.0,
               (Widgets.Top_Of (Block.Row) + Widgets.Height_Of (Block.Row) - Widgets.Top_Of (Pane.Content))
               / Pixels
               - Widgets.Height_Of (Pane.Scroll) / Pixels));
         Widgets.Focus (Block.Field);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (Block.Field).all);
      end;
   end Show_Added;

   procedure Done (Item : in out Session; What : Outline_VM.Command; Index : Natural) is
      use all type Outline_VM.Command;
   begin
      case What is
         when Add_Section                          =>
            Show_Added (Item);

         when Move_Up | Move_Down | Remove_Section =>
            Blocks.Show_Blocks (Item);
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);

         when Toggle_Notes                         =>
            Show_Notes (Item, Index, Focus => View_Mode (Item) /= Write);
            if View_Mode (Item) = Write then
               Writing.Section_Notes_Changed (Item, Index);
            end if;

         when Choose_Colour                        =>
            Clicks.Colour_Clicked (Item, Index);

         when Accept_Colour                        =>
            Clicks.Colour_Accepted (Item);

         when Cancel_Colour                        =>
            Clicks.Colour_Cancelled (Item);

         when End_Title                            =>
            Clicks.Title_Submitted (Item);
      end case;
   end Done;

   procedure Add_Section (Item : in out Session) is
   begin
      Outline_VM.Execute (Item.Outline_Model.Model, Outline_VM.Add_Section);
   end Add_Section;

   procedure Move_Section (Item : in out Session; From, To : Positive) is
   begin
      if From = To then
         return;
      end if;
      Sync (Item);
      Outline_VM.Move (Item.Outline_Model.Model, From, To);
      Blocks.Show_Blocks (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Move_Section;

   procedure Remove_Section (Item : in out Session; Which : Positive) is
   begin
      Outline_VM.Execute (Item.Outline_Model.Model, Outline_VM.Remove_Section, Which);
   end Remove_Section;

   procedure Toggle_Notes (Item : in out Session; Which : Positive) is
   begin
      Outline_VM.Execute (Item.Outline_Model.Model, Outline_VM.Toggle_Notes, Which);
   end Toggle_Notes;

   function Section_Notes (Item : Session; Which : Positive) return String
   is (Outline_VM.Notes (Item.Outline_Model.Model, Which));

   function Notes_Shown (Item : Session; Which : Positive) return Boolean
   is (Outline_VM.Is_Open (Item.Outline_Model.Model, Which));

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pane   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Widgets.Is_Visible (Pane.Colour_Popout)
        and then not Widgets.Contains (Pane.Colour_Popout, X * Pixels, Y * Pixels)
      then
         Pane.Colour_Key := 0;
         Widgets.Set_Visible (Pane.Colour_Popout, False);
      end if;
   end Pressed;

   procedure Update (Item : in out Session) is
      Pane : Outline_Parts renames Item.Outline_View;
   begin
      if Pane.Colour_Key /= 0 and then not Support.In_Outline (Item) then
         Pane.Colour_Key := 0;
         Widgets.Set_Visible (Pane.Colour_Popout, False);
      end if;
   end Update;

   --  What the widgets say

   procedure Listen_Block (Item : in out Session; Index : Positive) is
      use all type Widgets.Event_Kind;
      Block : Section_Block renames Item.Outline_View.Blocks (Index);

      procedure Hear
        (Part : in out Widgets.Widget'Class; Kind : Widgets.Event_Kind; Do_This : Hooks.Handler; Tag : Natural := 0) is
      begin
         if Tag /= 0 then
            Widgets.Set_Tag (Part, Widgets.No_Tag, Tag);
         end if;
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      Hear (Block.Row, Drag, Blocks.Block_Dragged'Access, Index);
      Hear (Block.Row, Release, Blocks.Block_Released'Access);
   end Listen_Block;

   --  The least the description is sized to, in points.
   Least_Description : constant Float := 96.0;

   procedure Description_Sized
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pane : Outline_Parts renames Item.Outline_View;
   begin
      Pane.Desc_Height := Float'Max (Least_Description, Pane.Desc_Height + Event.Down);
      Layouts.Set_Layout (Pane.Desc_Sheet, Height => Layouts.Length_Of (Pane.Desc_Height));
      Widgets.Request_Layout (Pane.Desc_Sheet);
   end Description_Sized;

   procedure Listen_Description (Item : in out Session) is
   begin
      Hooks.On (Item.Outline_View.Desc_Grip, Widgets.Drag, Item'Unchecked_Access, Description_Sized'Access);
   end Listen_Description;

end View.Outlines;
