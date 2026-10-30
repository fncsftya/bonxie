--  Where the running program is, and whether it can be replaced there.

package Updater.Locations is

   type Placements is (Not_Bundled, Running_From_Image, Read_Only, Replaceable);
   --  Not_Bundled: not in an application bundle (built in the tree), so there is nothing to replace.
   --  Running_From_Image: in a disk image or a translocated copy, which is not where it is kept.
   --  Read_Only: the folder it is in cannot be written to by this person.
   --  Replaceable: it can be.

   function Bundle return String;
   --  The path of the `.app` the program runs from, "" if it is not in one.

   function Placement (Bundle_Path : String) return Placements;
   --  Where the bundle at that path (or "") is kept.

   function Is_Running (Process : Natural) return Boolean;
   --  Whether a process of that number exists.

   function Process_Number return Natural;
   --  The number of this process.

   function Is_Writable (Path : String) return Boolean;

end Updater.Locations;
