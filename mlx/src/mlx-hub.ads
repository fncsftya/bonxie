--  The models in the Hugging Face cache (`~/.cache/huggingface/hub`, unless
--  HF_HUB_CACHE or HF_HOME say otherwise: see Cache_Directory), which
--  keeps each in a folder `models--<provider>--<name>`, its files in
--  `snapshots/<revision>`. A model is named as Hugging Face does,
--  `<provider>/<name>`.
package MLX.Hub is

   Max_Models : constant := 22;
   Max_Name   : constant := 256;
   --  Models listed, and bytes of a name: more are left out.

   type Models is private;

   function Cache_Directory return String
     with Post => Cache_Directory'Result /= "";
   --  Where the cache is, whether it is there or not: `$HF_HUB_CACHE`, or
   --  else `$HF_HOME/hub`, or else `~/.cache/huggingface/hub`.

   function Is_Present return Boolean;
   --  Whether the cache is there.

   procedure Scan (Found : out Models);
   --  Look for models in the cache, in order of name.

   function Count (Found : Models) return Natural
     with Post => Count'Result <= Max_Models;

   function Model_At (Found : Models; Which : Positive) return String
     with Pre  => Which <= Count (Found),
          Post => Model_At'Result'Length in 3 .. Max_Name;

   function Left_Out (Found : Models) return Boolean;
   --  Whether there were more than Max_Models.

   function Name_Of_Folder (Folder : String) return String;
   --  The name of the model kept in the cache's folder, "provider/name" of
   --  "models--provider--name"; "" if the folder is not a model's.

   function Snapshot (Name : String) return String;
   --  The folder of the files of the model of this name: the revision
   --  that `refs/main` says, or else the newest; "" if there is none.

private

   type Name_Array is array (1 .. Max_Models) of String (1 .. Max_Name);
   type Length_Array is array (1 .. Max_Models) of Natural;

   type Models is record
      Total    : Natural range 0 .. Max_Models := 0;
      Names    : Name_Array := [others => [others => ' ']];
      Lengths  : Length_Array := [others => 0];
      Overflow : Boolean := False;
   end record;

end MLX.Hub;
