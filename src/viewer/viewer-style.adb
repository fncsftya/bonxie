package body Viewer.Style is

   procedure Use_Dark (Dark : Boolean) is
   begin
      Active := (if Dark then Pomarine.Themes.Dark else Pomarine.Themes.Light);
   end Use_Dark;

end Viewer.Style;
