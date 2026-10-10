with SDL3.Events;
with SDL3.Windows.Renderers;
with Yoga.Nodes;

procedure Bonxie is
   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Message       : constant String := "Hello, World!";
   Message_Scale : constant := 4;
   Toolbar_Size  : constant Float := 48.0;

   Background : constant Color := (30, 30, 36, 255);
   Toolbar    : constant Color := (52, 54, 66, 255);
   Text       : constant Color := (230, 230, 235, 255);
begin
   SDL3.Initialize;

   declare
      Win  : SDL3.Windows.Window;
      Ev   : SDL3.Events.Event;
      Done : Boolean := False;

      UI : Yoga.Nodes.Tree;
      --  Frame: a column holding the content area above the toolbar.
      Content_Node : constant Yoga.Nodes.Node :=
        Yoga.Nodes.New_Child (Yoga.Nodes.Root (UI));
      Toolbar_Node : constant Yoga.Nodes.Node :=
        Yoga.Nodes.New_Child (Yoga.Nodes.Root (UI));
      Message_Node : constant Yoga.Nodes.Node :=
        Yoga.Nodes.New_Child (Content_Node);
   begin
      SDL3.Windows.Create
        (Win, "Hello, World! - bonxie", 800, 600, Resizable => True);

      declare
         R : Renderer;
         W, H : Natural;
      begin
         Create (R, Win);

         Yoga.Nodes.Set_Flex_Direction (Yoga.Nodes.Root (UI), Yoga.Column);

         --  Content fills the space above the toolbar; centers its child.
         Yoga.Nodes.Set_Flex_Grow (Content_Node, 1.0);
         Yoga.Nodes.Set_Justify_Content (Content_Node, Yoga.Center);
         Yoga.Nodes.Set_Align_Items (Content_Node, Yoga.Center);

         Yoga.Nodes.Set_Height (Toolbar_Node, Toolbar_Size);

         Yoga.Nodes.Set_Width
           (Message_Node,
            Float (Message'Length * Debug_Text_Size * Message_Scale));
         Yoga.Nodes.Set_Height
           (Message_Node, Float (Debug_Text_Size * Message_Scale));

         --  Repaints at the current window size. Also used as the redraw
         --  handler: the OS blocks the event loop during a live resize, and
         --  only repainting from inside the event watch avoids a stretched
         --  frame.
         declare
            procedure Draw is
            begin
               Output_Size (R, W, H);
               Yoga.Nodes.Calculate_Layout (UI, Float (W), Float (H));

               Clear (R, Background);

               Fill_Rect
                 (R, Toolbar,
                  Yoga.Nodes.Left (Toolbar_Node),
                  Yoga.Nodes.Top (Toolbar_Node),
                  Yoga.Nodes.Width (Toolbar_Node),
                  Yoga.Nodes.Height (Toolbar_Node));

               --  Message_Node's position is relative to Content_Node.
               Draw_Text
                 (R, Text,
                  Yoga.Nodes.Left (Content_Node)
                  + Yoga.Nodes.Left (Message_Node),
                  Yoga.Nodes.Top (Content_Node)
                  + Yoga.Nodes.Top (Message_Node),
                  Message, Message_Scale);

               Present (R);
            end Draw;
         begin
            SDL3.Events.Set_Redraw_Handler (Draw'Unrestricted_Access);

            while not Done loop
               while SDL3.Events.Poll (Ev) loop
                  Done := Done or else Ev.Kind = SDL3.Events.Quit;
               end loop;

               Draw;  --  Present blocks on vsync
            end loop;
         end;
      end;
   end;  --  Renderer, then Win and UI, are destroyed here

   SDL3.Shutdown;
end Bonxie;
