package body Writing_VM is
   use type Items.Id;

   function Version (Self : View_Model) return Parts.Version_Number is (Parts.Value (Self.Changes));

   function Shown (Self : View_Model; Dirs : Directories) return Natural is
   begin
      for Dir in 1 .. Dirs.Count loop
         if Dirs (Dir).Key = Self.Selected and then Self.Selected /= 0 then
            return Dir;
         end if;
      end loop;
      return 0;
   end Shown;

   procedure Show (Self : in out View_Model; Dirs : Directories; Directory : Natural) is
      Key : constant Items.Id := (if Directory = 0 then 0 else Dirs (Directory).Key);
   begin
      if Self.Selected /= Key then
         Self.Selected := Key;
         Parts.Bump (Self.Changes);
      end if;
   end Show;

   procedure Reset (Self : in out View_Model) is
   begin
      if Self.Selected /= 0 then
         Self.Selected := 0;
         Parts.Bump (Self.Changes);
      end if;
   end Reset;

   procedure Reconcile (Self : in out View_Model; Dirs : Directories) is
   begin
      if Shown (Self, Dirs) = 0 then
         Reset (Self);
      end if;
   end Reconcile;

   function Parent_Of (Dirs : Directories; Dir : Natural) return Natural is
   begin
      if Dir /= 0 and then Dirs (Dir).Parent /= 0 then
         for Each in 1 .. Dirs.Count loop
            if Dirs (Each).Key = Dirs (Dir).Parent then
               return Each;
            end if;
         end loop;
      end if;
      return 0;
   end Parent_Of;

   function Depth (Dirs : Directories; Dir : Natural) return Natural is
      At_Dir : Natural := Dir;
      Total : Natural := 0;
   begin
      while Parent_Of (Dirs, At_Dir) /= 0 loop
         At_Dir := Parent_Of (Dirs, At_Dir);
         Total := Total + 1;
         pragma Assert (Total < Dirs.Count);
      end loop;
      return Total;
   end Depth;

   function Section_Directory (Dirs : Directories; Dir : Natural) return Natural is
      At_Dir : Natural := Dir;
   begin
      for Step in 1 .. Dirs.Count loop
         exit when At_Dir = 0 or else Dirs (At_Dir).Section /= 0;
         At_Dir := Parent_Of (Dirs, At_Dir);
      end loop;
      return At_Dir;
   end Section_Directory;

   function Within (Dirs : Directories; Dir, Ancestor : Natural) return Boolean is
      At_Dir : Natural := Dir;
   begin
      for Step in 0 .. Dirs.Count loop
         if At_Dir = Ancestor then
            return True;
         end if;
         exit when At_Dir = 0;
         At_Dir := Parent_Of (Dirs, At_Dir);
      end loop;
      return False;
   end Within;

   function In_View (Self : View_Model; Dirs : Directories; Directory : Natural) return Boolean is
     (Within (Dirs, Directory, Shown (Self, Dirs)));
end Writing_VM;
