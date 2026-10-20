--  Small questions and texts about a window, shared by the rest.
private package Items.Windows.Parts is

   function Status_Text (Number : Natural) return String;

   function Day (Taken : Projects.Seconds) return String;
   --  As 13 Oct 2026, in UTC.

   function Is_Unchosen (Item : Window) return Boolean;

   function Is_Text_Source (Item : Window) return Boolean;
   --  Whether the source is to say where it is from, or shows a text
   --  file: not a picture.

   function Is_Open_Source (Item : Window) return Boolean;

   function Across_Of (Item : Window) return Float;
   --  How far across it is scrolled: only a source's picture is.

   function Scroll_Of (Item : in out Window) return Float;
   --  How far the content is scrolled now (see Items.Info.Scroll).

   function Page_Status (Item : Window) return String;

   procedure Clear_Recognized (Item : in out Window);
   --  Forget the words, as of a picture that is not the one shown.

   function Shown_Marks_Version (Item : Window) return Natural;
   --  Of the widget shown, whatever the item is.

end Items.Windows.Parts;
