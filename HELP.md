# Encoding and decoding documents

This is the exact procedure Enigma XOR 1.0.1 runs. The rotor pass is a historical M3 or M4. The XOR-Schlüssel is the one addition. With that key empty, Encipher and Decipher are the same rotor pass. With a key set, Encipher is rotors then XOR, and Decipher is XOR then rotors. Text prep still differs. This file documents the current implementation.

Open this from **Help → Encoding and Decoding Steps**.

---

## 1. The two text boxes

| Pane | Role |
|---|---|
| **MESSAGE** | Input. Type, paste, **Open Text File…** (⌘O), or drop a `.txt` file here. |
| **CIPHERTEXT** / **DECIPHERED** | Output of the last Encipher or Decipher. The heading and save name follow that operation. **Save…** (⌘S) writes **this pane only**. |

**Swap** exchanges the two panes. It does not run the machine, does not reset rotors, and does not change settings.

**Clear** (⌘K) empties MESSAGE and the output pane, resets the save basename to `message`, and puts the heading back to CIPHERTEXT. Machine settings are not changed.

**Copy Output** (⇧⌘C) copies the Ciphertext pane.

---

## 2. Encode a document (what you do)

Do these in order.

1. **Set the machine** before the message, or import a settings sheet / codebook (see §7).  
   Switching **M3 / M4** after you have set rotors **wipes the machine back to that mode’s defaults**. Do not toggle mode to “check” it.
2. Put the plaintext into **MESSAGE**.
3. Leave **Spell numbers in English** on if the document has digits you want kept as words (`5` → FIVE). Turn it off if you want digits thrown away.
4. Leave **Group in fives** **on** for Encipher. That is how the ciphertext file is written (`BDZGO WCXLT`). Turn it **off** before Decipher (see §3). The same checkbox is used for both buttons.
5. Click **Encipher** (⌘E). Do **not** click Decipher to encode. Decipher will **not** spell numbers, so a document with digits produces a different letter stream (see §5).
6. **Save Ciphertext…** — a plain `.txt` file. Default name: `{message}-cipher.txt`. `{message}` is the dropped file’s basename with `-cipher` / `-decipher` stripped, or `message` if you typed.
7. **Export Settings…** or **Export Codebook…** as a **separate** `.txt` file. The ciphertext file does not contain the machine. Without one of these sheets (or a written copy of the same fields), the file cannot be read later.

You now have two files, e.g. `hello-cipher.txt` and `hello-settings.txt`. Keep them together.

---

## 3. Decode a document (what you do)

1. **Restore the machine first.** Drop the settings/codebook file, or **Import Settings…**.  
   If you drop the ciphertext first, that is fine **unless** the ciphertext text happens to look like a key sheet (see §8). Safer: settings first.
2. Put the ciphertext into **MESSAGE** (open, paste, or drop the `-cipher.txt`).
3. **Spell numbers in English is ignored on Decipher.** You can leave it on. It does not run.
4. **Turn Group in fives off.** Decipher uses that checkbox on the **output**. If it stays on, the recovered letter stream is wrapped again (`ATTAC KATFI VE` instead of `ATTACKATFIVE`) and does not read as the decoded message. Spaces in the **input** ciphertext are already ignored; this is about the output pane.
5. Click **Decipher** (⌘D).  
   With a XOR-Schlüssel set, Encipher will **not** recover the letters. Decipher XORs each symbol first. Digits **2–7** in the ciphertext are real symbols (XOR results 26–31), not numbers to spell. Leave **Group in fives** off so the recovered letters are not wrapped again.
6. The output pane is titled **DECIPHERED** and holds the **letter stream**, not the original document (see §6). **Save Deciphered…** defaults to `{message}-decipher.txt` (never `{message}-cipher-cipher.txt`).

---

## 4. What Encipher actually does

Every Encipher click, in this order:

### 4.1 Read the machine from the UI (not from the last run)

The app builds a **new** machine from the fields **as they are now**:

- Mode: M3 or M4
- Rotors: split on `-`, space, or comma (`Gamma-VIII-IV-I` or `Gamma VIII IV I`)
- Reflector: the popup. M3 offers UKW-B and UKW-C. M4 offers only UKW-B Thin and UKW-C Thin. A wide reflector on an M4 sheet is rejected.
- Rings and Positions: spaces stripped (`R N C T` → `RNCT`)
- Plugboard: split on space, comma, tab, or semicolon; at most 10 pairs of two distinct letters
- XOR key: letters A–Z, at most 32. Spaces and hyphens are ignored. Empty, `—`, or `NONE` means no XOR

