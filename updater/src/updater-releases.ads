with Ada.Strings.Unbounded;
with Updater.Versions;

--  What GitHub says of the newest release (Latest_URL), reduced to what the updater uses.

package Updater.Releases is

   type Release is record
      Version        : Versions.Version;
      Notes          : Ada.Strings.Unbounded.Unbounded_String;
      --  The release's description, as its author wrote it.
      Page_URL       : Ada.Strings.Unbounded.Unbounded_String;
      Disk_Image_URL : Ada.Strings.Unbounded.Unbounded_String;
      Manifest_URL   : Ada.Strings.Unbounded.Unbounded_String;
      Signature_URL  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Is_Download_URL (Text : String) return Boolean;
   --  Whether it is https, on github.com, in this repository's releases: the only place the updater fetches from.

   function Parse (Text : String; Item : out Release) return Boolean;
   --  Whether Text is a published release (neither a draft nor a prerelease) whose tag is a version and that has
   --  the three assets (Disk_Image_Name, Manifest_Name and Signature_Name), each at a download URL; Item is it
   --  if so. Anything else, even text that is not JSON, is not a release.

   function First_Line (Notes : String; Limit : Positive) return String
   with Post => First_Line'Result'Length <= Limit;
   --  What a dialog can say of the notes: the first line that is more than markup (a heading's marks and a list's
   --  bullet are dropped), cut at Limit.

end Updater.Releases;
