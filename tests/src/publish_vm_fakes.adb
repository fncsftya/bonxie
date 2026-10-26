package body Publish_VM_Fakes is
   use type Pomarine.Events.Milliseconds;
   overriding procedure Ask_Export (Self : in out Platform) is
   begin
      Self.Requests := @ + 1;
      Self.State := Publish_VM.Waiting;
   end Ask_Export;

   overriding procedure Export_Result
     (Self : in out Platform; State : out Publish_VM.Export_States; Path : out Long_Texts.Text) is
   begin
      Self.Results := @ + 1;
      State := Self.State;
      Path := Self.Path;
   end Export_Result;

   overriding procedure Copy_Text (Self : in out Platform; Words : String; Succeeded : out Boolean) is
   begin
      Self.Copies := @ + 1;
      Self.Time := @ + Self.Copy_Delay;
      Succeeded := Self.Accept_Copy;
      if Succeeded then
         Self.Board := Long_Texts.To_Text (Words);
      end if;
   end Copy_Text;

   overriding procedure Save (Self : in out Store; Path, Words : String) is
   begin
      Self.Writes := @ + 1;
      if Self.Fails then
         raise Program_Error with "write failed";
      end if;
      Self.Path := Long_Texts.To_Text (Path);
      Self.Words := Long_Texts.To_Text (Words);
   end Save;
end Publish_VM_Fakes;
