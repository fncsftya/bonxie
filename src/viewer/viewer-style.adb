package body Viewer.Style is

   procedure Use_Dark (Dark : Boolean) is
   begin
      Active := (if Dark then UI.Themes.Dark else UI.Themes.Light);
   end Use_Dark;

end Viewer.Style;
