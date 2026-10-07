# Changelog

## 1.0.1 (build 2)

- The launch XOR-Schlüssel is `UBOATNINETYSIX`. Wiki Test Vector still clears it.
- M4 accepts only UKW-B Thin and UKW-C Thin. Wide B and C are rejected, and the M4 reflector menu disables them. M3 still uses wide B and C.
- An unrecognized reflector, such as UKW-Z, UKW Z, or Reflector Z, fails the import as “Unknown reflector: …”. It is not read as UKW-B. A wide reflector on M4, or a thin reflector on M3, uses a separate incompatibility message.
- Decipher writes `?` when the XOR key cannot recover a lamp. Group in fives keeps that mark, and the status line says what it means.

## 1.0.0 (build 1)

- Historical Kriegsmarine / Heer Enigma. M3 uses rotors I–VIII, UKW-B or UKW-C, and up to ten plugboard pairs. M4 adds a static Beta or Gamma rotor and UKW-B Thin or UKW-C Thin.
- Wirings, notch letters, identity entry wheel, and the pawl-and-ratchet double-step match the wartime machine. Beta at A with UKW-B Thin matches M3 with UKW-B.
- The one non-historical step is the XOR-Schlüssel. After the lamp, the letter index (A = 0) is XORed with the next key letter. Results 26–31 are the digits 2–7. An empty key is historical Enigma.
- Encipher is rotors then XOR. Decipher is XOR then rotors. They coincide only when the XOR key is empty or all A’s.
- Self-test covers `AAAAA → BDZGO`, XOR key Z → `Y2A7X`, the double-step, the 1942 U-264 message, the 1943 Scharnhorst intercept, and the 1 May 1945 Dönitz indicator `QEOB → CDSZ`.
- Settings sheets and codebooks record the XOR key. A Classic Enigma sheet with no XOR line imports as historical Enigma.
