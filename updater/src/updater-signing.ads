--  Ed25519 and SHA-256, by CryptoKit (see updater_swift.swift).

package Updater.Signing is

   function Verify (Public_Key, Message, Signature : String) return Boolean;
   --  Whether Signature (base64) is the Ed25519 signature of exactly the bytes of Message by the holder of
   --  Public_Key (base64, 32 bytes). Anything that is not a key or a signature is False.

   function SHA_256 (File_Name : String) return String
   with Post => SHA_256'Result'Length in 0 | 64;
   --  The digest of the file's bytes as 64 lowercase hex digits; "" if the file cannot be read.

end Updater.Signing;
