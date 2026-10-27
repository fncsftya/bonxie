with Ada.Command_Line;
with Ada.Text_IO;
with Pomarine.Clipboards;
with Pomarine.Line_Texts;
with Pomarine.Pages;
with Pomarine.Themes;
with Pomarine.Words;
with Pomarine.Widgets.Page_Views;
with Pomarine.Widgets.Panels;
with SDL3.Windows.Renderers;
with Yoga.Nodes;
with Ebook;

--  Usage: page_view FILE OUT.bmp WIDTH HEIGHT ZOOM [DOWN]. Draws the PDF as
--  a Page_View does, offscreen, into a WIDTH x HEIGHT points window,
--  scrolled DOWN (0.0 .. 1.0) of the way, to look at.

procedure Page_View is
   package Widgets renames Pomarine.Widgets;
   package Renderers renames SDL3.Windows.Renderers;
   package Views renames Pomarine.Widgets.Page_Views;

   Density : constant Float := 2.0;
   File    : constant String := Ada.Command_Line.Argument (1);
   Out_BMP : constant String := Ada.Command_Line.Argument (2);
   Width   : constant Positive := Positive'Value (Ada.Command_Line.Argument (3));
   Height  : constant Positive := Positive'Value (Ada.Command_Line.Argument (4));
   Zoom    : constant Float := Float'Value (Ada.Command_Line.Argument (5));
   Down    : constant Float :=
     (if Ada.Command_Line.Argument_Count > 5 then Float'Value (Ada.Command_Line.Argument (6)) else 0.0);

   type From_File is limited new Pomarine.Pages.Source with null record;

   overriding
   procedure Build
     (Item    : in out From_File;
      Index   : Positive;
      Content : out Pomarine.Pages.Page_Access;
      Found   : in out Pomarine.Words.Result;
      Ok      : out Boolean)
   is
      pragma Unreferenced (Item);
      Message : String (1 .. Ebook.Max_Message);
      Last    : Natural;
      use type Pomarine.Pages.Page_Access;
   begin
      Ebook.Build_Page (File, Index, Content, Found, Message, Last);
      Ok := Content /= null;
   end Build;

   Origin  : aliased From_File;
   Target  : Renderers.Renderer;
   Lines   : aliased Pomarine.Line_Texts.Drawer;
   Tree    : Widgets.Tree;
   Board   : Pomarine.Clipboards.Memory_Clipboard;
   Root    : aliased Pomarine.Widgets.Panels.Panel;
   Shown   : aliased Views.Page_View;
   Info    : Ebook.Information;
   Sizes   : Pomarine.Pages.Size_Array_Access;
   Message : String (1 .. Ebook.Max_Message);
   Last    : Natural;
   use type Pomarine.Pages.Size_Array_Access;
begin
   Ebook.Open (File, Info, Message, Last);
   if Info.Pages = 0 then
      Ada.Text_IO.Put_Line ("cannot open: " & Message (1 .. Last));
      return;
   end if;
   Ebook.Document_Sizes (File, Info.Pages, Sizes, Message, Last);
   if Sizes = null then
      Ada.Text_IO.Put_Line ("no sizes: " & Message (1 .. Last));
      return;
   end if;
   Renderers.Create_Offscreen (Target, Positive (Float (Width) * Density), Positive (Float (Height) * Density));
   Widgets.Set_Density (Tree, Density);
   Widgets.Set_Clipboard (Tree, Board);
   Widgets.Set_Line_Texts (Tree, Lines);
   Widgets.Set_Root (Tree, Root);
   Widgets.Add (Root, Shown);
   Yoga.Nodes.Set_Flex_Grow (Widgets.Node (Shown), 1.0);
   Views.Set_Document (Shown, Sizes, Origin'Unchecked_Access);
   Views.Set_Zoom (Shown, Zoom);
   Widgets.Layout (Tree, Target);
   Views.Scroll_To (Shown, Down);
   --  A page is made to a frame: draw until they are all there.
   for Pass in 1 .. 20 loop
      Pomarine.Line_Texts.Begin_Frame (Lines);
      Widgets.Invalidate (Shown);
      Widgets.Paint (Tree, Target, Pomarine.Themes.Light);
   end loop;
   Renderers.Save_BMP (Target, Out_BMP);
   Ada.Text_IO.Put_Line
     ("pages"
      & Views.Page_Count (Shown)'Image
      & " current"
      & Views.Current_Page (Shown)'Image
      & " words"
      & Views.Word_Count (Shown)'Image);
end Page_View;
