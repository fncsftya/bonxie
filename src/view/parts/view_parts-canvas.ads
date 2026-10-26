with Ada.Strings.Unbounded;
with Search_VM;
with Pomarine.Widgets.Labels;
with Growing;
with Items;
with Slot_Tables;
with Canvas_VM;
with Canvas_VM.Stored;
with Items.Links;
with Pomarine.UI;
with Pomarine.View_Models;
with Texts.Documents;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pins;
with Pomarine.Widgets.Scrollers;

--  The canvas's pins and links, its dock of minimised items and tray of tools, and the title being edited.
package View_Parts.Canvas is

   type Pin_Set is array (Items.Links.Sides) of aliased Pomarine.Widgets.Pins.Pin;
   --  The handles to link an item by: four round its window.

   package Pin_Tables is new Slot_Tables (Pin_Set);
   subtype Pin_Grid is Pin_Tables.Table;
   --  One set to each window.

   type Stroke_Button_Array is
     array (Items.Links.Strokes) of Pomarine.Widgets.Buttons.Button;

   type End_Button_Array is
     array (Items.Links.Endings) of Pomarine.Widgets.Buttons.Button;

   type Color_Button_Array is
     array (Items.Links.Link_Colors) of Pomarine.Widgets.Buttons.Button;

   type Pin_Place_Set is array (Items.Links.Sides) of Float;

   package Place_Lists is new Growing (Pin_Place_Set);
   subtype Pin_Places is Place_Lists.List;

   type Dock_Parts is limited record
      Dock_Panel    : Pomarine.Widgets.Panels.Panel;
      Dock_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Dock_Content  : Pomarine.Widgets.Panels.Panel;
      --  The bars sit in a row in Dock_Content, which scrolls across
      --  when they are wider than the window.
      --  A bar above the tools, of the bars of the items that are
      --  minimised: shown only when there are any.
      Tools         : Pomarine.UI.Layout;
      Tool_Item     : Pomarine.UI.Button_Handle;
      Tool_Source   : Pomarine.UI.Button_Handle;
      --  The tray of the canvas's tools, over it at the foot, in the
      --  middle: Add Document, Add Source.
      Tray_Left     : Float := -1.0E9;
      --  Where it was last put, in pixels from the left of the content.
      Tool_List     : Pomarine.UI.Button_Handle;
      --  At the right of the toolbar: the list of items.
   end record;
   --  The dock of minimised items and the tray of tools, over the canvas.

   type Link_State is limited record
      Pins         : Pin_Grid;
      --  On the canvas, over the windows, shown where the pointer is.
      Pin_Left, Pin_Top : Pin_Places;
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
      Handle_Left, Handle_Top, Bar_Left, Bar_Top : Float := -1.0E9;
      --  Where they were last put, in pixels.
   end record;
   --  The pins, and the links being made, selected and drawn: what they are is the canvas's view-model's
   --  (Canvas_VM).

   type Search_Document is record
      Which : Items.Slot := Items.Slot'First;
      Key : Items.Id := 0;
      Revision : Texts.Documents.Version := 0;
      Serial, Matches : Natural := 0;
   end record;
   package Search_Document_Lists is new Growing (Search_Document);

   type Search_State is limited record
      Bar : Pomarine.Widgets.Panels.Panel;
      Doc : aliased Texts.Documents.Document;
      Field : Pomarine.Widgets.Text_Fields.Text_Field;
      Previous, Next, Close : Pomarine.Widgets.Buttons.Button;
      Count : Pomarine.Widgets.Labels.Label;
      Model : Search_VM.View_Model;
      Shown : Pomarine.View_Models.Watch;
      --  Finder cache and navigation state of the writing/text engines. Search lifecycle and query are in Model.
      Documents : Search_Document_Lists.List;
      Total, Current, Rank : Natural := 0;
      Reveal_Pending : Boolean := False;
      Term : Ada.Strings.Unbounded.Unbounded_String;
      Seen : Texts.Documents.Version := 0;
   end record;

   type Canvas_Choices is limited record
      Library : aliased Canvas_VM.Stored.Project_Kept;
      Model   : aliased Canvas_VM.View_Model;
      --  What is on the canvas, where it is looked at from, what is done to it.
      Seen_Items    : Pomarine.View_Models.Watch;
      Seen_Camera   : Pomarine.View_Models.Watch;
      Seen_Steering : Pomarine.View_Models.Watch;
      Seen_Raised   : Pomarine.View_Models.Watch;
      Seen_Links    : Pomarine.View_Models.Watch;
      --  What the windows and the lines last showed of it.
   end record;
   --  The view-model of the canvas, and what the widgets show of it.

end View_Parts.Canvas;
