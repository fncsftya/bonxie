with Ada.Strings.Fixed;

package body Search_VM is
   use type Parts.Version_Number;

   procedure Initialize (Self : in out View_Model; Engine : not null access Finder'Class) is
   begin
      Self.Engine := Finder_Access (Engine);
   end Initialize;

   function Term (Self : View_Model) return String
   is (Parts.Get (Self.Typed));
   function Is_Showing (Self : View_Model) return Boolean
   is (Self.Showing);
   function Location (Self : View_Model) return Context
   is (Self.Where);
   function Found (Self : View_Model) return Result
   is (Self.Matches);
   overriding
   function Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes) + Parts.Version (Self.Typed));

   function Summary (Self : View_Model) return String is
      function Image (N : Natural) return String
      is (Ada.Strings.Fixed.Trim (N'Image, Ada.Strings.Both));
   begin
      return
        Image (Self.Matches.Current) & " / " & Image (Self.Matches.Total) & (if Self.Matches.Busy then " ..." else "");
   end Summary;

   procedure Set_Term (Self : in out View_Model; Text : String) is
   begin
      Parts.Set (Self.Typed, Text);
   end Set_Term;

   procedure Poll (Self : in out View_Model) is
      Fresh : Result;
   begin
      if not Self.Showing then
         return;
      end if;
      if not Valid (Self.Engine.all, Self.Where) then
         Execute (Self, Close);
         return;
      end if;
      Refresh (Self.Engine.all, Self.Where, Term (Self), Fresh);
      if Fresh /= Self.Matches then
         Self.Matches := Fresh;
         Parts.Bump (Self.Changes);
      end if;
   end Poll;

   procedure Open (Self : in out View_Model; Where : Context) is
   begin
      if Self.Showing then
         Execute (Self, Close);
      end if;
      Self.Where := Where;
      if Valid (Self.Engine.all, Where) then
         Self.Showing := True;
         Parts.Bump (Self.Changes);
         Poll (Self);
      end if;
   end Open;

   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      pragma Unreferenced (Index);
   begin
      return Self.Showing and then (What = Close or else Self.Matches.Total > 0);
   end Can_Execute;

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Close           =>
            Clear (Self.Engine.all, Self.Where);
            Self.Showing := False;
            Self.Matches := (others => <>);
            Parts.Bump (Self.Changes);

         when Previous | Next =>
            if Valid (Self.Engine.all, Self.Where) then
               Advance (Self.Engine.all, Self.Where, What = Previous);
            end if;
            Poll (Self);
      end case;
   end Execute;
end Search_VM;
