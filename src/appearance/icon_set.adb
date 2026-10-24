package body Icon_Set is

   procedure Install (Library : in out Pomarine.Icons.Library; Directory : String) is
   begin
      Sets.Install (Library, Directory);
   end Install;

end Icon_Set;
