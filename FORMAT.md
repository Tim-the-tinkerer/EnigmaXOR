# Enigma XOR text files

There is **no custom archive**. Ciphertext, settings, and the codebook are ordinary UTF-8 `.txt` files.

## Ciphertext and deciphered text

Encipher writes `{message}-cipher.txt`. Decipher writes `{message}-decipher.txt`.

The ciphertext alphabet is `A–Z` and, when a lamp index XORed with the Schlüssel lands on 26–31, the digits `2–7`:

| Value | Symbol |
|---|---|
| 0–25 | `A`–`Z` |
| 26–31 | `2` `3` `4` `5` `6` `7` |

Spaces are ignored on decipher. `0`, `1`, `8`, and `9` are not symbols and are dropped. Grouping does not drop `2–7`.

```
Y2A7X
BDZGO WCXLT
```

With an empty XOR key the file is letters only, and a historical Enigma with the same rotor settings can read it. With a key set, decipher XORs first. Encipher will not undo it.

## Machine settings

**Export Settings…** writes a labeled key sheet. **Import Settings…** (or dropping the file) reads it back.

```
Enigma XOR machine settings
The rotors are a historical M3 or M4. XOR-Schlüssel is the one addition.
Empty XOR means encipher and decipher are the same rotor pass. With a
Schlüssel, encipher is rotors then XOR; decipher is XOR then rotors.
Reset Grundstellung before each message.

Machine:       M4
UKW:           C-Thin
Walzenlage:    Gamma VIII IV I
Ringstellung:  R N C T
Grundstellung: J W M Q
Stecker:       AZ BY CX DW EV FU GT HS IR JQ
XOR-Schlüssel: UBOATNINETYSIX
```

| Field | Also accepted | Notes |
|---|---|---|
| Machine | Mode, Modell, Model | `M3` or `M4` |
| UKW | Reflector, Umkehrwalze | M3: `B` or `C`. M4: `B-Thin` or `C-Thin` only. `UKW-Z` and any other name fail the import |
| Walzenlage | Rotors, Wheels | Left to right. M4 leftmost must be Beta or Gamma |
| Ringstellung | Rings | Letters A–Z, or numbers `01`–`26` (`01` = A) |
| Grundstellung | Positions, Windows, Start | Window letters before the first keypress |
| Stecker | Steckerbrett, Plugboard, Plugs | Up to 10 pairs; `—` means none |
| XOR-Schlüssel | XOR, XOR key, Stichwort | Up to 32 letters A–Z. `—` or empty means no XOR |

A sheet from Classic Enigma, with no XOR line, imports as historical Enigma. An EnigmaVault classic `configuration` JSON object is accepted. A missing `xorKey` means no XOR. This app never writes a Vault archive.

## Codebook

**Export Codebook…** writes a one-entry Schlüsseltafel. The XOR key is a labeled line under the table, not a column, so a ring letter `V` or `I` is not read as a fifth wheel and a stecker pair `IV` is not read as rotor IV.

```
XOR-Schlüssel: UBOATNINETYSIX
```

Kenngruppen on the sheet are identification only and are not used by the cipher.

## Signal path

Encipher, for each plaintext letter:

1. Plugboard.
2. Step the rotors (right rotor every letter; middle on the right rotor’s notch; double-step when the middle rotor is on its own notch). On M4 the Greek rotor does not step.
3. Rotors right to left, reflector, rotors left to right. The entry wheel is the identity.
4. Plugboard. That is the lamp letter.
5. XOR the lamp index with the next XOR-Schlüssel letter. Write the symbol from the table above.

Decipher XORs the ciphertext symbol first, then runs steps 1–4 on the recovered lamp index.
