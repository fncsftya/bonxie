with Ada.Directories;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Icon_Set;
with Items.Readers.Callbacks;
with Items.Sources;
with Model_Replies;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Toasts;
with Source_Finder;
with Viewer.Canvas_Items;
with Viewer.Settings_View;
with Viewer.Style;

package body Viewer.Find_Sources is

   package Hooks is new Pomarine.Widgets.Callbacks (Session);
   package Widgets renames Pomarine.Widgets;
   package Toasts renames Pomarine.Widgets.Toasts;
   package Menus renames Pomarine.Widgets.Menus;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Editors renames Pomarine.Widgets.Editors;
   package Windows renames Items.Windows;
   package Readers renames Items.Readers;
   package Reader_Events is new Items.Readers.Callbacks (Session);

   use type Source_Finder.States;
   use type GNAT.OS_Lib.String_Access;
   use type Readers.Actions;
   use type Items.Id;
   use type SDL3.Events.Milliseconds;

   Toast_Width : constant Float := 340.0;
   Toast_Top   : constant Float := 12.0;
   Toast_Right : constant Float := 16.0;
   --  In points: where the toast is in the content area.

   Seen_For : constant SDL3.Events.Milliseconds := 6_000;
   --  How long a message that is only to be seen is left up.

   function Image (Number : Natural) return String is
     (Model_Replies.Tidy (Natural'Image (Number), 10));

   function Is_Blank (Words : String) return Boolean is
     (for all C of Words => C <= ' ');

   function Note_Window (Item : Session) return Natural is
   begin
      for Which in 1 .. Item.Windows.Count loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Windows.Details (Item.Windows (Which)).Key = Item.Finder.Note
         then
            return Which;
         end if;
      end loop;
      return 0;
   end Note_Window;
   --  The window of the item the sources are for, 0 if it has gone.

   --  The preview

   procedure Close_Preview (Item : in out Session) is
   begin
      Item.Finder.Previewing := 0;
      if Readers.Is_Assigned (Item.Finder.Preview) then
         Readers.Release (Item.Finder.Preview);
      end if;
   end Close_Preview;

   procedure Show_Preview (Item : in out Session; Index : Positive) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Wide   : constant Float := Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels;
      High   : constant Float := Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels;
      Had    : constant Boolean := Readers.Is_Assigned (Item.Finder.Preview);
      Room   : constant Float := Wide - Toast_Right - Toast_Width - 2.0 * Style.Reader_Margin;
      --  Left of the toast and the list, as much as there is.
      Across : constant Float := Float'Min (Readers.Window_Width, Float'Max (Readers.Least_Width, Room));
      Where  : Items.Frame :=
        (Left   => Float'Max (Style.Reader_Margin, Wide - Toast_Right - Toast_Width - Style.Reader_Margin - Across),
         Top    => Toast_Top,
         Width  => Across,
         Height => Float'Min
                     (Readers.Window_Height, Float'Max (Readers.Least_Height, High - Toast_Top - Style.Reader_Margin)));
   begin
      --  Where the person put it, if it was moved or sized, is where it stays.
      if Had then
         Where := Readers.Details (Item.Finder.Preview).Where;
         Readers.Release (Item.Finder.Preview);
      end if;
      Readers.Assign
        (Item.Finder.Preview,
         (Title       => Projects.Titles.To_Text
                           (Source_Finder.Title (Index)),
          Where       => Where,
          State       => Items.Open,
          Kind        => Items.Source,
          Captured_At => Canvas_Items.Capture_Time (Item),
          Origin      => Items.Remote,
          Document    => (if Source_Finder.Is_Document (Index) then Items.Extensions.To_Text ("pdf")
                          else Items.Extensions.Null_Text),
          Page        => (if Source_Finder.Is_Document (Index) then 1 else 0),
          Page_Count  => Source_Finder.Pages (Index),
          others      => <>),
         Where, Source_Finder.File (Index));
      Readers.Set_Frame (Item.Finder.Preview, Where);
      Readers.Set_State (Item.Finder.Preview, Items.Open);
      Readers.Place (Item.Finder.Preview);
      Readers.Bring_To_Front (Item.Finder.Preview);
      --  The list and the toast stay over it.
      Widgets.Raise_To_Front (Item.Finder.Review);
      Widgets.Raise_To_Front (Item.Finder.Toast);
      Item.Finder.Previewing := Index;
   end Show_Preview;

   procedure Visit_Source (Index : Natural) is
      Opener  : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("open");
      Started : Boolean;
   begin
      --  Only a web page is handed on, never a file or another kind of link.
      if Index in 1 .. Source_Finder.Count and then Opener /= null then
         declare
            Page : constant String := Source_Finder.Address (Index);
            Args : GNAT.OS_Lib.Argument_List := [1 => new String'(Page)];
         begin
            if Page'Length > 8
              and then (Page (Page'First .. Page'First + 7) = "https://"
                        or else Page (Page'First .. Page'First + 6) = "http://")
            then
               GNAT.OS_Lib.Spawn (Opener.all, Args, Started);
            end if;
            GNAT.OS_Lib.Free (Args (1));
         end;
      end if;
      GNAT.OS_Lib.Free (Opener);
   end Visit_Source;

   procedure Preview_Asked (Item : in out Session; Which : Natural; Action : Readers.Actions) is
      pragma Unreferenced (Which);
   begin
      case Action is
         when Readers.Close =>
            Close_Preview (Item);
         when Readers.Visit =>
            Visit_Source (Item.Finder.Previewing);
         when Readers.None | Readers.Toggle_Pin =>
            null;
      end case;
   end Preview_Asked;

   --  The toast and the list

   procedure Close_Review (Item : in out Session) is
   begin
      Close_Preview (Item);
      if Item.Finder.Review_Open then
         Item.Finder.Review_Open := False;
         Widgets.Set_Visible (Item.Finder.Review, False);
      end if;
   end Close_Review;

   procedure Say (Item : in out Session; Words, Action : String) is
   begin
      Toasts.Set_Message (Item.Finder.Toast, Model_Replies.Cut (Words, Toasts.Text_Capacity));
      Toasts.Set_Action (Item.Finder.Toast, Action);
      if not Item.Finder.Shown then
         Item.Finder.Shown := True;
         Widgets.Set_Visible (Item.Finder.Toast, True);
         Widgets.Raise_To_Front (Item.Finder.Toast);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Say;

   procedure Hide (Item : in out Session) is
   begin
      Close_Review (Item);
      Item.Finder.Hide_After := 0;
      Item.Finder.Notice := False;
      if Item.Finder.Shown then
         Item.Finder.Shown := False;
         Widgets.Set_Visible (Item.Finder.Toast, False);
      end if;
   end Hide;

   procedure Fill_Review (Item : in out Session) is
      Menu : Menus.Menu renames Item.Finder.Review;
   begin
      Menus.Clear (Menu);
      Menus.Add (Menu, Menus.Heading, "Add as sources");
      for Each in 1 .. Source_Finder.Count loop
         Menus.Add
           (Menu, Menus.Action, Image (Source_Finder.Percent (Each)) & "%  " & Source_Finder.Title (Each));
         Menus.Set_Icon
           (Menu, Each + 1, (if Source_Finder.Is_Document (Each) then Icon_Set.Document else Icon_Set.Link));
      end loop;
      Menus.Add (Menu, Menus.Separator);
      Menus.Add (Menu, Menus.Action, (if Source_Finder.Count > 1 then "Add all" else "Add"), Shade => Menus.Primary);
      Menus.Add (Menu, Menus.Action, "Dismiss", Shade => Menus.Danger);
   end Fill_Review;

   procedure Open_Review (Item : in out Session) is
   begin
      Fill_Review (Item);
      Item.Finder.Review_Open := True;
      Widgets.Set_Visible (Item.Finder.Review, True);
      Widgets.Raise_To_Front (Item.Finder.Review);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Show_Preview (Item, 1);
   end Open_Review;

   --  Putting an end to it

   procedure Finish (Item : in out Session) is
   begin
      if Source_Finder.State /= Source_Finder.Running then
         Source_Finder.Reset;
         Item.Finder.Owner := False;
      end if;
      Hide (Item);
   end Finish;
   --  Away with the toast, the list and the pictures that were not added.

   procedure Add_One (Item : in out Session; Index : Positive; Added : out Boolean) is
   begin
      Canvas_Items.Add_Found_Source
        (Item, Note_Window (Item), Source_Finder.Title (Index), Source_Finder.Address (Index),
         Source_Finder.File (Index), Added, Document => Source_Finder.Is_Document (Index));
      if Added then
         Source_Finder.Take (Index);
      end if;
   end Add_One;

   procedure Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Total : constant Natural := Source_Finder.Count;
      Added : Boolean := True;
   begin
      if not Item.Finder.Review_Open or else Source_Finder.State /= Source_Finder.Done
        or else Item.Nav.Shown /= Project
      then
         return;
      end if;
      if Event.Row in 2 .. Total + 1 then
         Add_One (Item, Event.Row - 1, Added);
      elsif Event.Row = Total + 3 then
         while Added and then Source_Finder.Count > 0 loop
            Add_One (Item, 1, Added);
         end loop;
      elsif Event.Row = Total + 4 then
         Source_Finder.Reset;
         Finish (Item);
         return;
      end if;
      if not Added then
         Say (Item, "No room for more items in the project", "Dismiss");
         Close_Review (Item);
         Item.Finder.Notice := True;
         Item.Finder.Hide_After := SDL3.Events.Ticks + Seen_For;
      elsif Source_Finder.Count = 0 then
         Finish (Item);
      else
         Fill_Review (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Show_Preview (Item, 1);
      end if;
   end Chosen;

   procedure Build (Item : in out Session) is
      use all type Widgets.Event_Kind;
      Below : constant Float := Toast_Top + Toasts.Height + 4.0;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Finder.Toast);
      Layouts.Set_Layout
        (Item.Finder.Toast, Place => Layouts.Absolute, Width => Toast_Width, Height => Toasts.Height,
         Position => (Top => Toast_Top, Right => Toast_Right, others => <>));
      Widgets.Set_Visible (Item.Finder.Toast, False);
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Finder.Review);
      Layouts.Set_Layout
        (Item.Finder.Review, Place => Layouts.Absolute, Width => Toast_Width,
         Position => (Top => Below, Right => Toast_Right, others => <>));
      Menus.Set_Accented (Item.Finder.Review, True);
      Widgets.Set_Visible (Item.Finder.Review, False);
      Hooks.On (Item.Finder.Review, Choose, Item'Unrestricted_Access, Chosen'Access);
      Readers.Build (Item.Finder.Preview, Item.Toolbar.Content_Panel, Style.Toolbar, Item.Shell.Density);
      Readers.Set_Pinnable (Item.Finder.Preview, False);
      Readers.Set_Visitable (Item.Finder.Preview, True);
      Reader_Events.On (Item.Finder.Preview, 0, Item'Unrestricted_Access, Preview_Asked'Access);
   end Build;

   --  Starting

   procedure Start (Item : in out Session; Which : Items.Slot) is
      Words   : constant String := Windows.Text (Item.Windows (Which));
      Located : Ada.Strings.Unbounded.Unbounded_String;
      Why     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Item.Prefs.AI_On or else Is_Blank (Words) or else Source_Finder.State = Source_Finder.Running then
         return;
      end if;
      Close_Review (Item);
      Settings_View.Locate_AI_Model (Item, Located, Why);
      if Ada.Strings.Unbounded.Length (Why) > 0 then
         Source_Finder.Reset;
         Item.Finder.Owner := False;
         Say (Item, Ada.Strings.Unbounded.To_String (Why), "Dismiss");
         Item.Finder.Notice := True;
         Item.Finder.Hide_After := SDL3.Events.Ticks + Seen_For;
         return;
      end if;
      declare
         Key       : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
         Directory : constant String :=
           Ada.Directories.Containing_Directory
             (Items.Sources.Image_File (Item.Nav.Store, Item.Opened.Current, Key));
      begin
         Source_Finder.Reset;
         Source_Finder.Start (Ada.Strings.Unbounded.To_String (Located), Words, Directory);
         Item.Finder.Owner := True;
         Item.Finder.Notice := False;
         Item.Finder.Project := Item.Opened.Current;
         Item.Finder.Note := Key;
         Item.Finder.Hide_After := 0;
         Say (Item, "Finding sources", "Cancel");
      end;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         Say (Item, "The folder for the pages could not be made", "Dismiss");
         Item.Finder.Notice := True;
         Item.Finder.Hide_After := SDL3.Events.Ticks + Seen_For;
   end Start;

   --  As time goes

   procedure Allow_Buttons (Item : in out Session) is
      On : constant Boolean := Item.Prefs.AI_On;
   begin
      for Which in 1 .. Item.Windows.Count loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            Windows.Allow_Find_Sources (Item.Windows (Which), On);
         end if;
      end loop;
      for Rank in 1 .. Item.Windows.Count loop
         if Editors.Assist_Is_Allowed (Item.Docs.Pages (Rank).Text) /= On then
            Editors.Set_Assist_Allowed (Item.Docs.Pages (Rank).Text, On);
         end if;
      end loop;
   end Allow_Buttons;

   procedure Show_Work (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Count : constant Natural := Source_Finder.Count;
   begin
      case Source_Finder.State is
         when Source_Finder.Idle =>
            Item.Finder.Owner := False;
            Hide (Item);
         when Source_Finder.Running =>
            Say (Item, "Finding sources: " & Source_Finder.Status, "Cancel");
         when Source_Finder.Done =>
            if Count > 0 then
               Say (Item, Image (Count) & (if Count = 1 then " source found" else " sources found"), "Review");
            else
               Say (Item,
                    "No good sources found"
                    & (if Source_Finder.Examined_Count = 0 then ""
                       else " (" & Image (Source_Finder.Examined_Count)
                            & (if Source_Finder.Examined_Count = 1 then " page" else " pages") & " checked)"),
                    "Dismiss");
               if Item.Finder.Hide_After = 0 then
                  Item.Finder.Hide_After := Now + Seen_For;
               end if;
            end if;
         when Source_Finder.Failed =>
            Say (Item, Source_Finder.Message, "Dismiss");
            if Item.Finder.Hide_After = 0 then
               Item.Finder.Hide_After := Now + Seen_For;
            end if;
      end case;
   end Show_Work;

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Clicked : Boolean;
   begin
      Allow_Buttons (Item);
      Toasts.Take_Action (Item.Finder.Toast, Clicked);
      if Item.Finder.Notice then
         if Clicked or else (Item.Finder.Hide_After /= 0 and then Now >= Item.Finder.Hide_After) then
            Hide (Item);
         end if;
         return;
      end if;
      if not Item.Finder.Owner then
         return;
      end if;
      if Clicked then
         case Source_Finder.State is
            when Source_Finder.Running =>
               Source_Finder.Cancel;
            when Source_Finder.Done =>
               if Source_Finder.Count > 0 then
                  if Item.Finder.Review_Open then
                     Close_Review (Item);
                  else
                     Open_Review (Item);
                  end if;
               else
                  Finish (Item);
               end if;
            when Source_Finder.Failed =>
               Finish (Item);
            when Source_Finder.Idle =>
               null;
         end case;
      end if;
      if Item.Finder.Review_Open then
         --  The source the pointer is over in the list is the one shown.
         declare
            Row  : constant Natural := Menus.Hovered_Row (Item.Finder.Review);
            Over : constant Natural := (if Row in 2 .. Source_Finder.Count + 1 then Row - 1 else 0);
         begin
            if Over /= 0 and then Over /= Item.Finder.Previewing then
               Show_Preview (Item, Over);
            end if;
            if Readers.Is_Assigned (Item.Finder.Preview) then
               Readers.Update (Item.Finder.Preview);
            end if;
         end;
      end if;
      if Item.Finder.Owner then
         if Source_Finder.State = Source_Finder.Running and then not Item.Prefs.AI_On then
            Source_Finder.Cancel;
         end if;
         Source_Finder.Poll;
         if Item.Finder.Hide_After /= 0 and then Now >= Item.Finder.Hide_After then
            Finish (Item);
         else
            Show_Work (Item, Now);
         end if;
      end if;
   end Update;

   function Working (Item : Session) return Boolean is
     (Item.Finder.Hide_After /= 0
      or else (Item.Finder.Owner and then Source_Finder.State = Source_Finder.Running));

   procedure Leave (Item : in out Session) is
   begin
      Hide (Item);
      if Item.Finder.Owner then
         if Source_Finder.State = Source_Finder.Running then
            Source_Finder.Cancel;
         else
            Source_Finder.Reset;
            Item.Finder.Owner := False;
         end if;
      end if;
   end Leave;

   function Over_Preview (Item : Session; X, Y : Float) return Boolean is
   begin
      if not Readers.Is_Assigned (Item.Finder.Preview) then
         return False;
      end if;
      declare
         Box : constant Items.Frame := Readers.Box (Item.Finder.Preview);
      begin
         return X in Box.Left .. Box.Left + Box.Width and then Y in Box.Top .. Box.Top + Box.Height;
      end;
   end Over_Preview;
   --  Whether the pixel X, Y is in the preview's window.

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Item.Finder.Review_Open
        and then not Widgets.Contains (Item.Finder.Review, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (Item.Finder.Toast, X * Pixels, Y * Pixels)
        and then not Over_Preview (Item, X * Pixels, Y * Pixels)
      then
         Close_Review (Item);
      end if;
   end Pressed;

   procedure Stop is
   begin
      Source_Finder.Cancel;
      for Try in 1 .. 100 loop
         Source_Finder.Poll;
         exit when Source_Finder.State /= Source_Finder.Running;
         delay 0.02;
      end loop;
      --  What was found and not added is not kept.
      if Source_Finder.State /= Source_Finder.Running then
         Source_Finder.Reset;
      end if;
   end Stop;

end Viewer.Find_Sources;
