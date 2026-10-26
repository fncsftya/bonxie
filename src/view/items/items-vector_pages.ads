with Pomarine.Pages;
with Pomarine.Words;
with Pomarine.Widgets.Page_Views;

--  A PDF shown in a Page_View as all its pages, one under another, drawn
--  from what is on them (see Pomarine.Pages) so that they are sharp at any
--  zoom, with the PDF's own text to select. The pages are made, by Ebook,
--  as they come into view.
package Items.Vector_Pages is

   use type Pomarine.Pages.Size_Array_Access;

   type File_Source is limited new Pomarine.Pages.Source with private;
   --  Makes the pages of one file.

   procedure Open
     (Shown   : in out Pomarine.Widgets.Page_Views.Page_View;
      Sizes   : in out Pomarine.Pages.Size_Array_Access;
      Origin  : aliased in out File_Source;
      File    : String;
      Count   : Positive;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'Length >= 160;
   --  Show the first Count pages of the PDF File in Shown. Sizes and Origin
   --  are kept as long as it is shown (see Close). They are shown at once, as
   --  of a guessed size, and Shown is told their sizes when the document has
   --  been opened, in the background. If the path is too long, Last >=
   --  Message'First and Message says why; otherwise Last is Message'First - 1.

   procedure Close
     (Shown : in out Pomarine.Widgets.Page_Views.Page_View;
      Sizes : in out Pomarine.Pages.Size_Array_Access)
     with Post => Sizes = null;
   --  Show no document, and give back what Open made.

private

   Path_Capacity : constant := 1024;

   type File_Source is limited new Pomarine.Pages.Source with record
      Name   : String (1 .. Path_Capacity) := [others => ' '];
      Length : Natural range 0 .. Path_Capacity := 0;
   end record;

   overriding procedure Measure
     (Item  : in out File_Source;
      Count : Positive;
      Sizes : out Pomarine.Pages.Size_Array_Access;
      Ok    : out Boolean);

   overriding procedure Build
     (Item    : in out File_Source;
      Index   : Positive;
      Content : out Pomarine.Pages.Page_Access;
      Found   : in out Pomarine.Words.Result;
      Ok      : out Boolean);

end Items.Vector_Pages;
