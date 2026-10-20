--  Taking the picture of a link or a file, and showing how far it has come.
private package Items.Windows.Fetching is

   procedure Apply_Pages
     (Item : in out Window; Document : String; Page, Count : Natural)
     with Pre => Is_Assigned (Item)
                 and then Details (Item).Kind = Source
                 and then Page <= Count,
          Post => Details (Item).Page = Page
                  and then Details (Item).Page_Count = Count;
   --  Say the source's picture is of the Page'th of the Count pages of its
   --  document, a file of that ending ("" and 0 for a web page): with more than one, buttons
   --  to turn the page are over the picture, and the status line says
   --  which it is once it is shown (Set_Capture Ready).

   procedure Apply_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0)
     with Pre => Is_Assigned (Item)
                 and then Details (Item).Kind = Source
                 and then (To /= Ready or else File /= "");
   --  Say how the source's picture stands, in its status line: Ready
   --  shows the PNG File, read again, as taken at At_Time; Failed says
   --  why, in Detail.

   procedure Apply_Origin (Item : in out Window; To : Items.Origins)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source,
          Post => Details (Item).Origin = To;
   --  Say whether the source is yet to be said to be a link or a file
   --  (it shows two buttons to say so), a link, or a file (its path is
   --  its text, which cannot be typed over, and clicked asks for another).

end Items.Windows.Fetching;
