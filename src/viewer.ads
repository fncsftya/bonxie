with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with SDL3.Windows;
private with Typeset.Documents;
private with Typeset.Views;
private with Yoga.Nodes;

--  A window showing a document, for scrolling and zooming.
package Viewer is

   procedure Run (Source : String);
   --  Open a window showing the text Source, a paragraph to each line,
   --  and run until it is closed. SDL must be initialized.

   --  Without a window, to test what is shown

   type Session is limited private;
   --  What Run shows, and how it is moved about.

   procedure Open
     (Item    : in out Session;
      Source  : String;
      Width   : Positive;
      Height  : Positive;
      Density : Float := 2.0)
     with Pre  => not Is_Open (Item) and then Density >= 1.0,
          Post => Is_Open (Item);
   --  Show Source as Run would, in a window Width x Height points of
   --  Density pixels each, but drawn offscreen, in software.

   function Is_Open (Item : Session) return Boolean;

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event)
     with Pre => Is_Open (Item);
   --  As if Event had come.

   procedure Settle (Item : in out Session)
     with Pre => Is_Open (Item);
   --  As if the zoom had held still for long enough to settle.

   procedure Resize (Item : in out Session; Width, Height : Positive)
     with Pre => Is_Open (Item);
   --  As if the window were resized to Width x Height points.

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image)
     with Pre => Is_Open (Item);
   --  Draw what is shown, as into the window, into Result.

private

   type Session is limited record
      UI           : Yoga.Nodes.Tree;
      --  A column: the page area above the toolbar.
      Page_Node    : Yoga.Nodes.Node;
      Toolbar_Node : Yoga.Nodes.Node;

      Doc          : Typeset.Documents.Document;
      Win          : SDL3.Windows.Window;
      Target       : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Page         : Typeset.Views.View;  --  and after Target
      Density      : Float := 1.0;
      --  Pixels to a point of the window.

      --  What is shown
      Anchor       : Typeset.Documents.Paragraph_Number := 1;
      Offset       : Float := 0.0;
      Zoom         : Float := 1.0;
      Settled      : Boolean := True;
      --  The zoom has stopped changing.

      Dirty        : Boolean := True;
      --  What is shown is out of date.
      Done         : Boolean := False;
   end record;

end Viewer;
