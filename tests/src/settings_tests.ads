--  Tests of the settings as a person uses them, read as an assistive
--  technology is told of them and clicked by what they are called, not where
--  they are: the choices, what the form shows for each, and what the choices
--  make the windows do. See Goldens.

package Settings_Tests is

   procedure By_Name;
   --  The choices of theme, background and speech model, VSync, and the
   --  download row that Parakeet has.

   procedure Browser_Filter;
   --  The Browser section: the filter is off, and no list shows; each mode shows its own list, to which sites are
   --  added, typed as any address, then chosen, changed and removed by the form's controls; what is not an
   --  address is said so. A golden of the section with sites in it.

   procedure Gallery_Cache;
   procedure Colour_Sampling;

end Settings_Tests;
