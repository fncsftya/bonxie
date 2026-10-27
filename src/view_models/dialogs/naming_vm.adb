package body Naming_VM is

   function Directory (Self : Model) return Natural
   is (Self.Folder);

   function Document (Self : Model) return Natural
   is (Self.Doc);

   function Source (Self : Model) return Natural
   is (Self.Origin);

   procedure Begin_Directory (Self : in out Model; Which : Positive) is
   begin
      Self.Folder := Which;
   end Begin_Directory;

   procedure Begin_Document (Self : in out Model; Which : Items.Slot) is
   begin
      Self.Doc := Which;
   end Begin_Document;

   procedure Begin_Source (Self : in out Model; Which : Items.Slot) is
   begin
      Self.Origin := Which;
   end Begin_Source;

   procedure End_Directory (Self : in out Model) is
   begin
      Self.Folder := 0;
   end End_Directory;

   procedure End_Document (Self : in out Model) is
   begin
      Self.Doc := 0;
   end End_Document;

   procedure End_Source (Self : in out Model) is
   begin
      Self.Origin := 0;
   end End_Source;

   function Is_Titling (Self : Model; Rank : Positive) return Boolean
   is (Rank <= Self.Titles.Count and then Self.Titles (Rank));

   procedure Begin_Title (Self : in out Model; Rank : Positive) is
   begin
      if Rank > Self.Titles.Count then
         Self.Titles.Resize (Rank, False);
      end if;
      Self.Titles (Rank) := True;
   end Begin_Title;

   procedure End_Title (Self : in out Model; Rank : Positive) is
   begin
      if Rank <= Self.Titles.Count then
         Self.Titles (Rank) := False;
      end if;
   end End_Title;

   procedure Reset (Self : in out Model) is
   begin
      Self.Folder := 0;
      Self.Doc := 0;
      Self.Origin := 0;
   end Reset;

end Naming_VM;
