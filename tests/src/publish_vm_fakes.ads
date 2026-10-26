with Long_Texts;
with Pomarine.Events;
with Publish_VM;

package Publish_VM_Fakes is
   type Platform is limited new Publish_VM.Effects with record
      Export_Ready, Copy_Ready, Accept_Copy : Boolean := True;
      Words, Board, Path : Long_Texts.Text;
      Time : Pomarine.Events.Milliseconds := 100;
      Copy_Delay : Pomarine.Events.Milliseconds := 0;
      State : Publish_VM.Export_States := Publish_VM.Cancelled;
      Requests, Results, Copies : Natural := 0;
   end record;
   overriding function Export_Available (Self : Platform) return Boolean is (Self.Export_Ready);
   overriding function Copy_Available (Self : Platform) return Boolean is (Self.Copy_Ready);
   overriding function Markdown_Text (Self : Platform) return String is (Long_Texts.To_String (Self.Words));
   overriding function Clock (Self : Platform) return Pomarine.Events.Milliseconds is (Self.Time);
   overriding procedure Ask_Export (Self : in out Platform);
   overriding procedure Export_Result
     (Self : in out Platform; State : out Publish_VM.Export_States; Path : out Long_Texts.Text);
   overriding procedure Copy_Text (Self : in out Platform; Words : String; Succeeded : out Boolean);

   type Store is limited new Publish_VM.Store with record
      Path, Words : Long_Texts.Text;
      Writes : Natural := 0;
      Fails : Boolean := False;
   end record;
   overriding procedure Save (Self : in out Store; Path, Words : String);
end Publish_VM_Fakes;
