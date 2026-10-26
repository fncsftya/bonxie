with Writing_Sources_VM;
with Pomarine.UI.Menus;
with Writing_VM;
with Items.Directories;
with Items.Readers;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Menus;
with View.Canvas_Items;
with View.Deletion;
with View.Style;
with View.Outlines;
with Pomarine.Widgets.Layouts;
with View.Writing.Order;
with View.Writing.Popups;
with View.Writing.Rename;
with View.Writing.Support;
with View.Writing.Tree;

package body View.Writing.Context is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Editors renames Pomarine.Widgets.Editors;
   package Rows renames Pomarine.UI.Menus;
   package Menus renames Pomarine.Widgets.Menus;
   package Readers renames Items.Readers;
   package Windows renames Items.Windows;

   use type Widgets.Clipboard_Access;
   use type Items.States;

   procedure Show_Context
     (Item : in out Session; Content : Rows.Content; Kind : Context_Kinds; X, Y : Float);
   --  Show the menu, its rows added, at X, Y, in points of the window, as
   --  far in as keeps it in the view.

   procedure Show_Context
     (Item : in out Session; Content : Rows.Content; Kind : Context_Kinds; X, Y : Float)
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Rows.Set_Content (Item.Context.Context_Menu, Content);
      Item.Context.Context_Kind := Kind;
      Layouts.Set_Layout
        (Item.Context.Context_Menu,
         Position =>
           (Left =>
              Float'Rounding
                (Float'Max
                   (0.0,
                    Float'Min
                      (X - Widgets.Left_Of (Content_Panel (Item).all) / Pixels,
                       Widgets.Width_Of (Content_Panel (Item).all) / Pixels
                       - Style.Context_Width)) * Pixels),
            Top =>
              Float'Rounding
                (Float'Max
                   (0.0,
                    Float'Min
                      (Y - Widgets.Top_Of (Content_Panel (Item).all) / Pixels,
                       Widgets.Height_Of (Content_Panel (Item).all) / Pixels
                       - Menus.Height_For (Item.Context.Context_Menu))) * Pixels),
            others => <>),
         Unit => Layouts.Device_Pixels);
      Widgets.Set_Visible (Item.Context.Context_Menu, True);
      Widgets.Raise_To_Front (Item.Context.Context_Menu);
      Widgets.Request_Layout (Item.Context.Context_Menu);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Context;

   procedure Add_Act
     (Item    : in out Session;
      Content : in out Rows.Content;
      Act     : Context_Acts;
      Name    : String;
      Icon    : Pomarine.Icons.Icon;
      Enabled : Boolean := True;
      Shade   : Menus.Tone := Menus.Plain);
   --  Add a row to the menu that does Act; if it cannot be now, it is a
   --  faint note, which is not clicked.

   procedure Add_Act
     (Item    : in out Session;
      Content : in out Rows.Content;
      Act     : Context_Acts;
      Name    : String;
      Icon    : Pomarine.Icons.Icon;
      Enabled : Boolean := True;
      Shade   : Menus.Tone := Menus.Plain) is
   begin
      Content.Append
        (Rows.Row ((if Enabled then Menus.Action else Menus.Note), Name, Shade,
                   Icon => (if Act = Select_All_Act then Pomarine.Icons.No_Icon else Pomarine.Icons.Shown (Icon))));
      Item.Context.Context_Acts (Rows.Count (Content)) := (if Enabled then Act else No_Act);
   end Add_Act;

   function Board_Has_Text (Item : Session) return Boolean is
     (Widgets.Clipboard (Content_Panel (Item).all) /= null
      and then Widgets.Clipboard (Content_Panel (Item).all).Text /= "");
   --  Whether there is something to paste.

   procedure Open_At
     (Item : in out Session; X, Y : Float; Opened : out Boolean)
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      PX     : constant Float := X * Pixels;
      PY     : constant Float := Y * Pixels;
      Content : Rows.Content;

      procedure Begin_Menu is
      begin
         Content.Clear;
         Item.Context.Context_Acts := [others => No_Act];
         Item.Context.Context_Canvas := 0;
      end Begin_Menu;

      procedure Of_Row (Node : Tree_Entry) is
      begin
         Begin_Menu;
         Item.Context.Context_Node := Node;
         if Node.Kind /= Document_Leaf then
            Add_Act (Item, Content, Add_Document_Act, "Add Document", Icon_Set.Document);
            Add_Act (Item, Content, Add_Folder_Act, "Add Folder", Icon_Set.Folder);
            if Node.Kind /= Overview_Node then
               Content.Append (Rows.Row (Menus.Separator));
            end if;
         end if;
         if Node.Kind /= Overview_Node then
            Add_Act (Item, Content, Rename_Act, "Rename", Icon_Set.Edit);
         end if;
         --  A section is made and removed in the outline, not here.
         if Node.Kind /= Overview_Node
           and then not (Node.Kind = Directory_Node and then Support.Is_Section (Item, Node.Dir))
         then
            Add_Act (Item, Content, Delete_Act, "Delete", Icon_Set.Delete,
                     Shade => Menus.Danger);
         end if;
         Show_Context (Item, Content, Tree_Context, X, Y);
         Opened := True;
      end Of_Row;

      procedure Picture_Menu (Over, Words : Boolean) is
      begin
         if Over then
            Add_Act (Item, Content, Copy_Act, "Copy", Icon_Set.Document);
         end if;
         Add_Act (Item, Content, Select_All_Act, "Select all", Pomarine.Icons.Check,
                  Enabled => Words);
         Show_Context (Item, Content, Picture_Context, X, Y);
         Opened := True;
      end Picture_Menu;

      procedure Text_Menu (Over : Boolean) is
         Paste : constant Boolean := Board_Has_Text (Item);
      begin
         if Over then
            Add_Act (Item, Content, Copy_Act, "Copy", Icon_Set.Document);
            Add_Act (Item, Content, Cut_Act, "Cut", Icon_Set.Eraser);
            Add_Act (Item, Content, Paste_Act, "Paste", Icon_Set.Plus, Paste);
            Add_Act (Item, Content, Select_All_Act, "Select all", Pomarine.Icons.Check);
         else
            Add_Act (Item, Content, Paste_Act, "Paste", Icon_Set.Plus, Paste);
            Add_Act (Item, Content, Select_All_Act, "Select all", Pomarine.Icons.Check);
         end if;
         Show_Context (Item, Content, Text_Context, X, Y);
         Opened := True;
      end Text_Menu;

      procedure Of_Picture (Shown : Readers.Reader; Slot : Natural) is
      begin
         Begin_Menu;
         Item.Context.Context_Reader := Slot;
         Picture_Menu
           (Readers.Is_Over_Selection (Shown, PX, PY),
            Readers.Has_Words (Shown));
      end Of_Picture;

      procedure Of_Text (Rank : Positive) is
         Page  : Doc_Page renames Item.Docs.Pages (Rank);
         Area  : Pomarine.Text_Areas.Text_Area renames Editors.Area (Page.Text).all;
         Over  : constant Boolean :=
           Pomarine.Text_Areas.Is_Over_Selection (Area, PX, PY);
      begin
         --  The caret goes where it was pressed, unless that is in the
         --  selection.
         Widgets.Focus (Page.Text);
         if not Over then
            Pomarine.Text_Areas.Click (Area, PX, PY);
            Pomarine.Text_Areas.Release (Area);
         end if;
         Begin_Menu;
         Item.Context.Context_Page := Rank;
         Text_Menu (Over);
      end Of_Text;

      procedure Of_Window (Which : Items.Slot) is
         Shown : Windows.Window renames Item.Windows (Which);
      begin
         if Windows.Text_Contains (Shown, PX, PY) then
            declare
               Over : constant Boolean :=
                 Windows.Over_Text_Selection (Shown, PX, PY);
            begin
               if not Over then
                  Windows.Put_Caret (Shown, PX, PY);
               end if;
               Begin_Menu;
               Item.Context.Context_Canvas := Which;
               Text_Menu (Over);
            end;
         elsif Support.Is_Source (Item, Which)
           and then Windows.Picture_Contains (Shown, PX, PY)
         then
            Begin_Menu;
            Item.Context.Context_Canvas := Which;
            Picture_Menu
              (Windows.Over_Picture_Selection (Shown, PX, PY),
               Windows.Has_Words (Shown));
         end if;
      end Of_Window;
   begin
      Opened := False;
      if View_Mode (Item) = Canvas then
         --  The window under the pointer, if it is of one.
         declare
            Under : constant Widgets.Widget_Access :=
              Widgets.Hit (Item.Root.Widgets, PX, PY);
         begin
            for Which in 1 .. Item.Windows.Count loop
               if Windows.Is_Assigned (Item.Windows (Which))
                 and then Windows.Owns (Item.Windows (Which), Under)
               then
                  Of_Window (Which);
                  return;
               end if;
            end loop;
         end;
         return;
      end if;
      if Widgets.Contains (Item.Page_View.Docs_Scroll, PX, PY) then
         for Row in 1 .. Trees.Count (Item.Docs.Ordering) loop
            if Widgets.Contains (Item.Docs.Doc_Rows (Row).Row, PX, PY) then
               Of_Row (Trees.Element (Item.Docs.Ordering, Row));
               return;
            end if;
         end loop;
      elsif Widgets.Contains (Item.Page_View.Sources_Scroll, PX, PY) then
         for Row in 1 .. Writing_Sources_VM.Count (Item.Reading.Sources) loop
            if Widgets.Contains (Item.Reading.Source_Rows (Row).Row, PX,
                                 PY)
            then
               Of_Row
                 ((Kind => Document_Leaf, Dir => 0,
                   Doc  => Writing_Sources_VM.Slot_At (Item.Reading.Sources, Row)));
               return;
            end if;
         end loop;
      end if;
      --  A source's window is over the pages.
      for Which in 1 .. Item.Windows.Count loop
         if Readers.Is_Assigned (Item.Reading.Readers (Which))
           and then Readers.Details (Item.Reading.Readers (Which)).State
              = Items.Open
           and then Item.Reading.Pinned_Slot /= Which
         then
            declare
               Box : constant Items.Frame :=
                 Readers.Box (Item.Reading.Readers (Which));
            begin
               if PX in Box.Left .. Box.Left + Box.Width
                 and then PY in Box.Top .. Box.Top + Box.Height
               then
                  if Readers.Picture_Contains (Item.Reading.Readers (Which),
                                               PX, PY)
                  then
                     Of_Picture (Item.Reading.Readers (Which), Which);
                  end if;
                  return;
               end if;
            end;
         end if;
      end loop;
      if Item.Reading.Pinned_Slot /= 0
       and then Widgets.Contains (Item.Page_View.Pane, PX, PY)
      then
         if Readers.Picture_Contains (Item.Reading.Pane_Reader, PX, PY) then
            Of_Picture (Item.Reading.Pane_Reader, 0);
         end if;
         return;
      end if;
      for Rank in 1 .. Trees.Page_Count (Item.Docs.Ordering) loop
         if Support.In_View (Item, Trees.Page_At (Item.Docs.Ordering, Rank))
           and then Widgets.Contains (Item.Docs.Pages (Rank).Text, PX, PY)
         then
            Of_Text (Rank);
            return;
         end if;
      end loop;
   end Open_At;

   procedure Do_Context (Item : in out Session; Chosen : Positive) is
      Act  : constant Context_Acts := Item.Context.Context_Acts (Chosen);
      Kind : constant Context_Kinds := Item.Context.Context_Kind;
      Node : constant Tree_Entry := Item.Context.Context_Node;
      Page : constant Natural := Item.Context.Context_Page;
      Slot : constant Natural := Item.Context.Context_Reader;
      On_Canvas : constant Natural := Item.Context.Context_Canvas;
      Board : constant Widgets.Clipboard_Access :=
        Widgets.Clipboard (Content_Panel (Item).all);
   begin
      Popups.Close_Context (Item);
      case Kind is
         when No_Context =>
            null;
         when Tree_Context =>
            if Act = Add_Document_Act then
               Tree.Show_Directory (Item, Node.Dir);
               Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
            elsif Act = Add_Folder_Act then
               Rename.New_Directory (Item, "Untitled folder", Node.Dir);
            elsif Act = Rename_Act then
               if Node.Kind = Directory_Node then
                  Rename.Begin_Rename_Dir (Item, Node.Dir);
               elsif Support.Is_Source (Item, Node.Doc) then
                  Rename.Begin_Rename_Source (Item, Node.Doc);
               else
                  Rename.Begin_Rename_Doc (Item, Node.Doc);
               end if;
            elsif Act = Delete_Act
              and then not (Node.Kind = Directory_Node and then Support.Is_Section (Item, Node.Dir))
            then
               Deletion.Confirm_Node (Item, Node);
            end if;
         when Text_Context =>
            if On_Canvas /= 0 then
               Windows.Edit_Text
                 (Item.Windows (On_Canvas),
                  (case Act is
                     when Copy_Act   => Windows.Copy,
                     when Cut_Act    => Windows.Cut,
                     when Paste_Act  => Windows.Paste,
                     when others     => Windows.Select_All));
            elsif Page in 1 .. Trees.Page_Count (Item.Docs.Ordering)
             and then Board /= null
            then
               declare
                  Area : Pomarine.Text_Areas.Text_Area renames
                    Editors.Area (Item.Docs.Pages (Page).Text).all;
               begin
                  case Act is
                     when Copy_Act =>
                        Pomarine.Text_Areas.Copy (Area, Board.all);
                     when Cut_Act =>
                        Pomarine.Text_Areas.Cut (Area, Board.all);
                     when Paste_Act =>
                        Pomarine.Text_Areas.Paste (Area, Board.all);
                     when Select_All_Act =>
                        Pomarine.Text_Areas.Select_All (Area);
                     when others =>
                        null;
                  end case;
               end;
            end if;
         when Picture_Context =>
            declare
               procedure Act_On (Shown : in out Readers.Reader) is
               begin
                  if Readers.Is_Assigned (Shown) then
                     if Act = Copy_Act then
                        Readers.Copy (Shown);
                     elsif Act = Select_All_Act then
                        Readers.Select_All (Shown);
                     end if;
                  end if;
               end Act_On;
            begin
               if On_Canvas /= 0 then
                  if Act = Copy_Act then
                     Windows.Copy_Words (Item.Windows (On_Canvas));
                  elsif Act = Select_All_Act then
                     Windows.Select_All_Words (Item.Windows (On_Canvas));
                  end if;
               elsif Slot = 0 then
                  Act_On (Item.Reading.Pane_Reader);
               else
                  Act_On (Item.Reading.Readers (Slot));
               end if;
            end;
      end case;
   end Do_Context;

   procedure Remove_Directory
     (Item : in out Session; Dir : Positive; Delete_Documents : Boolean)
   is
      Keys : Items.Id_List;
      Documents : array (1 .. Item.Windows.Count) of Boolean := [others => False];
   begin
      if Support.Is_Section (Item, Dir) then
         return;
      end if;
      --  Capture membership before removing anything: removal rebuilds
      --  rows and can change directory indices and document order.
      for Each in 1 .. Item.Docs.Dirs.Count loop
         if Support.Within (Item, Each, Dir) then
            Keys.Append (Item.Docs.Dirs (Each).Key);
         end if;
      end loop;
      pragma Assert (Keys.Count > 0);
      for Which in 1 .. Item.Windows.Count loop
         Documents (Which) := Support.Is_Note (Item, Which)
           and then Support.Within (Item, Trees.Directory_Of (Item.Docs.Ordering, Which), Dir);
      end loop;
      if Delete_Documents then
         for Which in 1 .. Item.Windows.Count loop
            if Documents (Which) then
               Canvas_Items.Remove (Item, Which);
            end if;
         end loop;
      end if;
      for Key of Keys loop
         Items.Directories.Delete_Directory (Item.Nav.Store, Key);
      end loop;
      Tree.Rebuild (Item);
      Order.Keep_Order (Item);
      Outlines.Reload (Item);
      Item.Section_Menu.Changes := Item.Section_Menu.Changes + 1;
      Item.Section_Menu.Seen := Item.Section_Menu.Changes;
      Tree.Show_Directory (Item, Writing_VM.Shown (Item.Docs.Navigation, Item.Docs.Dirs));
   end Remove_Directory;

   procedure Delete_Tree_Node
     (Item : in out Session; Node : Tree_Entry; Delete_Documents : Boolean := False) is
   begin
      case Node.Kind is
         when Document_Leaf =>
            Canvas_Items.Remove (Item, Node.Doc);
         when Directory_Node =>
            Remove_Directory (Item, Node.Dir, Delete_Documents);
         when Overview_Node =>
            null;
      end case;
   end Delete_Tree_Node;

end View.Writing.Context;
