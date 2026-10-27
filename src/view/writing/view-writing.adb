with Naming_VM;
with Writing_Sources_VM;
with Publish_VM;
with Writing_VM;
with Items.Models;
with Items.Windows;
with Projects;
with Word_Tools;
with Items.Readers.Callbacks;
with Icon_Set;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Pictures;
with Pomarine.Widgets.Progress_Bars;
with Speech.Jobs;
with View.Canvas_Items;
with View.Outlines;
with View.Section_Links;
with View.Grammar;
with View.Navigation;
with View.Writing.Context;
with View.Writing.Layout;
with View.Writing.Moves;
with View.Writing.Order;
with View.Writing.Panes;
with View.Writing.Popups;
with View.Writing.Publishing;
with View.Writing.Reader_Windows;
with View.Writing.Rename;
with View.Writing.Row_Drags;
with View.Writing.Support;
with View.Writing.Tree;

package body View.Writing is
   procedure Synchronize_Publish (Item : in out Session) renames Publishing.Synchronize;

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Progress_Bars renames Pomarine.Widgets.Progress_Bars;
   package Readers renames Items.Readers;
   package Windows renames Items.Windows;
   package Models renames Items.Models;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);
   package Reader_Events is new Items.Readers.Callbacks (Session);

   use type Projects.Id;
   use type Pictures.Tools;
   use type Models.Dictations;

   Untitled_Directory : constant String := "Untitled folder";

   procedure Enter (Item : in out Session) is
   begin
      Order.Build_Order (Item);
      for Which in 1 .. Item.Windows.Count loop
         if Support.Is_Source (Item, Which) then
            Reader_Windows.Make_Reader (Item, Which);
         end if;
      end loop;
      Item.Dragging.Drag_Row := 0;
      Item.Docs.Drop := (others => <>);
      Naming_VM.End_Directory (Item.Naming.Names);
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Widgets.Set_Visible (Item.Docs.Drop_Line, False);
      Tree.Refresh (Item);
   end Enter;

   procedure Show_View (Item : in out Session; To : Modes) is
   begin
      Section_Links.Close (Item);
      Section_Links.Update (Item);
      Publishing.Close_Format_Menu (Item);
      Popups.Close_Menu (Item);
      Popups.Close_Context (Item);
      Widgets.Set_Visible (Item.Outline_View.View, To = Outline);
      Widgets.Set_Visible (Item.Canvas_View, To = Canvas);
      Widgets.Set_Visible (Item.Page_View.Write_View, To = Write);
      Buttons.Set_Selected (Tab_Of (Item, Item.Toolbar.Outline_Tab).all, To = Outline);
      Buttons.Set_Selected (Tab_Of (Item, Item.Toolbar.Canvas_Tab).all, To = Canvas);
      Buttons.Set_Selected (Tab_Of (Item, Item.Toolbar.Write_Tab).all, To = Write);
      Buttons.Set_Selected (Tab_Of (Item, Item.Toolbar.Publish_Tab).all, To = Publish);
      Widgets.Set_Visible (Item.Publish_View.View, To = Publish);
      Widgets.Set_Visible (Tray_Panel (Item).all, To = Canvas);
      Widgets.Set_Visible (Tab_Of (Item, Item.Dock.Tool_List).all, To = Canvas);
      Canvas_Items.Show_Dock (Item);
      if To in Write | Publish then
         Tree.Rebuild (Item);
         if To = Publish then
            Publishing.Refresh_Publish (Item);
         end if;
      elsif To = Outline and then Open_Key (Item) /= 0 then
         Outlines.Shown (Item);
      end if;
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if To = Canvas then
         Canvas_Items.Sync (Item);
      end if;
   end Show_View;

   procedure Show_View (Item : in out Session) is
   begin
      Show_View (Item, View_Mode (Item));
   end Show_View;

   procedure Fit_Sidebar (Item : in out Session) is
   begin
      Panes.Fit_Sections (Item);
   end Fit_Sidebar;

   procedure Dismiss_Context (Item : in out Session) is
   begin
      Popups.Close_Context (Item);
   end Dismiss_Context;

   procedure Leave (Item : in out Session) is
   begin
      Grammar.Reset (Item);
      Reader_Windows.Unpin (Item, Reopen => False);
      for Which in 1 .. Item.Windows.Count loop
         if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
            Readers.Release (Item.Reading.Readers (Which));
         end if;
      end loop;
      Writing_Sources_VM.Reset (Item.Reading.Sources);
      Item.Docs.Dirs.Count := 0;
      Trees.Reset (Item.Docs.Ordering);
      Writing_VM.Reset (Item.Docs.Navigation);
      Item.Dragging.Drag_Row := 0;
      Item.Docs.Drop := (others => <>);
      Naming_VM.End_Directory (Item.Naming.Names);
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Widgets.Set_Visible (Item.Docs.Drop_Line, False);
      Tree.Refresh (Item);
      Show_View (Item, Canvas);
   end Leave;

   procedure Added (Item : in out Session; Which : Items.Slot) is
      Directory : Natural := 0;
   begin
      if Support.Is_Note (Item, Which) then
         --  One written while a directory is shown is last in it; else
         --  last of all.
         Directory :=
           (if Item.Section_View.Pending in 1 .. Outlines.Section_Count (Item)
            then Support.Dir_Of_Section (Item, Item.Section_View.Pending)
            elsif View_Mode (Item) = Write then Writing_VM.Shown (Item.Docs.Navigation, Item.Docs.Dirs) else 0);
         Order.Insert_Row
           (Item, Order.Last_Of (Item, Directory), (Kind => Document_Leaf, Dir => Directory, Doc => Which));
         if Trees.Directory_Of (Item.Docs.Ordering, Which) /= 0 then
            Order.Keep_Directory (Item, Which);
         end if;
         Order.Keep_Order (Item);
         if Support.Section_Directory (Item, Trees.Directory_Of (Item.Docs.Ordering, Which)) /= 0 then
            --  Made in a section's folder, it is the section's, and called
            --  as it if it has no name of its own.
            Section_Links.Joined (Item, Which);
            Item.Section_Menu.Seen := Item.Section_Menu.Changes;
         end if;
         Tree.Refresh (Item);
         if View_Mode (Item) = Write then
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            Layout.Fit_Pages (Item);
            Tree.Go_To (Item, Support.Rank_Of (Item, Which));
            Widgets.Focus (Item.Docs.Pages (Support.Rank_Of (Item, Which)).Text);
         end if;
      else
         Writing_Sources_VM.Add (Item.Reading.Sources, Which);
         Reader_Windows.Make_Reader (Item, Which);
         Tree.Refresh (Item);
      end if;
   end Added;

   procedure Removed (Item : in out Session; Which : Items.Slot) is
   begin
      if Support.Is_Note (Item, Which) then
         declare
            Row : constant Natural := Support.Leaf_Row (Item, Which);
         begin
            if Row > 0 then
               Order.Delete_Row (Item, Row);
            end if;
         end;
      else
         if Item.Reading.Pinned_Slot = Which then
            Reader_Windows.Unpin (Item, Reopen => False);
         end if;
         if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
            Readers.Release (Item.Reading.Readers (Which));
         end if;
         Writing_Sources_VM.Remove (Item.Reading.Sources, Which);
      end if;
      Tree.Refresh (Item);
   end Removed;

   procedure Picture_Taken (Item : in out Session; Which : Items.Slot) is
      Details : constant Items.Info := Models.Details (Item.Models (Which));

      procedure Show (Shown : in out Readers.Reader; Sync : out Sync_State) is
      begin
         Readers.Set_Document
           (Shown, Items.Extensions.To_String (Details.Document), Details.Page, Details.Page_Count);
         Readers.Set_Picture
           (Shown, Reader_Windows.Picture_Of (Item, Which), Details.Captured_At);
         Sync := (Own  => Readers.Marks_Version (Shown),
                  Peer => Windows.Marks_Version (Item.Windows (Which)));
      end Show;
   begin
      if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
         Show (Item.Reading.Readers (Which), Item.Reading.Reader_Sync (Which));
      end if;
      if Item.Reading.Pinned_Slot = Which then
         Show (Item.Reading.Pane_Reader, Item.Reading.Pane_Sync);
      end if;
   end Picture_Taken;

   procedure Page_Turned (Item : in out Session; Which : Items.Slot) is
      Details : constant Items.Info := Models.Details (Item.Models (Which));
   begin
      if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
         Readers.Set_Document
           (Item.Reading.Readers (Which), Items.Extensions.To_String (Details.Document),
            Details.Page, Details.Page_Count);
         Readers.Go_To_Page (Item.Reading.Readers (Which), Details.Page);
      end if;
      if Item.Reading.Pinned_Slot = Which then
         Readers.Set_Document
           (Item.Reading.Pane_Reader, Items.Extensions.To_String (Details.Document),
            Details.Page, Details.Page_Count);
         Readers.Go_To_Page (Item.Reading.Pane_Reader, Details.Page);
      end if;
   end Page_Turned;

   procedure Words_Found
     (Item : in out Session; Which : Items.Slot; Found : Vision.Result) is
   begin
      if Readers.Is_Assigned (Item.Reading.Readers (Which)) then
         Readers.Set_Recognized (Item.Reading.Readers (Which), Found);
      end if;
      if Item.Reading.Pinned_Slot = Which then
         Readers.Set_Recognized (Item.Reading.Pane_Reader, Found);
      end if;
   end Words_Found;

   procedure Listen (Item : in out Session) is
      use all type Widgets.Event_Kind;

      procedure Hear
        (Part    : in out Widgets.Widget'Class;
         Kind    : Widgets.Event_Kind;
         Do_This : Hooks.Handler) is
      begin
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      Hear (Item.Page_View.Pane_Edge, Drag, Panes.Pane_Dragged'Access);
      Hear (Item.Page_View.Sidebar_Edge, Drag, Panes.Sidebar_Dragged'Access);
      Hear (Item.Page_View.Sidebar_Edge, Release, Panes.Sidebar_Released'Access);
      Hear (Item.Page_View.Sources_Edge, Drag, Panes.Sources_Edge_Dragged'Access);
      Reader_Events.On (Item.Reading.Pane_Reader, 0, Item'Unchecked_Access, Panes.Reader_Asked'Access);
   end Listen;

   procedure Listen_Row (Item : in out Session; Row : Positive) is
      use all type Widgets.Event_Kind;
      Box : Grips.Grip renames Item.Docs.Doc_Rows (Row).Row;
   begin
      Widgets.Set_Tag (Box, Widgets.No_Tag, Row);
      Hooks.On (Box, Drag, Item'Unchecked_Access, Row_Drags.Row_Dragged'Access);
      Hooks.On (Box, Release, Item'Unchecked_Access, Row_Drags.Row_Released'Access);
   end Listen_Row;

   procedure Listen_Slot (Item : in out Session; Rank : Items.Slot) is
   begin
      Reader_Events.On (Item.Reading.Readers (Rank), Rank, Item'Unchecked_Access, Panes.Reader_Asked'Access);
   end Listen_Slot;

   procedure Add_For_Section (Item : in out Session; Section : Positive) is
   begin
      if Section <= Outlines.Section_Count (Item) then
         --  Made last among the documents, whatever the section; Added
         --  makes it the section's.
         Item.Section_View.Pending := Section;
         Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
         Item.Section_View.Pending := 0;
      end if;
   end Add_For_Section;

   procedure Section_Notes_Changed (Item : in out Session; Section : Positive) is
   begin
      Layout.Fit_Pages (Item);
      if Outlines.Notes_Shown (Item, Section) then
         Widgets.Focus (Item.Section_View.Notes (Section).Text);
      end if;
   end Section_Notes_Changed;

   procedure Add_Folder (Item : in out Session) is
   begin
      Rename.New_Directory (Item, Untitled_Directory);
   end Add_Folder;

   procedure Source_Chosen
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Natural := Event.Row;
   begin
      if Item.Page_View.Menu_Page /= 0 and then Row /= 0 then
         if Row = Popups.Add_Row (Item) then
            --  On the canvas, where its address can be typed.
            declare
               Document : constant Items.Slot :=
                 Trees.Page_At (Item.Docs.Ordering, Item.Page_View.Menu_Page);
            begin
               Popups.Close_Menu (Item);
               Navigation.Show (Item, Canvas);
               Canvas_Items.Add_Linked_Source (Item, Document);
            end;
         elsif Row - Popups.Rows_Before in 1 .. Item.Page_View.Menu_Count then
            --  Ticked, it is pinned; ticked again, it is let go.
            declare
               Which : constant Items.Slot :=
                 Item.Page_View.Menu_Slots (Row - Popups.Rows_Before);
            begin
               if Item.Reading.Pinned_Slot = Which then
                  Reader_Windows.Unpin (Item, Reopen => False);
               else
                  Reader_Windows.Pin (Item, Which);
               end if;
            end;
            Popups.Close_Menu (Item);
            Tree.Refresh (Item);
         end if;
      end if;
   end Source_Chosen;

   procedure Context_Chosen
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Event.Row /= 0 and then Item.Context.Context_Kind /= No_Context then
         Context.Do_Context (Item, Event.Row);
      end if;
   end Context_Chosen;

   procedure Open_Sources (Item : in out Session; Rank : Positive) is
   begin
      Popups.Open_Menu (Item, Rank);
   end Open_Sources;

   procedure Tool_Used (Item : in out Session; Rank : Positive; Tool : Positive) is
   begin
      Word_Tools.Use_Tool (Item.Docs.Pages (Rank).Text, Tool);
   end Tool_Used;

   procedure Link_Followed (Item : in out Session; Rank : Positive) is
   begin
      Word_Tools.Follow (Item.Docs.Pages (Rank).Text);
   end Link_Followed;

   procedure Link_Asked (Item : in out Session; Rank : Positive) is
      Editor : Pomarine.Widgets.Editors.Editor renames Item.Docs.Pages (Rank).Text;

      procedure Offer (Name, Address : String) is
      begin
         Pomarine.Widgets.Editors.Add_Link_Choice (Editor, Name, Address);
      end Offer;
   begin
      Pomarine.Widgets.Editors.Clear_Link_Choices (Editor);
      Writing_Sources_VM.Offer_Links (Item.Reading.Sources, Offer'Access);
   end Link_Asked;

   procedure Begin_Page_Title (Item : in out Session; Rank : Positive) is
   begin
      Panes.Page_Title_Double_Clicked (Item, Rank);
   end Begin_Page_Title;

   procedure End_Page_Title (Item : in out Session; Rank : Positive) is
   begin
      Panes.Page_Title_Ended (Item, Rank);
   end End_Page_Title;

   procedure Select_Row (Item : in out Session; Row : Positive) is
   begin
      Panes.Row_Clicked (Item, Row);
   end Select_Row;

   procedure Rename_Row (Item : in out Session; Row : Positive) is
   begin
      Panes.Row_Double_Clicked (Item, Row);
   end Rename_Row;

   procedure End_Name_Edit (Item : in out Session) is
   begin
      Panes.Directory_Field_Ended (Item);
   end End_Name_Edit;

   procedure End_Source_Name_Edit (Item : in out Session) is
   begin
      Panes.Source_Field_Ended (Item);
   end End_Source_Name_Edit;

   procedure Apply_Source_Command (Item : in out Session; Slot : Items.Slot) is
   begin
      Reader_Windows.Toggle_Source (Item, Slot);
      Tree.Refresh (Item);
   end Apply_Source_Command;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);

      procedure Away (Shown : in out Readers.Reader) is
      begin
         if Readers.Is_Assigned (Shown)
           and then Readers.Tool (Shown) /= Pictures.Pointer
         then
            declare
               Box : constant Items.Frame := Readers.Box (Shown);
            begin
               if X * Pixels not in Box.Left .. Box.Left + Box.Width
                 or else Y * Pixels not in Box.Top .. Box.Top + Box.Height
               then
                  Readers.Select_Tool (Shown, Pictures.Pointer);
               end if;
            end;
         end if;
      end Away;
   begin
      Publishing.Menu_Pressed (Item, X, Y);
      if Item.Page_View.Menu_Page /= 0 then
         declare
            Menu : constant Items.Frame :=
              (Left   => Widgets.Left_Of (Item.Page_View.Menu),
               Top    => Widgets.Top_Of (Item.Page_View.Menu),
               Width  => Widgets.Width_Of (Item.Page_View.Menu),
               Height => Widgets.Height_Of (Item.Page_View.Menu));
         begin
            --  Its own button, pressed, is to put it away when clicked.
            if (X * Pixels not in Menu.Left .. Menu.Left + Menu.Width
                or else Y * Pixels not in Menu.Top .. Menu.Top + Menu.Height)
              and then not Widgets.Contains
                             (Item.Docs.Pages
                                (Item.Page_View.Menu_Page).Sources_Button,
                              X * Pixels, Y * Pixels)
            then
               Popups.Close_Menu (Item);
            end if;
         end;
      end if;
      if Item.Context.Context_Kind /= No_Context
        and then not Widgets.Contains
                       (Item.Context.Context_Menu, X * Pixels, Y * Pixels)
      then
         Popups.Close_Context (Item);
      end if;
      for Each of Item.Reading.Readers loop
         Away (Each);
      end loop;
      Away (Item.Reading.Pane_Reader);
   end Pressed;

   function Until_Copy_Ends (Item : Session) return Integer is (Publish_VM.Copy_Remaining (Item.Publish_View.Options));

   procedure Update (Item : in out Session) is
   begin
      if Support.In_Writing (Item) and then Section_Links.Changes (Item) /= Item.Section_Menu.Seen
        and then Item.Dragging.Drag_Row = 0
      then
         --  A document was made one of a section's, or let go, or a
         --  section renamed: where the documents are in the tree changes.
         Tree.Rebuild (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
      if Support.In_Writing (Item) then
         for Each of Item.Reading.Readers loop
            if Readers.Is_Assigned (Each) then
               Readers.Update (Each);
            end if;
         end loop;
         if Readers.Is_Assigned (Item.Reading.Pane_Reader) then
            Readers.Update (Item.Reading.Pane_Reader);
         end if;
      end if;
      for Which in 1 .. Item.Windows.Count loop
         if Support.Is_Note (Item, Which) then
            declare
               Rank : constant Natural := Support.Rank_Of (Item, Which);
            begin
               Windows.Set_Dictation_Editor
                 (Item.Windows (Which),
                  (if Rank > 0 and then Support.In_Writing (Item)
                   then Item.Docs.Pages (Rank).Text'Unrestricted_Access
                   else null));
               Models.Hold_Typing
                 (Item.Models (Which),
                  Rank > 0
                  and then Widgets.Has_Focus (Item.Docs.Pages (Rank).Text));
               if Rank > 0 then
                  declare
                     Busy : constant Boolean :=
                       Models.Dictation (Item.Models (Which))
                       in Models.Preparing | Models.Listening;
                     Mic  : Buttons.Button renames
                       Item.Docs.Pages (Rank).Mic_Button;
                  begin
                     if Busy /= (Buttons.Label (Mic) = "Stop") then
                        Buttons.Set_Label
                          (Mic, (if Busy then "Stop" else "Mic"));
                        Buttons.Set_Icon
                          (Mic,
                           (if Busy then Icon_Set.Stop
                            else Icon_Set.Microphone));
                     end if;
                  end;
                  declare
                     Hearing : constant Boolean :=
                       Models.Dictation (Item.Models (Which)) = Models.Listening;
                     Level   : Progress_Bars.Progress_Bar renames
                       Item.Docs.Pages (Rank).Level;
                     Loud    : constant Float :=
                       (if Hearing
                        then Float'Rounding (Speech.Jobs.Loudness (Which) * 20.0) / 20.0
                        else 0.0);
                  begin
                     if Widgets.Is_Visible (Level) /= Hearing then
                        Widgets.Set_Visible (Level, Hearing);
                     end if;
                     if Progress_Bars.Value (Level) /= Loud then
                        Progress_Bars.Set_Value (Level, Loud);
                     end if;
                  end;
                  declare
                     Words : constant Natural :=
                       Models.Words (Item.Models (Which));
                  begin
                     Labels.Set_Text
                       (Item.Docs.Pages (Rank).Words,
                        Support.Count_Image (Words)
                        & (if Words = 1 then " word" else " words"));
                  end;
                  Buttons.Set_Badge
                    (Item.Docs.Pages (Rank).Sources_Button,
                     Tree.Linked_Sources (Item, Which));
                  Labels.Set_Text
                    (Item.Docs.Pages (Rank).Heading,
                     Support.Title_Of (Item, Which));
                  declare
                     Row : constant Natural := Support.Leaf_Row (Item, Which);
                  begin
                     if Row > 0 then
                        Labels.Set_Text
                          (Item.Docs.Doc_Rows (Row).Count,
                           Support.Count_Image (Models.Words (Item.Models (Which))));
                        Labels.Set_Text
                          (Item.Docs.Doc_Rows (Row).Caption,
                           Support.Title_Of (Item, Which));
                        if Item.Dragging.Drag_Row = 0 then
                           Tree.Choose_Row
                             (Item.Docs.Doc_Rows (Row),
                              Widgets.Has_Focus (Item.Docs.Pages (Rank).Text));
                        end if;
                     end if;
                  end;
               end if;
            end;
         elsif Support.Is_Source (Item, Which)
           and then Readers.Is_Assigned (Item.Reading.Readers (Which))
         then
            Reader_Windows.Keep_Title (Item, Which, Item.Reading.Readers (Which));
            Readers.Set_Tag
              (Item.Reading.Readers (Which), Canvas_Items.Source_Ink (Item,
                 Which));
            Readers.Follow_Page (Item.Reading.Readers (Which));
            Reader_Windows.Keep_Marks
              (Item, Which, Item.Reading.Readers (Which),
               Item.Reading.Reader_Sync (Which));
            declare
               Row : constant Natural := Support.Row_Of (Item, Which);
            begin
               if Row > 0 then
                  Widgets.Set_Accessible_Name
                    (Item.Reading.Source_Rows (Row).Row, "Source " & Support.Title_Of (Item, Which));
                  Labels.Set_Text
                    (Item.Reading.Source_Rows (Row).Caption,
                     Support.Title_Of (Item, Which));
               end if;
            end;
         end if;
      end loop;
      if Item.Reading.Pinned_Slot /= 0 then
         Reader_Windows.Keep_Title (Item, Item.Reading.Pinned_Slot, Item.Reading.Pane_Reader);
         Readers.Set_Tag
           (Item.Reading.Pane_Reader,
            Canvas_Items.Source_Ink (Item, Item.Reading.Pinned_Slot));
         Readers.Follow_Page (Item.Reading.Pane_Reader);
         Reader_Windows.Keep_Marks
           (Item, Item.Reading.Pinned_Slot, Item.Reading.Pane_Reader,
            Item.Reading.Pane_Sync);
      end if;
   end Update;

   procedure Move (Item : in out Session; From, To : Positive) renames Moves.Move_Page;

   procedure Move_To_Directory
     (Item : in out Session; Rank : Positive; Directory : Natural) renames Moves.Move_Page_To_Directory;

   procedure Open_Context
     (Item : in out Session; X, Y : Float; Opened : out Boolean) renames Context.Open_At;

   procedure Delete_Node
     (Item : in out Session; Node : Tree_Entry; Delete_Documents : Boolean := False) renames Context.Delete_Tree_Node;

   procedure Make_Directory (Item : in out Session; Name : String) renames Rename.New_Directory;

   procedure Select_Directory (Item : in out Session; Directory : Natural) renames Tree.Show_Directory;

   procedure Fit (Item : in out Session) renames Layout.Fit_Pages;

end View.Writing;
