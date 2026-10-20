--  Dictating into a window's text.
private package Items.Windows.Speaking is

   procedure Change
     (Item   : in out Window;
      To     : Dictations;
      Detail : String := "")
     with Pre  => Is_Assigned (Item) and then Details (Item).Kind = Note,
          Post => Dictation (Item) = To;
   --  Say how dictating stands: the button is a stop button while it is
   --  Preparing or Listening, and the status line says what is going on
   --  (a Failed one says why, in Detail, until the text is next
   --  changed).

   procedure Show_Level (Item : in out Window; To : Float)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note
                 and then To in 0.0 .. 1.0;
   --  Say how loud what is heard is, while Listening: shown as a bar
   --  along the foot of the status line, filled to that far.

   procedure Show_Live (Item : in out Window; Said : String; Settled : Natural := 0)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note;
   --  Show what has been heard so far, while Listening, in the note's
   --  text, where Add_Dictation will put it: each call replaces the last
   --  Said. These edits are not recorded (they cannot be undone), and
   --  Add_Dictation, or a failure, takes them back before the final text
   --  goes in. If the text is changed by anything else while it is
   --  shown, it is left as it is, and no more is shown. The first Settled
   --  bytes of Said are drawn as text; the rest, which may yet change,
   --  faintly.

   procedure Append_Said (Item : in out Window; Said : String)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note;
   --  Put Said in the note's text, as one edit, to be undone together.
   --  If the text is focused, it goes in at the caret (what is selected
   --  is kept); if it has none yet, it is the text; otherwise it is a
   --  new paragraph after the last.

end Items.Windows.Speaking;
