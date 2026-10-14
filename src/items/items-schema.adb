with Repository.Schema;

package body Items.Schema is

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Repository.Schema.Prepare (Store);
   end Prepare;

end Items.Schema;
