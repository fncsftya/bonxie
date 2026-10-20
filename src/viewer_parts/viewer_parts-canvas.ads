with Items;
with Items.Links;
with Texts.Documents;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pins;
with Pomarine.Widgets.Scrollers;

--  The canvas's pins and links, its dock of minimised items and tray of tools, and the title being edited.
package Viewer_Parts.Canvas is

   type Pin_Grid is
     array (Items.Slot, Items.Links.Sides) of aliased Pomarine.Widgets.Pins.Pin;
   --  The handles to link items by: four round each window.

   type Stroke_Button_Array is
     array (Items.Links.Strokes) of Pomarine.Widgets.Buttons.Button;

   type End_Button_Array is
     array (Items.Links.Endings) of Pomarine.Widgets.Buttons.Button;

   type Color_Button_Array is
     array (Items.Links.Link_Colors) of Pomarine.Widgets.Buttons.Button;

   type Pin_Places is array (Items.Slot, Items.Links.Sides) of Float;

   type Dock_Parts is limited record
      Dock_Panel    : Pomarine.Widgets.Panels.Panel;
      Dock_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Dock_Content  : Pomarine.Widgets.Panels.Panel;
      --  The bars sit in a row in Dock_Content, which scrolls across
      --  when they are wider than the window.
      --  A bar above the tools, of the bars of the items that are
      --  minimised: shown only when there are any.
      Tools         : Pomarine.Widgets.Panels.Panel;
      Tool_Item     : Pomarine.Widgets.Buttons.Button;
      Tool_Source   : Pomarine.Widgets.Buttons.Button;
      --  The tray of the canvas's tools, over it at the foot, in the
      --  middle: Add Document, Add Source.
      Tray_Left     : Float := -1.0E9;
      --  Where it was last put, in pixels from the left of the content.
      Tool_List     : Pomarine.Widgets.Buttons.Button;
      --  At the right of the toolbar: the list of items.
   end record;
   --  The dock of minimised items and the tray of tools, over the canvas.

   type Link_State is limited record
      Pins         : Pin_Grid;
      --  On the canvas, over the windows, shown where the pointer is.
      Pin_Left, Pin_Top : Pin_Places := [others => [others => -1.0E9]];
      --  Where each was last put, in pixels, to put it again only if it
      --  moves.
      Link_Handle  : Pomarine.Widgets.Pins.Pin;
      --  Over the target end of the selected link, to drag it to another
      --  pin by.
      Link_Bar     : Pomarine.Widgets.Panels.Panel;
      Stroke_Buttons : Stroke_Button_Array;
      End_Buttons    : End_Button_Array;
      Color_Buttons  : Color_Button_Array;
      Delete_Link    : Pomarine.Widgets.Buttons.Button;
      --  Beside the selected link: how it is drawn, and to delete it.
      Link_Key     : Items.Id := 0;
      --  The link selected, 0 if none.
      Link_Moving  : Boolean := False;
      --  Whether the target end of the selected link is being dragged,
      --  rather than a new link from a pin.
      Handle_Left, Handle_Top, Bar_Left, Bar_Top : Float := -1.0E9;
      --  Where they were last put, in pixels.
      Link_Set     : Items.Links.Link_List;
      --  The links between the project's items.
      Link_From    : Natural := 0;
      Link_From_Side : Items.Links.Sides := Items.Links.Top;
      --  The window and side of the pin a line is being dragged from;
      --  0 if none is.
   end record;
   --  The pins, and the links being made, selected and drawn.

   type Title_Edit_State is limited record
      Edit_Doc     : aliased Texts.Documents.Document;
      Edit_Field   : Pomarine.Widgets.Text_Fields.Text_Field;
      --  The title being renamed, and the field for it, which is in the
      --  edit panel: after Target, and the document.
   end record;
   --  The title of an item on the canvas being renamed.

end Viewer_Parts.Canvas;
