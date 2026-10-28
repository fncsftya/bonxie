--  Tests of the browser pane's view-model alone, over a page that is pretended: no window, no web view. See Goldens.

package Browser_VM_Tests is

   procedure Addresses;
   --  What is typed becomes an address: one with a scheme is kept, one without gets https://.

   procedure Going;
   --  No page is asked for until an address is gone to; then Go and Reload reach the page, and where the page
   --  is (redirects and clicks change it) is the address shown.

   procedure Keeping;
   --  Back and Forward follow the page; a favourite is made, kept in a file for another model, and let go;
   --  a capture is begun, found done, and finished.

   procedure Without_A_Page;
   --  With no web view there is nothing to do, and nothing is asked of it.

end Browser_VM_Tests;
