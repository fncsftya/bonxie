with Section_Colour_Pickers;
with Growing;
with Projects;
with Slot_Tables;
with Projects.Sections;
with Texts.Documents;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;

--  The outline view: the form of the project's title and description, and the blocks of its sections.
package Viewer_Parts.Outline is

   type Section_Block is limited record
      Doc    : aliased Texts.Documents.Document;
      --  The title, which the field shows.
      Seen   : Texts.Documents.Version := 0;
      --  The version of it that is kept.
      Row    : Pomarine.Widgets.Grips.Grip;
      --  The block, which is dragged by anywhere but its field and buttons.
      Line   : Pomarine.Widgets.Panels.Panel;
      --  The top of the block: the title and its buttons. Notes are under.
      Handle : Pomarine.Widgets.Labels.Label;
      Swatch : Pomarine.Widgets.Grips.Grip;
      --  The section's colour: a square, filled once an item is its own,
      --  and only outlined before.
      Field  : Pomarine.Widgets.Text_Fields.Text_Field;
      Notes  : Pomarine.Widgets.Buttons.Button;
      --  Shows or hides the notes, and is down while they are shown.
      Up     : Pomarine.Widgets.Buttons.Button;
      Down   : Pomarine.Widgets.Buttons.Button;
      Remove : Pomarine.Widgets.Buttons.Button;
      Notes_Doc   : aliased Texts.Documents.Document;
      --  The notes, which the editor shows.
      Notes_Seen  : Texts.Documents.Version := 0;
      --  The version of them that is kept.
      Notes_Sheet : Pomarine.Widgets.Panels.Panel;
      Notes_Text  : Pomarine.Widgets.Editors.Editor;
   end record;

   package Block_Tables is new Slot_Tables (Section_Block);
   subtype Section_Blocks is Block_Tables.Table;

   type Outline_Parts is limited record
      Colour_Popout : Pomarine.Widgets.Panels.Panel;
      Colour_Picker : Section_Colour_Pickers.Picker;
      Colour_Actions : Pomarine.Widgets.Panels.Panel;
      Colour_OK, Colour_Cancel : Pomarine.Widgets.Buttons.Button;
      Colour_Key : Projects.Sections.Section_Id := 0;
      Name_Doc    : aliased Texts.Documents.Document;
      Desc_Doc    : aliased Texts.Documents.Document;
      Name_Seen   : Texts.Documents.Version := 0;
      Desc_Seen   : Texts.Documents.Version := 0;
      --  The project's title and description, and the versions of them
      --  that are kept.
      Blocks      : Section_Blocks;
      Order       : Projects.Sections.Section_List;
      --  The sections, as kept: Blocks (1 .. Order.Count) show them.
      Links       : Projects.Sections.Link_List;
      --  The items of the project that are of a section, as kept.
      View        : Pomarine.Widgets.Panels.Panel;
      --  A row, in the content area when Mode is Outline: the form, and the
      --  sections.
      Form        : Pomarine.Widgets.Panels.Panel;
      Name_Label  : Pomarine.Widgets.Labels.Label;
      Name_Field  : Pomarine.Widgets.Text_Fields.Text_Field;
      Desc_Label  : Pomarine.Widgets.Labels.Label;
      Desc_Sheet  : Pomarine.Widgets.Panels.Panel;
      Desc_Text   : Pomarine.Widgets.Editors.Editor;
      Sections    : Pomarine.Widgets.Panels.Panel;
      Head        : Pomarine.Widgets.Panels.Panel;
      Heading     : Pomarine.Widgets.Labels.Label;
      Add_Button  : Pomarine.Widgets.Buttons.Button;
      --  Where the menu was last put.
      --  The ask: the tries made so far (0 when none is under way), the
      --  project it is for, the model's folder and what it is asked, and
      --  whether it is to give notes.
      Scroll      : Pomarine.Widgets.Scrollers.Scroller;
      Content     : Pomarine.Widgets.Panels.Panel;
      None        : Pomarine.Widgets.Labels.Label;
      Drop_Line   : Pomarine.Widgets.Panels.Panel;
      --  Between two blocks, where the one dragged would go.
      Ghost       : Pomarine.Widgets.Panels.Panel;
      Ghost_Title : Pomarine.Widgets.Labels.Label;
      --  Over the blocks, under the pointer while one is dragged: its title.
      Drag_Block  : Natural := 0;
      Drag_Total  : Float := 0.0;
      Drag_Moved  : Boolean := False;
      Drag_From_X : Float := 0.0;
      Drop_Before : Natural := 0;
      --  The block being dragged, how far and from where across, and the one it would go in
      --  front of (Order.Count + 1 for last), 0 if it would not move.
   end record;
   --  The outline view: the form of the project's title and description,
   --  and the blocks of its sections.

   package Row_Lists is new Growing (Natural);
   subtype Section_Rows is Row_Lists.List;
   --  The section of each row of the menu, after its heading: 0 for none.

   type Section_Menu_Parts is limited record
      Menu    : Pomarine.Widgets.Menus.Menu;
      --  Over the content, hidden until a button to link to the outline is
      --  clicked: a heading, a box for each section, ticked if it is the
      --  item's own, and faint if another item's.
      Which   : Natural := 0;
      --  The item the menu is of (its slot), 0 if it is not shown.
      Page    : Natural := 0;
      --  The page of the writing view whose button opened it, 0 for the
      --  canvas's window.
      Left, Top : Float := -1.0E9;
      --  Where it was last put.
      Rows    : Section_Rows;
      Remove  : Natural := 0;
      --  The row of the sections' boxes, and the row to take the link away.
      Changes : Natural := 0;
      Seen    : Natural := 0;
      --  How many times a link was made or taken away, and as of how many
      --  the writing view is shown.
   end record;

end Viewer_Parts.Outline;