If those fields are invalid, Encipher stops and the status line shows the error. Nothing is written to Ciphertext.

The **Positions** field is always the start of this run. The status line’s “Windows now …” is where the rotors **finished**. The next Encipher/Decipher does **not** continue from there. It starts from the Positions field again. You do not have to reset Grundstellung in the UI; the app already does.

### 4.2 Turn the MESSAGE pane into A–Z only

`EnigmaText.letters(from: message, spellNumbers: checkbox)`

**A. Spell numbers — Encipher only, and only if the checkbox is on**

Left to right, each run of ASCII digits `0–9` is replaced by English words. A minus (`-`, `−`, or `–`) becomes MINUS only when it is a unary sign: at the start of the text, after whitespace, or after opening punctuation (`( [ { " '`). A dash between digits is discarded punctuation and the next run is a new positive number (`2026-09-14` is not MINUS NINE; `555-1234` is not MINUS 1234).

| Input run | Words inserted |
|---|---|
| `0` | ZERO |
| `5` | FIVE |
| `21` | TWENTY ONE |
| `42` | FORTY TWO |
| `100` | ONE HUNDRED |
| `101` | ONE HUNDRED ONE |
| `1942` | ONE THOUSAND NINE HUNDRED FORTY TWO |
| `1,234` | ONE THOUSAND TWO HUNDRED THIRTY FOUR (comma groups of three) |
| `007` | ZERO ZERO SEVEN (more than one digit **and** a leading zero → one word per digit) |
| `0800` | ZERO EIGHT ZERO ZERO |
| `3.14` | THREE POINT ONE FOUR (fraction: one word per digit) |
| `-4` | MINUS FOUR (unary: start of text) |
| `lost -4` / `(-4)` | … MINUS FOUR |
| `2026-09-14` | TWO THOUSAND TWENTY SIX, then 09, then FOURTEEN (dashes are not minus) |
| `555-1234` | FIVE HUNDRED FIFTY FIVE, then 1234 (not MINUS) |
| `12:30` | TWELVE then `:` then THIRTY (colon is not part of the number) |
| `1800 HOURS` | EIGHTEEN HUNDRED, then the word HOURS (`EIGHTEENHUNDREDHOURS`) |
| `1850 HOURS` | EIGHTEEN HUNDRED AND FIFTY HOURS |
| `0800 HOURS` | ZERO EIGHT HUNDRED HOURS |
| `1800` (no HOURS) | ONE THOUSAND EIGHT HUNDRED (ordinary cardinal) |
| `1260 HOURS` | TWELVE HUNDRED AND SIXTY HOURS (minutes 60 are not rejected) |
| `2400 HOURS` | TWENTY FOUR HUNDRED HOURS (hour 24 is not rejected; some clocks use 2400 for midnight) |

A 3- or 4-digit run immediately before the word HOURS (any case, optional space) is clock time: hour digits, then HUNDRED, then AND and the minutes if they are not 00. The digits are **not** checked as a real clock. `1260` and `2400` still take the hours path. Cardinals otherwise go through thousand / million / billion / trillion and do not use “and”. Hyphens are not used (`TWENTY ONE`, not `TWENTY-ONE`). Runs longer than 15 digits, or with a leading zero (and not a HOURS clock), are spelled digit-by-digit.

A space is inserted before the words if the previous character was not whitespace, so `room12` becomes `room TWELVE`.

**B. Umlauts** (Encipher only)

`Ä/ä` → `AE`, `Ö/ö` → `OE`, `Ü/ü` → `UE`, `ß` → `SS`.

**C. Keep ASCII A–Z only** (always)

Everything is uppercased. Any character that is not `A–Z` is dropped: spaces, punctuation, leftover digits (if spelling was off), newlines, quotes, digits that were never spelled.

Worked MESSAGE `Attack at 5. Über die Brücke.` with spelling on:

1. Spell: `Attack at FIVE. Über die Brücke.`
2. Umlauts: `Attack at FIVE. UEBer die BrUECke.` (`ü` → `UE`; `Ü` would too)
3. Letters: `ATTACKATFIVEUEBERDIEBRUECKE`

