with Ada.Exceptions;
with Ada.Text_IO;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with UI.Widgets;
with Viewer.Build;
with Viewer.Clicks;
with Viewer.Deletion;
with Viewer.Navigation;
with Viewer.Painting;
with Viewer.Style;

package body Viewer is

   package Widgets renames UI.Widgets;
   package Canvases renames UI.Widgets.Canvases;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;

   use Ada.Strings.Unbounded;
   use type Projects.Id;
   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type SDL3.Cursors.Kind;
   use SDL3.Windows.Renderers;

   package Redraws is new SDL3.Events.Redraws (Session, Painting.Draw);

   --  Events

   function Cursor (Item : Session) return SDL3.Cursors.Kind is
     (Widgets.Wanted_Cursor (Item.Widgets));

   procedure Show_Cursor (Item : in out Session);
   --  Give the window the cursor the widgets want, if it is not that now.

   procedure Show_Cursor (Item : in out Session) is
      Wanted : constant SDL3.Cursors.Kind := Cursor (Item);
   begin
      if Item.Windowed and then Wanted /= Item.Shown_Cursor then
         SDL3.Cursors.Set (Wanted);
         Item.Shown_Cursor := Wanted;
      end if;
   end Show_Cursor;

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event) is
      Handled : Boolean := False;
   begin
      case Event.Kind is
         when SDL3.Events.Quit =>
            Item.Done := True;
         when SDL3.Events.Redraw =>
            Widgets.Invalidate_All (Item.Widgets);
         when others =>
            if Item.Deleting /= 0 then
               --  The dialog is all that takes events.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Deletion.Close (Item);
                  return;
               end if;
            --  The text is saved only from a project.
            elsif Item.Shown = Project
              and then Event.Kind = SDL3.Events.Key_Down
              and then Event.Command and then Event.Key = SDL3.Events.Key_S
            then
               Save (Item);
               Handled := True;
            end if;
            if not Handled then
               Widgets.Dispatch (Item.Widgets, Event, Handled);
               Clicks.Take (Item);
               Show_Cursor (Item);
            end if;
      end case;
   end Handle;

   --  The screens

   function Screen (Item : Session) return Screens is (Item.Shown);

   function Mode (Item : Session) return Modes is (Item.Mode);

   function Current_Project (Item : Session) return Projects.Id is
     (Item.Current);

   procedure New_Project (Item : in out Session)
     renames Navigation.Enter_New;

   procedure Open_Project (Item : in out Session; Key : Projects.Id)
     renames Navigation.Enter;

   procedure Close_Project (Item : in out Session)
     renames Navigation.Leave;

   procedure Add_Project
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
     renames Navigation.Keep;

   function Is_Renaming (Item : Session) return Boolean is
     (Item.Editing /= 0);

   function Is_Confirming (Item : Session) return Boolean is
     (Item.Deleting /= 0);

   function Row_Title (Item : Session; Row : Positive) return String is
     (if Row <= Item.Listed.Count then Buttons.Label (Item.Recent_Rows (Row))
      else "");

   --  The file

   function Title (Item : Session) return String is
     (case Item.Shown is
         when Home    => "bonxie",
         when Project => Scripts.Title (Item.Script));

   procedure Save (Item : in out Session) is
   begin
      if Scripts.File_Name (Item.Script) /= "" then
         Scripts.Save (Item.Script);
      end if;
   exception
      when Problem : others =>
         --  Keep the text, to save another time.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Could not save " & Scripts.File_Name (Item.Script) & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Save;

   procedure Show_Title (Item : in out Session);
   --  In the window's title bar, if it has changed.

   procedure Show_Title (Item : in out Session) is
      Now : constant String := Title (Item);
   begin
      if Now /= To_String (Item.Shown_Title) then
         SDL3.Windows.Set_Title (Item.Win, Now);
         Labels.Set_Text
           (Item.Header_Title,
            Now (Now'First ..
                 Now'First - 1
                 + Natural'Min (Now'Length, Labels.Text_Capacity)));
         Item.Shown_Title := To_Unbounded_String (Now);
      end if;
   end Show_Title;

   --  Running

   procedure Open
     (Item : in out Session; Source : String; File_Name : String) is
   begin
      Item.Windowed := True;
      SDL3.Windows.Create
        (Item.Win, "bonxie", Style.Window_Width, Style.Window_Height,
         Resizable => True, High_Density => True);
      Item.Density := SDL3.Windows.Pixel_Density (Item.Win);
      SDL3.Windows.Extend_Into_Title_Bar (Item.Win);
      Create (Item.Target, Item.Win);
      Build.Set_Up (Item, Source, File_Name, Projects.Default_Path);
      SDL3.Windows.Start_Text_Input (Item.Win);
   end Open;

   procedure Wait_And_Handle (Item : in out Session) is
      Event   : SDL3.Events.Event;
      Timeout : Integer := -1;  --  none

      procedure Wake_In (Milliseconds : Integer) is
      begin
         Timeout :=
           (if Timeout < 0 then Integer'Max (0, Milliseconds)
            else Integer'Min (Timeout, Integer'Max (0, Milliseconds)));
      end Wake_In;
   begin
      --  Nothing to do until something happens, except to blink a caret.
      Tick (Item, SDL3.Events.Ticks);
      if Widgets.Until_Update (Item.Widgets) >= 0 then
         Wake_In (Widgets.Until_Update (Item.Widgets));
      end if;

      if SDL3.Events.Wait (Event, Timeout_MS => Timeout) then
         Handle (Item, Event);
         while SDL3.Events.Poll (Event) loop
            Handle (Item, Event);
         end loop;
      end if;

      Tick (Item, SDL3.Events.Ticks);
   end Wait_And_Handle;

   --  Without a window

   function Pixels (Points : Positive; Density : Float) return Positive is
     (Positive (Float (Points) * Density));

   procedure Open
     (Item      : in out Session;
      Source    : String;
      Width     : Positive;
      Height    : Positive;
      Density   : Float := 2.0;
      File_Name : String := "") is
   begin
      Item.Density := Density;
      Create_Offscreen
        (Item.Target, Pixels (Width, Density), Pixels (Height, Density));
      Build.Set_Up (Item, Source, File_Name, Projects.Memory);
   end Open;

   function Is_Open (Item : Session) return Boolean is
     (Widgets.Has_Root (Item.Widgets));

   function Canvas_Zoom (Item : Session) return Float is
     (Canvases.Zoom (Item.Canvas_View));

   function Canvas_Origin_X (Item : Session) return Float is
     (Canvases.Origin_X (Item.Canvas_View));

   function Canvas_Origin_Y (Item : Session) return Float is
     (Canvases.Origin_Y (Item.Canvas_View));

   function Text (Item : Session) return String is
     (Scripts.Text (Item.Script));

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds) is
   begin
      Widgets.Update (Item.Widgets, Now);
   end Tick;

   procedure Resize (Item : in out Session; Width, Height : Positive) is
   begin
      SDL3.Windows.Renderers.Resize
        (Item.Target,
         Pixels (Width, Item.Density), Pixels (Height, Item.Density));
      --  Which loses what was drawn.
      Widgets.Invalidate_All (Item.Widgets);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Resize;

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image) is
   begin
      --  Offscreen there is nothing to present to.
      Painting.Paint (Item);
      SDL3.Windows.Renderers.Images.Read (Result, Item.Target);
   end Render;

   procedure Run (Source : String; File_Name : String := "") is
      Item    : aliased Session;
      Watcher : Redraws.Watch;  --  ends before Item does
   begin
      Open (Item, Source, File_Name);

      --  The redraw watch also draws: the OS blocks the event loop
      --  during a live resize, and only repainting from inside the event
      --  watch avoids a stretched frame.
      Redraws.Install (Watcher, Item);

      while not Item.Done loop
         Show_Title (Item);
         if Widgets.Needs_Paint (Item.Widgets) then
            Painting.Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
   end Run;

end Viewer;
