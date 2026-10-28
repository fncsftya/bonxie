with Browser_VM;
with Pomarine.UI.Contexts;

--  How the browser pane's controls (Pomarine.UI) are bound to its view-model: the buttons that move the page, the
--  address and the title. Instantiated once, here, in a package of its own, as the adapters must be.

package Browser_UI is
   package Controls is new Pomarine.UI.Contexts (Browser_VM.Commands, Browser_VM.Model);

   Status : constant Controls.Text_Property := Controls.Showing (Browser_VM.Status'Access);

   Marked : constant Controls.Flag_Property := Controls.Showing (Browser_VM.Is_Favourite'Access);

   Address : constant Controls.Text_Property :=
     Controls.Editing (Browser_VM.Address_Draft'Access, Browser_VM.Set_Address_Draft'Access);
end Browser_UI;
