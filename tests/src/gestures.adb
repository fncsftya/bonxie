package body Gestures is

   package Events renames Pomarine.Events;

   procedure Move_To (Session : in out View.Session; X, Y : Float; Held : Boolean := False) is
   begin
      View.Handle
        (Session,
         Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, Left_Held => Held, others => <>));
   end Move_To;

   procedure Button (Session : in out View.Session; Kind : Events.Event_Kind; Clicks : Positive; X, Y : Float) is
   begin
      View.Handle
        (Session, Events.Event'(Kind => Kind, Button => 1, Clicks => Clicks, Mouse_X => X, Mouse_Y => Y, others => <>));
   end Button;

   procedure Press (Session : in out View.Session; X, Y : Float) is
   begin
      Move_To (Session, X, Y);
      Button (Session, Events.Mouse_Down, 1, X, Y);
   end Press;

   procedure Release (Session : in out View.Session; X, Y : Float) is
   begin
      Button (Session, Events.Mouse_Up, 1, X, Y);
   end Release;

   procedure Click_On (Session : in out View.Session; X, Y : Float) is
   begin
      Press (Session, X, Y);
      Release (Session, X, Y);
   end Click_On;

   procedure Double_Click_On (Session : in out View.Session; X, Y : Float) is
   begin
      Click_On (Session, X, Y);
      Move_To (Session, X, Y);
      Button (Session, Events.Mouse_Down, 2, X, Y);
      Release (Session, X, Y);
   end Double_Click_On;

   procedure Drag (Session : in out View.Session; From_X, From_Y, To_X, To_Y : Float) is
   begin
      Press (Session, From_X, From_Y);
      --  In two moves, as a pointer is.
      Move_To (Session, (From_X + To_X) / 2.0, (From_Y + To_Y) / 2.0, Held => True);
      Move_To (Session, To_X, To_Y, Held => True);
      Release (Session, To_X, To_Y);
   end Drag;

   procedure Type_In (Session : in out View.Session; Text : String) is
      First : Positive := Text'First;
      Last  : Natural;
   begin
      while First <= Text'Last loop
         Last := Natural'Min (Text'Last, First + Events.Text_Capacity - 1);
         while Last < Text'Last and then Character'Pos (Text (Last + 1)) in 16#80# .. 16#BF# loop
            Last := Last - 1;
         end loop;
         pragma Assert (Last >= First);
         View.Handle (Session, Events.Text_Event (Text (First .. Last)));
         First := Last + 1;
      end loop;
   end Type_In;

   procedure Press_Key (Session : in out View.Session; Code : Events.Key_Code; Command : Boolean := False) is
   begin
      View.Handle (Session, Events.Event'(Kind => Events.Key_Down, Key => Code, Command => Command, others => <>));
   end Press_Key;

end Gestures;
