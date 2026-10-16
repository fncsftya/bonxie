with Pomarine.Page_Builds;
with SDL3.Events;
with Goldens;
with Projects;
with Viewer;
with Viewer.Home_Screen;
with Viewer.Outline_Screen;
with Viewer.Project_Screen;

package body Outline_Tests is

   package Events renames SDL3.Events;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Outline renames Viewer.Outline_Screen;
   package Pictures renames Goldens.Images;

   procedure Check (Name : String; Expected, Actual : String)
     renames Goldens.Check_Text;

   Width  : constant := 720;
   Height : constant := 480;
   --  Of the window, in points; the toolbar is 44 high at the top.

   procedure Start (Session : in out Viewer.Session) is
   begin
      Viewer.Open (Session, "", Width, Height, 2.0);
      Home.New_Project (Session);
   end Start;

   procedure Type_In (Session : in out Viewer.Session; Text : String) is
   begin
      Viewer.Handle (Session, Events.Text_Event (Text));
   end Type_In;

   procedure Move_To
     (Session : in out Viewer.Session; X, Y : Float; Held : Boolean := False) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X,
                                Mouse_Y => Y, Left_Held => Held, others => <>));
   end Move_To;

   procedure Press (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Press;

   procedure Release (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Release;

   procedure Settle (Session : in out Viewer.Session) is
      Drawn : Pictures.Image;
   begin
      --  Drawn, as it is between a person's clicks: what was typed is kept.
      Viewer.Render (Session, Drawn);
      Pomarine.Page_Builds.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
   end Settle;

   procedure Snap (Session : in out Viewer.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   function Titles (Session : Viewer.Session) return String is
      Result : String (1 .. 4096);
      Last   : Natural := 0;
   begin
      for Row in 1 .. Outline.Section_Count (Session) loop
         declare
            Title : constant String := Outline.Section_Title (Session, Row);
         begin
            Result (Last + 1 .. Last + Title'Length + 1) := Title & "|";
            Last := Last + Title'Length + 1;
         end;
      end loop;
      return Result (1 .. Last);
   end Titles;

   procedure Reopen (Session : in out Viewer.Session) is
      Key : constant Projects.Id := Proj.Current_Project (Session);
   begin
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
   end Reopen;

   procedure Starting is
      Session : Viewer.Session;
   begin
      Start (Session);
      --  A project opens to its outline, the first of the tabs.
      Check ("outline-mode", "OUTLINE", Viewer.Modes'Image (Proj.Mode (Session)));
      Check ("outline-none", "", Titles (Session));
      Snap (Session, "outline-empty");

      --  The tab last chosen is the one it opens to.
      Proj.Set_Mode (Session, Viewer.Write);
      Reopen (Session);
      Check ("outline-mode-write", "WRITE", Viewer.Modes'Image (Proj.Mode (Session)));
      Proj.Set_Mode (Session, Viewer.Canvas);
      Reopen (Session);
      Check ("outline-mode-canvas", "CANVAS", Viewer.Modes'Image (Proj.Mode (Session)));
      Proj.Set_Mode (Session, Viewer.Outline);
      Reopen (Session);
      Check ("outline-mode-outline", "OUTLINE", Viewer.Modes'Image (Proj.Mode (Session)));
   end Starting;

   procedure Sections is
      Session : Viewer.Session;
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Beginning");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Middle");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "End");
      Settle (Session);
      Check ("outline-added", "Beginning|Middle|End|", Titles (Session));
      Snap (Session, "outline-sections");

      Outline.Move_Section (Session, 3, 1);
      Check ("outline-moved", "End|Beginning|Middle|", Titles (Session));
      Snap (Session, "outline-moved");
      Outline.Move_Section (Session, 1, 2);
      Check ("outline-moved-down", "Beginning|End|Middle|", Titles (Session));

      --  Dragged by the handle of the first, over the second, and let go
      --  below the last: with a ghost of it under the pointer.
      Move_To (Session, 385.0, 122.0);
      Press (Session, 385.0, 122.0);
      Move_To (Session, 385.0, 150.0, Held => True);
      Move_To (Session, 385.0, 235.0, Held => True);
      Snap (Session, "outline-dragging");
      Release (Session, 385.0, 235.0);
      Settle (Session);
      Check ("outline-dragged", "End|Middle|Beginning|", Titles (Session));
      Outline.Move_Section (Session, 3, 1);
      Check ("outline-dragged-back", "Beginning|End|Middle|", Titles (Session));

      Outline.Remove_Section (Session, 2);
      Check ("outline-removed", "Beginning|Middle|", Titles (Session));

      --  Kept, in that order.
      Reopen (Session);
      Check ("outline-kept", "Beginning|Middle|", Titles (Session));
      Outline.Move_Section (Session, 2, 1);
      Reopen (Session);
      Check ("outline-order-kept", "Middle|Beginning|", Titles (Session));
   end Sections;

   procedure Form is
      Session : Viewer.Session;
   begin
      Start (Session);
      Check ("outline-form-title", "Untitled project", Outline.Project_Title (Session));
      Check ("outline-form-description", "", Outline.Project_Description (Session));
   end Form;

end Outline_Tests;
