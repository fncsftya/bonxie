--  Tests of the browser's site filter: the base address a site is kept as, which pages the rules let through,
--  and the view-model that edits them, with no window and no web view. See Goldens.

package Site_Filter_Tests is

   procedure Bases;
   --  What is typed is cut down to its base address, or is not an address.

   procedure Rules_Permit;
   --  Off lets all through; blocking holds back the sites listed and their subdomains; allowing lets through only
   --  those. Pages that are not on the web are never held back.

   procedure Editing;
   --  The mode is chosen; sites are added, chosen, changed and removed; what is not an address, or is in the list
   --  already, is refused; the choices are kept in a file for another model.

end Site_Filter_Tests;
