# Security

Enigma XOR is a historical machine plus a repeating XOR. **Do not use it to protect real secrets.**

- The reflector still guarantees that a lamp letter never equals the key that was pressed. The XOR can hide that from the ciphertext. It does not repair the rotor machine.
- The XOR-Schlüssel is written in the clear on the settings sheet and the codebook. It is not stretched, and it is not a password.
- The key space of the rotors is large by 1940 standards and small by modern ones. M4 was broken in 1942–43. A 32-letter XOR on top of a known-plaintext rotor machine is not a substitute for that history.
- Ciphertext, settings, and codebooks are ordinary text. Anyone who has the ciphertext and the sheet can read the message.
- **Spell numbers in English** is a plaintext transform before the rotors. It is not encryption.
- This app does not authenticate, compress, or hide filenames.

For file encryption use an audited tool such as macOS FileVault, age, or GPG.