That letter string is what the rotors see. It is **not** shown in the UI.

### 4.3 Run the machine

For **each** remaining letter, in order:

1. Plugboard
2. **Step the rotors** (before the wiring)
3. Rotors right-to-left
4. Reflector
5. Rotors left-to-right
6. Plugboard

Stepping (historical pawl-and-ratchet, including the middle-rotor double-step):

- Right-hand rotor steps every letter.
- If the right rotor **was** on its turnover letter, the middle rotor also steps.
- If the middle rotor **was** on its turnover letter, it double-steps: left and middle both step even when the right rotor is not on a notch.
- **M4:** the leftmost Greek rotor (Beta/Gamma) **never** steps during the message. Only the three Naval rotors do.

Turnover letters: I Q, II E, III V, IV J, V Z, VI/VII/VIII Z and M. Beta and Gamma have none.

The military entry wheel is a straight-through alphabet, so it is not a separate step. A lamp letter never equals the keyboard letter. That property belongs to the rotor pass. After the XOR it can disappear, and a ciphertext symbol can match the plaintext letter.

### 4.3a XOR-Schlüssel

After the lamp letter, if the XOR key is not empty:

1. Take the lamp as a number, A = 0 … Z = 25.
2. Take the next Schlüssel letter the same way. The key repeats from the start when the message is longer.
3. Bitwise XOR the two numbers. The result is 0–31.
4. Write 0–25 as A–Z, and 26–31 as the digits `2 3 4 5 6 7`.

Key letter A is XOR 0, so a Schlüssel of only A’s matches an empty key. Wiki vector with no XOR: `AAAAA` → `BDZGO`. The same machine with XOR key `Z` → `Y2A7X`.

Decipher reverses that order. Each ciphertext symbol (A–Z or 2–7) is XORed with the same Schlüssel letter, which must land back on 0–25, and that lamp index is sent through the rotors. A wrong key can produce a value above 25. That position is written as `?` and the rotors still step, so the rest of the message stays aligned. Group in fives keeps each `?`, so the mark is still visible when that checkbox is on.

If the letter stream is empty (nothing survived step 4.2), the app stops: “No letters in the message. Enigma only ciphers A–Z.”

### 4.4 Write the Ciphertext pane

If **Group in fives** is on, the output is split into groups of five symbols with spaces (`BDZGO WCXLT`, or `Y2A7X` when the XOR overflows). Digits 2–7 are kept. A leftover shorter group is kept. If the checkbox is off, you get one continuous block.

On **Encipher**, leave it on — that is the usual ciphertext file. On **Decipher**, turn it off — otherwise the recovered plaintext is wrapped the same way and is not a proper decode.

That string is what **Save Ciphertext…** or **Save Deciphered…** writes. Encipher → `{message}-cipher.txt`. Decipher → `{message}-decipher.txt`. No header, no machine settings.

---

## 5. What Decipher actually does

Same as Encipher **except**:

| | Encipher | Decipher |
|---|---|---|
| Spell numbers | Yes, if the checkbox is on | **Never** |
| Group in fives | **On** for a normal ciphertext file | **Off** — otherwise the decode is re-wrapped into fives |
| Machine | New machine from the UI fields | Same |
| XOR | After the lamp | Before the rotors |
| Symbols kept | A–Z from the message (digits spelled or dropped) | A–Z and digits 2–7. Other digits are dropped. Numbers are not spelled. |

So:

- Ciphertext in MESSAGE + **Decipher** with Group in fives **off** → continuous letter stream of the original encode (`ATTACKATFIVE`).
- Ciphertext in MESSAGE + **Decipher** with Group in fives **on** → same letters, but spaced as ciphertext (`ATTAC KATFI VE`). That is not a proper decode.
- Ciphertext in MESSAGE + **Encipher** → recovers the letters **only when the XOR key is empty**. With a Schlüssel, Encipher is the wrong direction.
- **Plaintext** in MESSAGE + **Decipher** → digits are **dropped**, not spelled. `Attack at 5` becomes `ATTACKAT`, not `ATTACKATFIVE`. That is a different message. Use Encipher to encode.

---

## 6. You will not get the original document back

Decode returns the **letter stream from step 4.2**, not the file you dropped.

