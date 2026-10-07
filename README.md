# Enigma XOR

Historical **M3 / M4 Naval** Enigma, with one addition: a bitwise **XOR-Schlüssel** after the lamp.

You put text in by typing, pasting, or dragging a `.txt` file. You get an ordinary text file out. Export the **machine settings** or a **codebook** so the same configuration can decipher it later.

**Version:** 1.0.1 (build 2)

The rotor core is the wartime machine: wirings, notches, plugboard, ring settings, pawl-and-ratchet double-step, and a Greek rotor that does not turn. The military entry wheel is the identity alphabet. Canonical self-test with the XOR key empty: `AAAAA → BDZGO` (rotors I-II-III, rings AAA, windows AAA, UKW-B). The same machine with XOR key `Z` is `AAAAA → Y2A7X`.

## What the XOR does

Each letter is numbered A = 0 … Z = 25.

1. The historical machine steps, then produces a lamp letter.
2. That index is XORed with the next letter of the XOR key. The key repeats.
3. Results 0–25 are written as A–Z. Results 26–31 are written as the digits `2 3 4 5 6 7`.

An empty key, or a key of only A’s, is XOR with zero. The ciphertext is then pure historical Enigma, and Encipher and Decipher are the same rotor pass.

With any other key, Encipher is rotors then XOR. Decipher is XOR then rotors. A wrong key can produce a value the rotors cannot accept. That position is written as `?`, and the rotors still step.

| XOR key | `AAAAA` on the wiki machine |
|---|---|
| empty | `BDZGO` |
| `B` | `ACYHP` |
| `Z` | `Y2A7X` |
| `BQ` | `ATYWP` |

## Machine

| | M3 | M4 Naval |
|---|---|---|
| Rotors | 3 from I–VIII | Greek (Beta/Gamma, static) + 3 from I–VIII |
| Reflector | UKW-B, UKW-C | UKW-B Thin, UKW-C Thin |
| Plugboard | up to 10 pairs | up to 10 pairs |
| XOR key | up to 32 letters A–Z | up to 32 letters A–Z |

M4 with Beta at **A** and UKW-B Thin is electrically identical to M3 with UKW-B. The XOR, if set, is applied the same way on both.

Default launch settings are an M4 (Gamma-VIII-IV-I, UKW-C Thin, rings RNCT, windows JWMQ, full plugboard) and XOR key `UBOATNINETYSIX`.

## Use

1. Set the machine, or **Wiki Test Vector** (clears the XOR key) / **Randomize Machine**.
2. Type, paste, or drop a text file.
3. **Encipher** (⌘E) with **Group in fives on**. Digits in the message become English words unless you uncheck **Spell numbers in English**. Save the ciphertext as `.txt` (⌘S).
4. **Export Settings…** or **Export Codebook…** and keep that file with the ciphertext. Layout: [FORMAT.md](FORMAT.md).
5. To read it later: import the sheet, paste the ciphertext, turn **Group in fives off**, then **Decipher** (⌘D). Digits 2–7 in the ciphertext are XOR symbols. They are not spelled as numbers.

**How It Works** is the machine overview. **Help → Encoding and Decoding Steps** is the exact procedure ([HELP.md](HELP.md)).

## Historical checks

`--self-test` checks the wiki vector, the double-step, M4/M3 compatibility, and three published messages with the XOR key empty:

| Message | Machine |
|---|---|
| U-264, 1942 (Looks) | M4, Beta II IV I, UKW-B Thin, rings AAAV, windows VJNA |
| Scharnhorst, 1943 (Bey) | M3, III VI VIII, UKW-B, rings AHM, windows UZV |
| Dönitz indicator, 1 May 1945 | M4, Beta V VI VIII, UKW-C Thin, rings EPEL, windows NAEM, `QEOB` → `CDSZ` |

It also checks a codebook sheet where Ringstellung starts with **V** or **I** and Stecker contains **IV** or **VI**. Those must stay four M4 rotors. Fixture: [Examples/regression-v-ring-iv-plug-codebook.txt](Examples/regression-v-ring-iv-plug-codebook.txt).

## Build

```bash
cd ~/Apps-Usefull/EnigmaXOR
chmod +x build-app.sh
./build-app.sh
```

```bash
./build-app.sh --no-launch
.build/release/EnigmaXOR --self-test
```

Requires macOS 13+ and the Xcode toolchain (`DEVELOPER_DIR` defaults to Xcode.app). SwiftUI is not used; the window is AppKit.

## Keyboard

| Action | |
|---|---|
| Open text file | ⌘O |
| Encipher | ⌘E |
| Decipher | ⌘D |
| Save ciphertext | ⌘S |
| Copy output | ⇧⌘C |
| Clear message and output | ⌘K |
| Encoding and Decoding Steps | Help menu |
| How It Works | Help menu |
