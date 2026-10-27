with Pomarine.Events;
with View;

--  What a person does with a pointer and keys, given to a View.Session as the events they come to.

package Gestures is

   procedure Move_To (Session : in out View.Session; X, Y : Float; Held : Boolean := False);
   --  The pointer to X, Y, with the left button held down or not.

   procedure Press (Session : in out View.Session; X, Y : Float);
   --  The pointer to X, Y, and the left button down.

   procedure Release (Session : in out View.Session; X, Y : Float);

   procedure Click_On (Session : in out View.Session; X, Y : Float);

   procedure Double_Click_On (Session : in out View.Session; X, Y : Float);

   procedure Drag (Session : in out View.Session; From_X, From_Y, To_X, To_Y : Float);
   --  Press at the first point, the pointer in two moves to the second, and release there.

   procedure Type_In (Session : in out View.Session; Text : String);
   --  As typed: in events of as much as one can hold, never cutting a character.

   procedure Press_Key (Session : in out View.Session; Code : Pomarine.Events.Key_Code; Command : Boolean := False);

end Gestures;