| Original | After decode (spelling was on at encode) |
|---|---|
| `Attack at 5.` | `ATTACKATFIVE` |
| `Über` | `UEBER` |
| `Hello, world!` | `HELLOWORLD` |
| `12:30` | `TWELVETHIRTY` |
| Line breaks, quotes, tabs | gone |

There is no step that turns FIVE back into `5`, or restores punctuation. If **Group in fives** is left on during Decipher, the output is `ATTAC KATFI VE` — turn it **off** so you get `ATTACKATFIVE`.

The letter count in the status line is the length of that stream. “Numbers spelled in English.” appears only when Encipher ran **and** the MESSAGE pane still contains a digit character.

---

## 7. Settings and codebook (required to decode later)

Neither file is a custom archive. Both are UTF-8 text. Layout: [FORMAT.md](FORMAT.md).

**Export Settings…** writes `{source}-settings.txt` (Machine, UKW, Walzenlage, Ringstellung, Grundstellung, Stecker, XOR-Schlüssel).

**Export Codebook…** writes `{source}-codebook.txt` (one-row Schlüsseltafel for **this** machine). Kenngruppen on that sheet are random identification groups. They are **not** used by the cipher.

**Import / drop:** the file is parsed in this order:

1. JSON object containing `mode` and `rotorNames` (EnigmaVault classic `configuration` blob)
2. Else a codebook table row
3. Else a labeled `Field: value` sheet

The table parser takes **exactly** three rotors (M3) or four (M4), then that many ring letters, then stecker pairs, then Grundstellung. Ring letters **I** and **V** are also rotor names; stecker **IV** looks like a wheel. Those are not extra rotors.

On success, the machine fields in the window are replaced. The MESSAGE pane is **not** changed.

---

## 8. Dropping or opening a file (this is easy to get wrong)

One file at a time (the first, if you drop several). UTF-8 only.

The app then **classifies** the file. If it “looks like settings”, it loads the **machine**. Otherwise it replaces **MESSAGE** (and sets `source` from the filename).

A file “looks like settings” when **any** of these is true:

- The text contains `WALZENLAGE` **and** (`GRUNDSTELLUNG` or `RINGSTELLUNG`)
- The text contains `MACHINE:` **and** (`UKW` or `REFLECTOR`)
- The text contains `Schlüsseltafel` / `SCHLUESSELTAFEL` / `SCHLUSSELTAFEL`
- The text is JSON with both `rotorNames` and `mode`

A plaintext letter that happens to discuss Walzenlage and Grundstellung will be treated as a key sheet, not as a message. Ciphertext this app writes is only A–Z and spaces, so it will not trip that test.

When a file is loaded as a **message**, the status letter count uses `letters(from:)` **without** spelling, so digits in that count are already dropped. Encipher with spelling on will use a longer stream.

---

## 9. Other controls that affect a document

| Control | What it actually does |
|---|---|
| **M3 / M4** | Replaces the whole machine with that mode’s defaults (M3: I-II-III / UKW-B / AAA; M4: Gamma-VIII-IV-I / UKW-C Thin / RNCT / JWMQ / full plugboard). |
| **Wiki Test Vector** | Loads I-II-III, AAA, AAA, UKW-B, no stecker; puts `AAAAA` in MESSAGE; clears Ciphertext. Encipher should show `BDZGO`. |
| **Randomize Positions** | Only the Positions field. Rotors, rings, plugs unchanged. |
| **Randomize Machine** | New rotors, reflector, rings, positions, and 10 plug pairs for the **current** mode. |
| **Clear** (⌘K) | Empties MESSAGE and output, save name `message`, heading CIPHERTEXT. Does not change the machine. |
| **How It Works** | Machine overview. Not this procedure. |

---

## 10. Minimum checklist

**Encode**

1. Set or randomize the machine. Do not switch M3/M4 afterwards.
2. MESSAGE = document.
3. **Group in fives on.** Encipher (not Decipher) if the document has digits and spelling is on.
4. Save Ciphertext.
5. Export Settings or Codebook.

**Decode**

1. Import/drop the settings or codebook.
2. MESSAGE = ciphertext file.
3. **Group in fives off.** Then Decipher.
4. Read the letter stream in the **DECIPHERED** pane. Save as `{message}-decipher.txt`. It will not match the original punctuation or digits.

**Sanity check:** Wiki Test Vector → Encipher (fives on) → `BDZGO`. Swap → Group in fives **off** → Decipher → `AAAAA`.
