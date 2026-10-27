with Pomarine.Widgets;
with Pomarine.Widgets.Editors;

--  The tools bonxie adds to the toolbar of a rich text editor, for what is
--  selected in its text: Fade (Cmd+D) and Reword (Cmd+R). Add also gives the
--  editing buttons their icons.

package Word_Tools is

   Fade   : constant := 1;
   Reword : constant := 2;
   --  Their numbers, in the order Add gives them.

   procedure Add (Item : in out Pomarine.Widgets.Editors.Editor)
   with
     Pre  => Pomarine.Widgets.Editors.Tool_Count (Item) = 0,
     Post => Pomarine.Widgets.Editors.Tool_Count (Item) = Reword;

   procedure Use_Tool (Source : in out Pomarine.Widgets.Widget'Class; Tool : Natural);
   --  Do what the tool of this number, used in Source (see Editors.Callbacks.On_Tool), is
   --  for. Fade fades the selected text, or, if all of it is faded, brings
   --  it back (kept as <f> round it in the document's markup); Reword starts
   --  writing another version of it (see Editors.Begin_Version).

   procedure Follow (Source : in out Pomarine.Widgets.Widget'Class);
   --  Open, in the system's way (the default browser, the mail program), the
   --  link Source, an editor, said it was Command-clicked on (Editors.Callbacks.On_Follow). Only the addresses
   --  a person can make (see Pomarine.Text_Areas.Is_Address) are opened, as
   --  what is loaded may say any.

end Word_Tools;
