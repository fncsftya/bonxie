with SDL3.Events;
with SDL3.Windows.Renderers;
with Texts.Documents;
with Goldens;
with UI.Clipboards;
with UI.Themes;
with UI.Widgets.Panels;
with UI.Widgets.Text_Fields;
with Yoga.Nodes;

package body Field_Tests is

   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames UI.Widgets;
   package Docs renames Texts.Documents;
   package Nodes renames Yoga.Nodes;

   Colors : constant UI.Themes.Theme := UI.Themes.Light;

   --  A field in a window, drawn in software:
   --
   --     Root ── Field

   Density : constant Float := 2.0;
   Width   : constant := 240;
   Height  : constant := 72;
   Margin  : constant := 16;
   --  In points: the window, and the space around the field. The field
   --  is 40 high, and so is from 16 to 56 down.

   Middle : constant Float := 36.0;
   --  Down the window, in points, in the field.

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Doc    : aliased Docs.Document;
      Board  : UI.Clipboards.Memory_Clipboard;
      Root   : aliased UI.Widgets.Panels.Panel;
      Field  : aliased UI.Widgets.Text_Fields.Text_Field;
      --  after Target and Doc
   end record;

   procedure Open (Item : in out Fixture; Content : String := "") is
   begin
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Width) * Density),
         Positive (Float (Height) * Density));
      Docs.Load (Item.Doc, Content);
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Clipboard (Item.Tree, Item.Board);

      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Field);
      UI.Widgets.Text_Fields.Configure (Item.Field, "Georgia", Size => 16.0);
      UI.Widgets.Text_Fields.Attach (Item.Field, Item.Doc'Unchecked_Access);
      Widgets.Focus (Item.Field);

      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Column);
      Nodes.Set_Padding
        (Widgets.Node (Item.Root), Yoga.All_Edges,
         Float (Margin) * Density);
      Nodes.Set_Height (Widgets.Node (Item.Field), 40.0 * Density);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   procedure Check (Item : in out Fixture; Name : String) is
      Drawn : Images.Image;
   begin
      Widgets.Paint (Item.Tree, Item.Target, Colors, Retained => True);
      Images.Read (Drawn, Item.Target);
      Goldens.Check (Name, Drawn);
   end Check;

   procedure Draw (Item : in out Fixture; Drawn : in out Images.Image) is
   begin
      Widgets.Paint (Item.Tree, Item.Target, Colors, Retained => True);
      Images.Read (Drawn, Item.Target);
   end Draw;

   --  Events, as SDL would give them

   procedure Send (Item : in out Fixture; Event : Events.Event) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, Event, Handled);
      pragma Assert (Handled, "the field did not take an event");
   end Send;

   procedure Press
     (Item    : in out Fixture;
      Code    : Events.Key_Code;
      Command : Boolean := False) is
   begin
      Send (Item,
            (Kind => Events.Key_Down, Key => Code, Command => Command,
             others => <>));
   end Press;

   procedure Type_In (Item : in out Fixture; Text : String) is
   begin
      Send (Item, Events.Text_Event (Text));
   end Type_In;

   procedure Click (Item : in out Fixture; X : Float) is
      Ignored : Boolean;
   begin
      Send (Item,
            (Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
             Mouse_X => X, Mouse_Y => Middle, others => <>));
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Up, Button => 1, Mouse_X => X,
          Mouse_Y => Middle, others => <>),
         Ignored);
   end Click;

   function Returned (Item : in out Fixture) return Boolean is
      Result : Boolean;
   begin
      UI.Widgets.Text_Fields.Take_Return (Item.Field, Result);
      return Result;
   end Returned;

   procedure Check_Text (Name : String; Item : Fixture; Expected : String) is
   begin
      Goldens.Check_Text (Name, Expected, Docs.Whole (Item.Doc));
   end Check_Text;

   --  The tests

   procedure Typing is
      Item : Fixture;
   begin
      Open (Item);
      Check (Item, "field-empty");
      Type_In (Item, "Great skua");
      Check (Item, "field-typing");
      Check_Text ("field-typing-text", Item, "Great skua");
   end Typing;

   procedure Returning is
      Item   : Fixture;
      Before, After : Images.Image;
   begin
      Open (Item, "Great skua");
      Press (Item, Events.Key_Right_Arrow, Command => True);
      Draw (Item, Before);
      Goldens.Check_Text ("field-no-return-yet", "FALSE",
                          Boolean'Image (Returned (Item)));

      --  Return takes no new line, but is kept to be taken.
      Press (Item, Events.Key_Return);
      Check_Text ("field-return-text", Item, "Great skua");
      Draw (Item, After);
      Goldens.Check_Same ("field-return-same", Before, After);
      Goldens.Check_Text ("field-return-taken", "TRUE",
                          Boolean'Image (Returned (Item)));
      Goldens.Check_Text ("field-return-forgotten", "FALSE",
                          Boolean'Image (Returned (Item)));

      Type_In (Item, "!");
      Check_Text ("field-typing-after-return", Item, "Great skua!");
   end Returning;

   procedure Pasting is
      Item : Fixture;
   begin
      Open (Item);
      --  Line feeds in what is typed or pasted are spaces.
      Item.Board.Set_Text ("Great" & ASCII.LF & "skua" & ASCII.CR);
      Press (Item, Events.Key_V, Command => True);
      Check_Text ("field-paste-text", Item, "Great skua");
      Type_In (Item, "A" & ASCII.LF & "B");
      Check_Text ("field-typed-line-feed", Item, "Great skuaA B");
   end Pasting;

   procedure Long_Line is
      Item : Fixture;
      Long : constant String :=
        "Bonxies are great skuas, which nest on moorland in Shetland and "
        & "Orkney and spend the winter at sea.";
   begin
      Open (Item);
      Type_In (Item, Long);
      --  Not wrapped: scrolled to the caret, at the end.
      Check (Item, "field-long-end");
      Check_Text ("field-long-text", Item, Long);

      Press (Item, Events.Key_Left_Arrow, Command => True);
      Check (Item, "field-long-start");
   end Long_Line;

   procedure Clicking is
      Item : Fixture;
   begin
      Open (Item, "Great skua");
      --  Past the end, and before the start.
      Click (Item, Float (Width - Margin) - 2.0);
      Type_In (Item, "!");
      Click (Item, Float (Margin) + 2.0);
      Type_In (Item, ">");
      Check_Text ("field-clicked-text", Item, ">Great skua!");
      Check (Item, "field-clicked");
   end Clicking;

   procedure Up_And_Down is
      Item : Fixture;
   begin
      Open (Item, "Great skua");
      Press (Item, Events.Key_Down_Arrow);
      Type_In (Item, "!");
      Press (Item, Events.Key_Up_Arrow);
      Type_In (Item, ">");
      Check_Text ("field-up-down-text", Item, ">Great skua!");
   end Up_And_Down;

end Field_Tests;
