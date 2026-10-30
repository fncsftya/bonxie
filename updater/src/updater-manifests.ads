with Updater.Versions;

--  The text that is signed. A release carries it beside the disk image, and the signature (Signature_Name) is
--  over exactly these bytes. It says what the disk image must be, so the image needs no signature of its own
--  (Ed25519 does not stream, and the image is large):
--
--     bonxie-update 1
--     version 0.2.0
--     file Bonxie.dmg
--     size 123456789
--     sha256 <64 lowercase hex digits>
--
--  Each line ends with a line feed.

package Updater.Manifests is

   Format_Line : constant String := "bonxie-update 1";

   subtype Hex_Digest is String (1 .. 64);

   type Manifest is record
      Version : Versions.Version;
      Size    : Long_Long_Integer := 0;
      --  Bytes in the disk image.
      Digest  : Hex_Digest := [others => '0'];
      --  Its SHA-256.
   end record;

   function Parse (Text : String; Item : out Manifest) return Boolean;
   --  Whether Text is a manifest, with the file named Disk_Image_Name, a size of up to twelve digits and a digest
   --  of lowercase hex; Item is it if so.

   function Image (Item : Manifest) return String
   with Post => (for some Line_Feed of Image'Result => Line_Feed = ASCII.LF);
   --  The text that Parse gives Item back from.

end Updater.Manifests;
