--  Finding out that a newer release is on GitHub, fetching it, checking it is the author's, and handing over to a
--  script that puts it in place of the running program. It knows nothing of the application's screens: the
--  application asks (Releases, Versions), a background job stages the download (Staging), and the application
--  quits when it has been handed over.
--
--  What makes a release trusted is an Ed25519 signature on its manifest (Manifests), made with a key that is
--  not on GitHub, checked against the public key built into the program (Keys). The program is not notarized, so
--  nothing else vouches for it.

package Updater is

   Repository : constant String := "fncsftya/bonxie";
   --  Where the releases are: https://github.com/fncsftya/bonxie/releases

   Latest_URL : constant String := "https://api.github.com/repos/" & Repository & "/releases/latest";
   --  GitHub's answer for the newest release that is neither a draft nor a prerelease.

   Disk_Image_Name : constant String := "Bonxie.dmg";
   Manifest_Name   : constant String := Disk_Image_Name & ".manifest";
   Signature_Name  : constant String := Manifest_Name & ".sig";
   --  The assets of a release that the updater uses.

end Updater;
