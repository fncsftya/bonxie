--  The public half of the key the releases are signed with: the private half is the author's (see
--  tools/update-key.swift) and is not in the repository.

package Updater.Keys is

   Public_Key : constant String := "tku1mt3HrhP88qm2KmdX45o25rMCBIqSp3/VCkmXZvw=";
   --  Base64 of the 32 bytes of the Ed25519 public key.

end Updater.Keys;
