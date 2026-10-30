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

   type Thesaurus_States is (Unavailable, Several_Words, One_Word);
   --  Whether the thesaurus can be asked about the text selected in an editor: Unavailable if nothing
   --  is selected or the text cannot be written to; Several_Words if what is selected is more than three
   --  words (or has anything but letters and single spaces between them), or is in more than one paragraph,
   --  or part of a text with versions; One_Word otherwise (a word, or a phrase of two or three).

   function Thesaurus_State (Item : in out Pomarine.Widgets.Editors.Editor) return Thesaurus_States
   with Pre => Pomarine.Widgets.Editors.Has_Document (Item);

   function Selected_Word (Item : in out Pomarine.Widgets.Editors.Editor) return String
   with
     Pre  => Pomarine.Widgets.Editors.Has_Document (Item),
     Post => (Selected_Word'Result /= "") = (Thesaurus_State (Item) = One_Word);
   --  The word or short phrase selected (without the spaces at its ends), or "".

   procedure Use_Synonym (Item : in out Pomarine.Widgets.Editors.Editor; Word : String)
   with Pre => Pomarine.Widgets.Editors.Has_Document (Item) and then Word /= "";
   --  Make Word, another version of the word or phrase selected, the text there, as Reword does, so the word it
   --  was can be cycled back to. Nothing is done unless Thesaurus_State is One_Word.

   procedure Follow (Source : in out Pomarine.Widgets.Widget'Class);
   --  Open, in the system's way (the default browser, the mail program), the
   --  link Source, an editor, said it was Command-clicked on (Editors.Callbacks.On_Follow). Only the addresses
   --  a person can make (see Pomarine.Text_Areas.Is_Address) are opened, as
   --  what is loaded may say any.

end Word_Tools;
