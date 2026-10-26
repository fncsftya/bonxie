with Menu_VM;
with Items.Sources;
with Ada.Assertions;
with Goldens;
with Items;
with Items.Models;
with Item_Window_VM;
with Reader_VM;
with Pomarine.View_Models;

package body Item_Control_VM_Tests is
   package Models renames Items.Models;
   package Windows renames Item_Window_VM;
   package Readers renames Reader_VM;
   use type Models.Tools;
   use type Windows.Command;
   use type Pomarine.View_Models.Version_Number;

   procedure Check (Name : String; Passed : Boolean) is
   begin
      Goldens.Check_Text (Name, "TRUE", Passed'Image);
   end Check;

   type Window_Effects is limited new Windows.Effects with record
      Last : Windows.Command := Windows.Capture;
      Index : Natural := 0;
      Requests, Changes : Natural := 0;
   end record;
   overriding procedure Changed (Self : in out Window_Effects);
   overriding procedure Requested (Self : in out Window_Effects; What : Windows.Command; Index : Natural) is
   begin
      Self.Last := What;
      Self.Index := Index;
      Self.Requests := Self.Requests + 1;
   end Requested;
   overriding procedure Changed (Self : in out Window_Effects) is
   begin
      Self.Changes := Self.Changes + 1;
   end Changed;

   procedure Window_Rules is
      Item : aliased Models.Item;
      View : aliased Window_Effects;
      Model : Windows.Model;
      Seen : Pomarine.View_Models.Version_Number;
      Rejected : Boolean := False;
   begin
      Check ("item-window-vm-uninitialized", not Windows.Can_Execute (Model, Windows.Capture));
      Windows.Initialize (Model, Item'Access, View'Access);
      Check ("item-window-vm-unassigned", not Windows.Can_Execute (Model, Windows.Choose_Link));
      Models.Assign (Item, (Key => 1, Kind => Items.Source, Origin => Items.Unchosen, others => <>), "");
      Windows.Poll (Model);
      Seen := Windows.Version (Model);
      Windows.Poll (Model);
      Check ("item-window-vm-no-change", Windows.Version (Model) = Seen);
      Check ("item-window-vm-source-commands", Windows.Can_Execute (Model, Windows.Choose_Link)
             and then Windows.Can_Execute (Model, Windows.Choose_File)
             and then not Windows.Can_Execute (Model, Windows.Speak)
             and then not Windows.Can_Execute (Model, Windows.Capture, 1));
      Windows.Execute (Model, Windows.Use_Marker);
      Check ("item-window-vm-selected", Models.Tool (Item) = Models.Highlighter
             and then Windows.Marker_Selected (Model) and then not Windows.Pointer_Selected (Model)
             and then View.Changes = 1 and then View.Requests = 0);
      Seen := Windows.Version (Model);
      Windows.Execute (Model, Windows.Use_Marker);
      Check ("item-window-vm-same-tool", Windows.Version (Model) = Seen);
      Windows.Execute (Model, Windows.Use_Eraser);
      Check ("item-window-vm-eraser", Windows.Eraser_Selected (Model));
      Models.Set_Pages (Item, "pdf", 1, 2);
      Check ("item-window-vm-page-first", not Windows.Previous_Allowed (Model) and then Windows.Next_Allowed (Model));
      Windows.Execute (Model, Windows.Next_Page);
      Check ("item-window-vm-page-effect", View.Last = Windows.Next_Page and then View.Index = 0);
      Models.Set_Pages (Item, "pdf", 2, 2);
      Check ("item-window-vm-page-last", Windows.Previous_Allowed (Model) and then not Windows.Next_Allowed (Model));
      Windows.Execute (Model, Windows.Zoom_Preset, 6);
      Check ("item-window-vm-preset", Models.Details (Item).Zoom = 2.0
             and then View.Last = Windows.Zoom_Preset and then View.Index = 6);
      Check ("item-window-vm-preset-range", not Windows.Can_Execute (Model, Windows.Zoom_Preset)
             and then not Windows.Can_Execute (Model, Windows.Zoom_Preset, 7));
      Models.Set_Origin (Item, Items.Remote);
      Check ("item-window-vm-remote-path", not Windows.Can_Execute (Model, Windows.Choose_File));
      Models.Set_Origin (Item, Items.Local);
      Check ("item-window-vm-local-path", Windows.Can_Execute (Model, Windows.Choose_File));
      Check ("item-window-vm-frame-open", Windows.Can_Execute (Model, Windows.Minimize_Window)
             and then Windows.Can_Execute (Model, Windows.Begin_Title_Edit)
             and then not Windows.Can_Execute (Model, Windows.Restore_Window));
      Models.Set_State (Item, Items.Minimized);
      Check ("item-window-vm-frame-minimized", Windows.Can_Execute (Model, Windows.Restore_Window)
             and then Windows.Can_Execute (Model, Windows.Close_Window)
             and then not Windows.Can_Execute (Model, Windows.Begin_Title_Edit));
      Windows.Execute (Model, Windows.Restore_Window);
      Check ("item-window-vm-restore-effect", View.Last = Windows.Restore_Window);
      Models.Set_State (Item, Items.Open);
      Windows.Set_Zoom_Fraction (Model, 0.5);
      Check ("item-window-vm-slider", Models.Details (Item).Zoom = Items.Sources.From_Slider (0.5));
      Models.Set_State (Item, Items.Closed);
      Check ("item-window-vm-closed-live", not Windows.Can_Execute (Model, Windows.Capture));
      Models.Release (Item);
      Check ("item-window-vm-released", not Windows.Can_Execute (Model, Windows.Use_Pointer));
      Models.Assign (Item, (Key => 2, Kind => Items.Note, others => <>), "");
      Windows.Poll (Model);
      Check ("item-window-vm-note", Windows.Can_Execute (Model, Windows.Speak)
             and then Windows.Can_Execute (Model, Windows.Link_To_Outline)
             and then not Windows.Can_Execute (Model, Windows.Use_Marker));
      Windows.Execute (Model, Windows.Speak);
      Check ("item-window-vm-speech-effect", View.Last = Windows.Speak);
      begin
         Windows.Execute (Model, Windows.Capture);
      exception
         when Ada.Assertions.Assertion_Error => Rejected := True;
      end;
      Check ("item-window-vm-contract", Rejected);
      Seen := Windows.Version (Model);
      Models.Release (Item);
      Models.Assign (Item, (Key => 3, Kind => Items.Note, others => <>), "");
      Windows.Poll (Model);
      Check ("item-window-vm-reused-identity", Windows.Version (Model) = Seen + 1);
   end Window_Rules;

   type Reading_Engine is limited new Readers.Engine with record
      Opened : Boolean := False;
      Selected : Models.Tools := Models.Pointer;
      Scale : Float := 1.0;
      Pins, Visits, Closes : Natural := 0;
   end record;
   overriding procedure Requested (Self : in out Reading_Engine; What : Readers.Command);
   overriding function Zoom (Self : Reading_Engine) return Float is (Self.Scale);
   overriding procedure Set_Zoom (Self : in out Reading_Engine; Value : Float);
   overriding function Is_Open (Self : Reading_Engine) return Boolean is (Self.Opened);
   overriding function Tool (Self : Reading_Engine) return Models.Tools is (Self.Selected);
   overriding procedure Select_Tool (Self : in out Reading_Engine; To : Models.Tools) is
   begin
      Self.Selected := To;
   end Select_Tool;
   overriding procedure Set_Zoom (Self : in out Reading_Engine; Value : Float) is
   begin
      Self.Scale := Value;
   end Set_Zoom;
   overriding procedure Requested (Self : in out Reading_Engine; What : Readers.Command) is
   begin
      case What is
         when Readers.Toggle_Pin => Self.Pins := Self.Pins + 1;
         when Readers.Close_Reader => Self.Closes := Self.Closes + 1;
         when Readers.Visit => Self.Visits := Self.Visits + 1;
         when others => raise Program_Error;
      end case;
   end Requested;

   procedure Reader_Rules is
      Engine : aliased Reading_Engine;
      Model : Readers.Model;
      Seen : Pomarine.View_Models.Version_Number;
      Rejected : Boolean := False;
   begin
      Check ("reader-vm-uninitialized", not Readers.Can_Execute (Model, Readers.Use_Marker));
      Readers.Initialize (Model, Engine'Access);
      Check ("reader-vm-closed", not Readers.Can_Execute (Model, Readers.Use_Marker));
      Engine.Opened := True;
      Readers.Poll (Model);
      Check ("reader-vm-open", Readers.Can_Execute (Model, Readers.Toggle_Pin)
             and then not Readers.Can_Execute (Model, Readers.Visit, 1));
      Seen := Readers.Version (Model);
      Readers.Poll (Model);
      Check ("reader-vm-no-change", Readers.Version (Model) = Seen);
      Readers.Execute (Model, Readers.Use_Marker);
      Check ("reader-vm-selected", Engine.Selected = Models.Highlighter
             and then Readers.Marker_Selected (Model) and then not Readers.Pointer_Selected (Model));
      Seen := Readers.Version (Model);
      Readers.Execute (Model, Readers.Use_Marker);
      Check ("reader-vm-same-tool", Readers.Version (Model) = Seen);
      Readers.Execute (Model, Readers.Use_Eraser);
      Check ("reader-vm-eraser", Readers.Eraser_Selected (Model));
      Readers.Execute (Model, Readers.Toggle_Pin);
      Readers.Execute (Model, Readers.Visit);
      Check ("reader-vm-effects", Engine.Pins = 1 and then Engine.Visits = 1);
      Engine.Selected := Models.Pointer;
      Readers.Poll (Model);
      Check ("reader-vm-external-tool", Readers.Pointer_Selected (Model));
      Readers.Execute (Model, Readers.Close_Reader);
      Readers.Set_Zoom_Fraction (Model, 0.75);
      Check ("reader-vm-slider-and-close", Engine.Scale = Items.Sources.From_Slider (0.75) and then Engine.Closes = 1);
      Engine.Opened := False;
      Readers.Set_Zoom_Fraction (Model, 0.0);
      Check ("reader-vm-closed-slider", Engine.Scale = Items.Sources.From_Slider (0.75));
      Check ("reader-vm-closed-live", not Readers.Can_Execute (Model, Readers.Visit));
      begin
         Readers.Execute (Model, Readers.Visit);
      exception
         when Ada.Assertions.Assertion_Error => Rejected := True;
      end;
      Check ("reader-vm-contract", Rejected and then Engine.Visits = 1);
   end Reader_Rules;
   type Menu_Router is limited new Menu_VM.Router with record
      Rows : Natural := 2;
      Disabled : Natural := 0;
      Last : Natural := 0;
      Which : Menu_VM.Command := Menu_VM.Source_Menu;
   end record;
   overriding function Allowed (Self : Menu_Router; What : Menu_VM.Command; Row : Natural) return Boolean is
     (Row in 1 .. Self.Rows and then Row /= Self.Disabled);
   overriding procedure Choose (Self : in out Menu_Router; What : Menu_VM.Command; Row : Positive) is
   begin
      Self.Last := Row;
      Self.Which := What;
   end Choose;

   procedure Menu_Rules is
      use type Menu_VM.Command;
      Target : aliased Menu_Router;
      Model : Menu_VM.Model;
      Rejected : Boolean := False;
   begin
      Check ("menu-vm-uninitialized", not Menu_VM.Can_Execute (Model, Menu_VM.Source_Menu, 1));
      Menu_VM.Initialize (Model, Target'Access);
      Check ("menu-vm-row-range", Menu_VM.Can_Execute (Model, Menu_VM.Source_Menu, 2)
             and then not Menu_VM.Can_Execute (Model, Menu_VM.Source_Menu)
             and then not Menu_VM.Can_Execute (Model, Menu_VM.Source_Menu, 3));
      Target.Disabled := 2;
      Check ("menu-vm-live-availability", not Menu_VM.Can_Execute (Model, Menu_VM.Context_Menu, 2));
      begin
         Menu_VM.Execute (Model, Menu_VM.Context_Menu, 2);
      exception
         when Ada.Assertions.Assertion_Error => Rejected := True;
      end;
      Check ("menu-vm-contract", Rejected and then Target.Last = 0);
      Target.Rows := 3;
      for What in Menu_VM.Command loop
         Menu_VM.Execute (Model, What, 3);
         Check ("menu-vm-route-" & What'Image, Target.Last = 3 and then Target.Which = What);
      end loop;
   end Menu_Rules;
end Item_Control_VM_Tests;
