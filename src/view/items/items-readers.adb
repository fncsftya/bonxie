with Pomarine.Marks;
with Reader_UI;
with Items.Sources;
with Pomarine.Line_Texts;
with Pomarine.Text_Areas;
with Icon_Set;
with Pomarine.Widgets.Frames.Handlers;
with Pomarine.Widgets.Layouts;
with Pomarine.UI;
with Pomarine.Icons;

package body Items.Readers is

   package Widgets renames Pomarine.Widgets;
   package UI renames Pomarine.UI;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Frames renames Pomarine.Widgets.Frames;
   package Sliders renames Pomarine.Widgets.Sliders;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Views renames Pomarine.Widgets.Page_Views;
   package Editors renames Pomarine.Widgets.Editors;
   package Docs renames Texts.Documents;

   overriding function Is_Open (Self : Control_Engine) return Boolean is
     (Self.Owner.Assigned and then Self.Owner.Details.State = Open);

   overriding function Tool (Self : Control_Engine) return Items.Models.Tools is
     (if not Self.Owner.Assigned then Items.Models.Pointer
      elsif Tool (Self.Owner.all) = Pictures.Highlighter then Items.Models.Highlighter
      elsif Tool (Self.Owner.all) = Pictures.Eraser then Items.Models.Eraser
      else Items.Models.Pointer);

   overriding procedure Select_Tool (Self : in out Control_Engine; To : Items.Models.Tools) is
   begin
      Select_Tool (Self.Owner.all,
                   (case To is
                       when Items.Models.Pointer => Pictures.Pointer,
                       when Items.Models.Highlighter => Pictures.Highlighter,
                       when Items.Models.Eraser => Pictures.Eraser));
   end Select_Tool;

   procedure Say (Item : in out Reader; Action : Actions);

   overriding function Zoom (Self : Control_Engine) return Float is (Self.Owner.Details.Zoom);

   overriding procedure Set_Zoom (Self : in out Control_Engine; Value : Float) is
   begin
      Set_Zoom (Self.Owner.all, Value);
   end Set_Zoom;

   overriding procedure Requested (Self : in out Control_Engine; What : Reader_VM.Command) is
   begin
      case What is
         when Reader_VM.Toggle_Pin => Say (Self.Owner.all, Toggle_Pin);
         when Reader_VM.Close_Reader => Say (Self.Owner.all, Close);
         when Reader_VM.Visit => Say (Self.Owner.all, Visit);
         when others => raise Program_Error with "tool commands are handled by the reading engine";
      end case;
   end Requested;

   function Is_Texty (Item : Reader) return Boolean is
     (Item.Details.Origin /= Unchosen
      and then Items.Sources.Is_Text (Items.Extensions.To_String (Item.Details.Document)));
   --  Whether the source is shown as text, not as a picture.

   procedure Show_Mode (Item : in out Reader);
   --  Show the text of a text file, or the picture and its tools.

   --  In points

   Button_Size   : constant Float := Frames.Button_Size;
   Button_Gap    : constant Float := Frames.Button_Gap;
   Label_Height  : constant Float := Frames.Label_Height;
   Row_Height    : constant Float := 19.0;
   Slider_Width  : constant Float := 72.0;
   Percent_Width : constant Float := 40.0;
   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;
   Pin_Icon_Size : constant Float := 12.0;
   Text_Size     : constant Float := 15.0;
   Visit_Width   : constant Float := 84.0;

   procedure Listen (Item : in out Reader);
   --  Give the reader's widgets the procedures they call (see Update).

   procedure Build
     (Item    : in out Reader;
      Parent  : in out Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float;
      Pinned  : Boolean := False)
   is
      Pixels : constant Float := Density;
   begin
      Item.Pixels := Pixels;
      Item.Pinned := Pinned;
      Frames.Build
        (Item.Chrome, Parent, Bar, Pixels,
         Placement => (if Pinned then Frames.Filling else Frames.Floating));
      Buttons.Configure
        (Item.Pin_Button,
         Buttons.Looks
           ("Pin",
            Icon => Pomarine.Icons.Shown (Icon_Set.Pin),
            Icon_Points => Pin_Icon_Size));
      Buttons.Set_Selected (Item.Pin_Button, Pinned);

      Buttons.Set_Label (Item.Visit_Button, "Visit Source");
      Item.Control_Source.Owner := Item'Unrestricted_Access;
      Reader_VM.Initialize (Item.Controls, Item.Control_Source'Access);
      Item.UI_Host.Open (Parent);
      declare
         Screen : UI.View renames Item.UI_Host.Screen.all;
         Bound : constant Reader_UI.Controls.Context'Class := Reader_UI.Controls.Bind (Screen, Item.Controls'Access);

         function Put (Part : in out Widgets.Widget'Class; Wide, High : Float) return UI.Layout is
           (UI.Styled (UI.Put (Screen, Part), (Width => Wide, Height => High, others => <>)));

         function Tool
           (Part : in out Buttons.Button; What : Reader_VM.Command; Caption : String; Icon : Pomarine.Icons.Optional)
           return UI.Layout is
         begin
            Buttons.Configure (Part, Buttons.Looks (Caption, Icon => Icon));
            declare
               Handle : constant UI.Button_Handle := Bound.Borrow_Button (Part, What, Reflect => False);
            begin
               case What is
                  when Reader_VM.Use_Pointer => Bound.Selected_When (Handle, Reader_UI.Pointer_Flag.Property);
                  when Reader_VM.Use_Marker => Bound.Selected_When (Handle, Reader_UI.Marker_Flag.Property);
                  when Reader_VM.Use_Eraser => Bound.Selected_When (Handle, Reader_UI.Eraser_Flag.Property);
                  when others => null;
               end case;
               return UI.Styled (UI.Place (Handle), (Width => Button_Size, Height => Row_Height, others => <>));
            end;
         end Tool;

         Cursor : constant UI.Layout :=
           Tool (Item.Cursor_Button, Reader_VM.Use_Pointer, "Ptr", Pomarine.Icons.Shown (Icon_Set.Cursor));
         Marker : constant UI.Layout :=
           Tool (Item.Marker_Button, Reader_VM.Use_Marker, "Mark", Pomarine.Icons.Shown (Icon_Set.Highlighter));
         Eraser : constant UI.Layout :=
           Tool (Item.Eraser_Button, Reader_VM.Use_Eraser, "Rub", Pomarine.Icons.Shown (Icon_Set.Eraser));
         Tools  : constant UI.Layout := UI.Styled
           (UI.Put_In (Screen, Item.Tools, [Cursor, Marker, Eraser], Flow => Layouts.Row, Gap => Button_Gap),
            (Width => Tools_Width, Height => Row_Height, Gap => Button_Gap, others => <>));
         Content : constant UI.Layout := UI.Fragment
           (Screen, [UI.Styled (UI.Put (Screen, Item.Picture), (Grow => 1.0, Height => 0.0, others => <>)),
                     UI.Styled (UI.Put (Screen, Item.Pages), (Grow => 1.0, Height => 0.0, others => <>)),
                     UI.Styled (UI.Put (Screen, Item.Text_View), (Grow => 1.0, Height => 0.0, others => <>))]);
         Zoom_Control : constant UI.Widget_Handle :=
           Bound.Borrow_Slider (Item.Zoom_Slider, Reader_UI.Zoom_Value.Property);
         Visit_Control : constant UI.Button_Handle :=
           Bound.Borrow_Button (Item.Visit_Button, Reader_VM.Visit, Reflect => False);
         Status : constant UI.Layout := UI.Fragment
           (Screen, [Tools,
                     UI.Styled (UI.Place (Zoom_Control),
                                (Width => Slider_Width, Height => Row_Height, others => <>)),
                     Put (Item.Zoom_Label, Percent_Width, Label_Height),
                     UI.Styled (UI.Put (Screen, Item.Status),
                                (Grow => 1.0, Width => 0.0, Height => Label_Height, others => <>)),
                     UI.Styled (UI.Place (Visit_Control), (Width => Visit_Width, Height => Row_Height, others => <>))]);
         Pin_Control : constant UI.Button_Handle :=
           Bound.Borrow_Button (Item.Pin_Button, Reader_VM.Toggle_Pin, Reflect => False);
         Pin : constant UI.Layout :=
           UI.Styled (UI.Place (Pin_Control), (Width => Button_Size, Height => Button_Size, others => <>));
      begin
         Bound.On_Frame_Event (Item.Chrome, Widgets.Close, Reader_VM.Close_Reader);
         UI.Mount_Before (Screen, Frames.Title_End (Item.Chrome).all, Pin);
         UI.Mount_Before (Screen, Frames.Content_End (Item.Chrome).all, Content);
         UI.Mount_Before (Screen, Frames.Status_End (Item.Chrome).all, Status);
      end;
      Editors.Configure
        (Item.Text_View, Pomarine.Line_Texts.Serif, Text_Size, 2000.0);
      Editors.Set_Paper (Item.Text_View, Pomarine.Themes.Page);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Text_View).all);
      Widgets.Set_Visible (Item.Text_View, False);

      Widgets.Set_Visible (Item.Visit_Button, False);
      Listen (Item);
   end Build;

   function Is_Assigned (Item : Reader) return Boolean is (Item.Assigned);

   procedure Set_Tag (Item : in out Reader; To : Pomarine.Themes.Slot) is
   begin
      Frames.Set_Tag (Item.Chrome, To);
   end Set_Tag;

   function Details (Item : Reader) return Items.Info is (Item.Details);

   function Recognized_Count (Item : Reader) return Natural is
     (if Item.Paged then Views.Word_Count (Item.Pages) else Item.Recognized.Count);

   function Selected_Text (Item : Reader) return String is
     (if Item.Paged then Views.Selected_Text (Item.Pages)
      else Pictures.Selected_Text (Item.Picture));

   function Marks_Version (Item : Reader) return Natural is
     (if Item.Paged then Views.Marks_Version (Item.Pages)
      else Pictures.Marks_Version (Item.Picture));

   function Is_Marking (Item : Reader) return Boolean is
     (if Item.Paged then Views.Is_Marking (Item.Pages)
      else Pictures.Is_Marking (Item.Picture));

   function Tool (Item : Reader) return Pictures.Tools is
     (if Item.Paged then Views.Tool (Item.Pages) else Pictures.Tool (Item.Picture));

   function Zoom (Item : Reader) return Float is (Item.Details.Zoom);

   function Picture_Contains
     (Item : Reader; X, Y : Float) return Boolean is
     (if Item.Paged then Widgets.Contains (Item.Pages, X, Y)
      else Widgets.Contains (Item.Picture, X, Y));

   function Is_Over_Selection
     (Item : Reader; X, Y : Float) return Boolean is
     (if Item.Paged then Views.Is_Over_Selection (Item.Pages, X, Y)
      else Pictures.Is_Over_Selection (Item.Picture, X, Y));

   function Has_Words (Item : Reader) return Boolean is
     (if Item.Paged then Views.Has_Words (Item.Pages) else Pictures.Has_Words (Item.Picture));

   procedure Select_All (Item : in out Reader) is
   begin
      if Item.Paged then
         Views.Select_All (Item.Pages);
      else
         Pictures.Select_All (Item.Picture);
      end if;
   end Select_All;

   procedure Copy (Item : Reader) is
   begin
      if Item.Paged then
         Views.Copy (Item.Pages);
      else
         Pictures.Copy (Item.Picture);
      end if;
   end Copy;

   function Box (Item : Reader) return Items.Frame is
     ((Left   => Frames.Left_Of (Item.Chrome),
       Top    => Frames.Top_Of (Item.Chrome),
       Width  => Frames.Width_Of (Item.Chrome),
       Height => Frames.Height_Of (Item.Chrome)));

   procedure Get_Marks (Item : Reader; Into : out Items.Marks.Mark_List) is
   begin
      Into.Past := (if Item.Paged then Views.History_Of (Item.Pages)
                    else Pictures.History_Of (Item.Picture));
      if Item.Paged then
         Into.Count := Views.Mark_Count (Item.Pages);
         Pomarine.Marks.Reserve (Into.Marks, Into.Count);
         for Index in 1 .. Into.Count loop
            declare
               Each : constant Views.Mark := Views.Mark_At (Item.Pages, Index);
            begin
               Into.Marks.Data (Index) :=
                 (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => Each.Page, Trace => Each.Trace);
            end;
         end loop;
         return;
      end if;
      Into.Count := Pictures.Mark_Count (Item.Picture);
      Pomarine.Marks.Reserve (Into.Marks, Into.Count);
      for Index in 1 .. Into.Count loop
         declare
            Each : constant Pictures.Mark :=
              Pictures.Mark_At (Item.Picture, Index);
         begin
            Into.Marks.Data (Index) :=
              (Left => Each.Left, Right => Each.Right, Y => Each.Y, Page => 1, Trace => Each.Trace);
         end;
      end loop;
   end Get_Marks;

   procedure Set_Marks (Item : in out Reader; Kept : Items.Marks.Mark_List) is
      Shown : Pictures.Mark_Array (1 .. Kept.Count);
      Paged : Views.Mark_Array (1 .. Kept.Count);
   begin
      for Index in Shown'Range loop
         declare
            Each : Items.Marks.Mark renames Kept.Marks.Data (Index);
         begin
            Shown (Index) :=
              Pictures.Clamped_Mark
                (Each.Left, Each.Right, Each.Y);
            Shown (Index).Trace := Each.Trace;
            Paged (Index) := Views.Clamped_Mark (Each.Left, Each.Right, Each.Y, Each.Page);
            Paged (Index).Trace := Each.Trace;
         end;
      end loop;
      Pictures.Set_Marks (Item.Picture, Shown, Kept.Past);
      Views.Set_Marks (Item.Pages, Paged, Kept.Past);
   end Set_Marks;

   procedure Select_Tool (Item : in out Reader; To : Pictures.Tools) is
   begin
      Pictures.Set_Tool (Item.Picture, To);
      Views.Set_Tool (Item.Pages, To);
      Reader_VM.Poll (Item.Controls);
      Pomarine.UI.Synchronize (Item.UI_Host.Screen.all);
   end Select_Tool;

   procedure Set_Zoom (Item : in out Reader; To : Float) is
   begin
      Item.Details.Zoom := To;
      Pictures.Set_Zoom (Item.Picture, To);
      Views.Set_Zoom (Item.Pages, To);
      Labels.Set_Text (Item.Zoom_Label, Items.Sources.Percent (To));
      Reader_VM.Poll (Item.Controls);
      Pomarine.UI.Synchronize (Item.UI_Host.Screen.all);
   end Set_Zoom;

   procedure Set_Title (Item : in out Reader; To : String) is
   begin
      Item.Details.Title := Projects.Titles.To_Text
        (To);
      Frames.Set_Title (Item.Chrome, To);
   end Set_Title;

   procedure Show_Status (Item : in out Reader);
   --  Say whether there is a picture to show.

   procedure Show_Status (Item : in out Reader) is
   begin
      Labels.Set_Text
        (Item.Status,
         (if Item.Details.Captured_At = 0 then "Not captured yet"
          elsif Item.Details.Page_Count > 0
          then "Page" & Item.Details.Page'Image & " of" & Item.Details.Page_Count'Image
          else ""));
   end Show_Status;

   procedure Show_Mode (Item : in out Reader) is
      Texty : constant Boolean := Is_Texty (Item);
   begin
      Widgets.Set_Visible (Item.Text_View, Texty);
      Widgets.Set_Visible (Item.Picture, not Texty and then not Item.Paged);
      Widgets.Set_Visible (Item.Pages, not Texty and then Item.Paged);
      Widgets.Set_Visible (Item.Tools, not Texty);
      Widgets.Set_Visible (Item.Zoom_Slider, not Texty);
      Widgets.Set_Visible (Item.Zoom_Label, not Texty);
   end Show_Mode;

   procedure Set_Document
     (Item : in out Reader; Document : String; Page, Count : Natural) is
   begin
      Item.Details.Document :=
        Items.Extensions.To_Text (Document);
      Item.Details.Page := Page;
      Item.Details.Page_Count := Count;
      Show_Mode (Item);
      Show_Status (Item);
   end Set_Document;

   procedure Clear_Recognized (Item : in out Reader);
   --  Forget the words, as of a picture that is not the one shown.

   procedure Clear_Recognized (Item : in out Reader) is
   begin
      Pictures.Set_Words (Item.Picture, null);
      Item.Recognized.Count := 0;
      Item.Recognized.Length := 0;
      Item.Recognized.Truncated := False;
   end Clear_Recognized;

   procedure Set_Recognized
     (Item : in out Reader; Found : Vision.Result) is
   begin
      Item.Recognized := Found;
      Pictures.Set_Words (Item.Picture, Item.Recognized'Unchecked_Access);
   end Set_Recognized;

   procedure Go_To_Page (Item : in out Reader; Page : Positive) is
   begin
      if Item.Paged and then Page <= Views.Page_Count (Item.Pages) then
         Views.Show_Page (Item.Pages, Page);
      end if;
   end Go_To_Page;

   procedure Follow_Page (Item : in out Reader) is
      Now : constant Natural :=
        (if Item.Paged and then Views.Is_Settled (Item.Pages)
         then Views.Current_Page (Item.Pages) else 0);
   begin
      if Now > 0 and then Now /= Item.Details.Page then
         Item.Details.Page := Now;
         Show_Status (Item);
      end if;
   end Follow_Page;

   procedure Show_Picture (Item : in out Reader; File : String);
   --  Show the page or picture File, as the source's document is.

   procedure Show_Picture (Item : in out Reader; File : String) is
   begin
      if Item.Details.Page > 0
        and then Items.Sources.Is_Vector (Items.Extensions.To_String (Item.Details.Document))
      then
         declare
            Message : String (1 .. 160);
            Last    : Natural;
         begin
            Items.Vector_Pages.Open
              (Item.Pages, Item.Doc_Sizes, Item.Doc_Source, File,
               Item.Details.Page_Count, Message, Last);
            Item.Paged := Last < Message'First;
            Pictures.Set_File (Item.Picture, "");
            if Item.Paged then
               Views.Show_Page (Item.Pages, Item.Details.Page);
            end if;
         end;
      else
         Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
         Item.Paged := False;
         Pictures.Set_File (Item.Picture, File);
      end if;
   end Show_Picture;

   procedure Set_Picture
     (Item : in out Reader; File : String; At_Time : Projects.Seconds) is
   begin
      Item.Details.Captured_At := At_Time;
      Clear_Recognized (Item);
      Pictures.Clear_Marks (Item.Picture);
      if Is_Texty (Item) then
         Pictures.Set_File (Item.Picture, "");
         Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
         Item.Paged := False;
         Docs.Load (Item.Text_Doc, Items.Sources.Read_Text (File));
      else
         Show_Picture (Item, File);
      end if;
      Show_Mode (Item);
      Show_Status (Item);
      if Item.Details.State = Open and then not Is_Texty (Item) then
         Pictures.Load_Soon (Item.Picture, Urgent => True);
      end if;
   end Set_Picture;

   procedure Set_State (Item : in out Reader; To : States) is
   begin
      Item.Details.State := To;
      if To /= Open then
         Select_Tool (Item, Pictures.Pointer);
         Pictures.Unload (Item.Picture);
         Views.Unload (Item.Pages);
      else
         Pictures.Load_Soon (Item.Picture, Urgent => True);
      end if;
      Frames.Set_Shown (Item.Chrome, To = Open, False);
      Item.Was_Used := False;
      Reader_VM.Poll (Item.Controls);
      Pomarine.UI.Synchronize (Item.UI_Host.Screen.all);
   end Set_State;

   procedure Assign
     (Item         : in out Reader;
      Of_Item      : Items.Info;
      Where        : Items.Frame;
      Picture_File : String := "") is
   begin
      Item.Assigned := True;
      Item.Details := Of_Item;
      Item.Details.Where := Items.Sized
        ((Where with delta
            Width  => Float'Max (Least_Width, Where.Width),
            Height => Float'Max (Least_Height, Where.Height)));
      Item.Details.State := Closed;
      Item.Details.Scroll := 0.0;
      Item.Details.Scroll_Across := 0.0;
      Item.Resizing := False;
      Set_Title (Item, Projects.Titles.To_String (Of_Item.Title));
      Clear_Recognized (Item);
      Pictures.Clear_Marks (Item.Picture);
      Views.Clear_Marks (Item.Pages);
      Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Select_Tool (Item, Pictures.Pointer);
      Set_Zoom (Item, Of_Item.Zoom);
      Docs.Load (Item.Text_Doc, "");
      Editors.Attach (Item.Text_View, Item.Text_Doc'Unchecked_Access);
      if Of_Item.Captured_At > 0 and then Picture_File /= "" then
         if Is_Texty (Item) then
            Docs.Load (Item.Text_Doc, Items.Sources.Read_Text (Picture_File));
         else
            Show_Picture (Item, Picture_File);
         end if;
      end if;
      Show_Mode (Item);
      Show_Status (Item);
      Set_State (Item, Closed);
   end Assign;

   procedure Set_Pinnable (Item : in out Reader; To : Boolean) is
   begin
      Pomarine.Widgets.Set_Visible (Item.Pin_Button, To);
   end Set_Pinnable;

   procedure Set_Visitable (Item : in out Reader; To : Boolean) is
   begin
      Pomarine.Widgets.Set_Visible (Item.Visit_Button, To);
   end Set_Visitable;

   procedure Release (Item : in out Reader) is
   begin
      Clear_Recognized (Item);
      Pictures.Set_File (Item.Picture, "");
      Items.Vector_Pages.Close (Item.Pages, Item.Doc_Sizes);
      Item.Paged := False;
      Pictures.Unload (Item.Picture);
      Frames.Set_Shown (Item.Chrome, False, False);
      Item.Assigned := False;
      Item.Was_Used := False;
      Reader_VM.Poll (Item.Controls);
      Pomarine.UI.Synchronize (Item.UI_Host.Screen.all);
   end Release;

   procedure Place (Item : in out Reader) is
      Where  : Items.Frame renames Item.Details.Where;
      Pixels : constant Float := Frames.Pixels_Per_Point (Item.Chrome);
   begin
      if Item.Pinned then
         return;
      end if;
      --  On whole pixels, so that its edges, and the borders in them, are
      --  the same wherever it is.
      Frames.Place
        (Item.Chrome,
         Float'Rounding (Where.Left * Pixels),
         Float'Rounding (Where.Top * Pixels),
         Float'Rounding (Where.Width * Pixels),
         Float'Rounding (Where.Height * Pixels));
   end Place;

   procedure Set_Frame (Item : in out Reader; Where : Items.Frame) is
   begin
      Item.Details.Where := Items.Sized
        ((Where with delta
            Width  => Float'Max (Least_Width, Where.Width),
            Height => Float'Max (Least_Height, Where.Height)));
      Place (Item);
   end Set_Frame;

   procedure Bring_To_Front (Item : in out Reader) is
   begin
      Frames.Raise_To_Front (Item.Chrome);
   end Bring_To_Front;

   function Is_Dragging (Item : Reader) return Boolean is
     (Frames.Is_Dragging (Item.Chrome));

   package Frame_Hooks is new Pomarine.Widgets.Frames.Handlers (Reader);

   subtype Source_Widget is Widgets.Widget'Class;

   procedure Say (Item : in out Reader; Action : Actions) is
   begin
      if Item.Said /= null then
         Item.Said (Item.Said_Self, Item.Said_Proc, Item.Said_Which, Action);
      end if;
   end Say;

   procedure Moved
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The title bar was dragged, in points: move it, but not while pinned.

   procedure Moved
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if not Item.Pinned then
         Item.Details.Where.Left := Item.Details.Where.Left + Event.Across;
         Item.Details.Where.Top := Item.Details.Where.Top + Event.Down;
         Place (Item);
      end if;
   end Moved;

   procedure Sized
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event);
   --  The corner was dragged, in points: size it, but not under the least.

   procedure Sized
     (Item : in out Reader; From : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Item.Raw_Width := Item.Raw_Width + Event.Across;
      Item.Raw_Height := Item.Raw_Height + Event.Down;
      Item.Details.Where := Items.Sized
        ((Item.Details.Where with delta
            Width  => Float'Max (Least_Width, Item.Raw_Width),
            Height => Float'Max (Least_Height, Item.Raw_Height)));
      Place (Item);
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);
   end Sized;

   procedure Listen (Item : in out Reader) is
      use all type Widgets.Event_Kind;
   begin
      Frame_Hooks.On (Item.Chrome, Move, Item'Unrestricted_Access, Moved'Access);
      Frame_Hooks.On (Item.Chrome, Resize, Item'Unrestricted_Access, Sized'Access);
   end Listen;

   procedure Update (Item : in out Reader) is
      Used : Boolean;
   begin
      --  What is moved and sized is the handlers' (see Listen); here only
      --  the size the corner asks for, which is the size it has while it
      --  is not being dragged.
      if not Item.Resizing then
         Item.Raw_Width := Item.Details.Where.Width;
         Item.Raw_Height := Item.Details.Where.Height;
      end if;
      Item.Resizing := Frames.Is_Sizing (Item.Chrome);

      --  Raised when it starts to be used.
      Used := Is_Dragging (Item)
              or else Sliders.Is_Dragging (Item.Zoom_Slider);
      if Used and then not Item.Was_Used and then Item.Details.State = Open
      then
         Frames.Raise_To_Front (Item.Chrome);
      end if;
      Item.Was_Used := Used;
   end Update;

end Items.Readers;
