import Foundation

/// Permanent regression: codebook rows where Ringstellung starts with **V** or **I**
/// (rotor names) and Stecker contains **IV** (also a rotor name) must parse as
/// four M4 wheels, then recover the original letter stream from grouped ciphertext.
///
/// The 1.2.0-era bug swallowed ring **V** as a fifth rotor (`M4 requires 4 rotors
/// but 5 were provided`) and made the sheet unusable. That is a total loss of
/// the message. `./build-app.sh` runs this via `--self-test`. Do not delete.
enum CodebookRecoveryRegression {
    /// Exact layout that failed in the wild (Words of wisdom-codebook.txt).
    static let vRingIVPlugSheet = """
    GEHEIM
    Schlüsseltafel
    Enigma M4  —  Kriegsmarine

    Tag   UKW      Walzenlage             Ringstellung   Steckerbrett                         Grundstellung
    ----  -------  ---------------------  -------------  -----------------------------------  --------------
       1  B-Thin   Gamma VII VIII VI      V U Q K        GA SK IV EL PN RD JH MO CB ZU        M A Y O

    Procedure
    1. Insert rotors left to right as listed (Zusatzwalze leftmost on M4).
    2. Set each alphabet ring to Ringstellung.
    3. Set the windows to Grundstellung before the first letter of the message.
    4. Fit the Steckerbrett pairs (at most ten).
    5. Type only letters. Umlauts become AE/OE/UE, ß becomes SS. Output is in five-letter groups.
    6. To decipher, restore these exact settings and type the ciphertext.

    Kenngruppen (identification only — not part of the cipher):  KYNK  TCTF  ZFLU  VQIZ
    """

    /// Ring **I** after rotors ending in **I**; stecker **VI** (also a wheel name).
    static let iRingVIPlugSheet = """
    GEHEIM
    Schlüsseltafel
    Enigma M4  —  Kriegsmarine

    Tag   UKW      Walzenlage             Ringstellung   Steckerbrett                         Grundstellung
    ----  -------  ---------------------  -------------  -----------------------------------  --------------
       1  C-Thin   Beta I II III          I V A A        AB CD EF GH VI JK LM NO PQ RS        A B C D
    """

    static let expectedVRingConfig = EnigmaConfiguration(
        mode: .m4,
        rotorNames: ["Gamma", "VII", "VIII", "VI"],
        reflector: "B-Thin",
        rings: "VUQK",
        positions: "MAYO",
        plugPairs: ["GA", "SK", "IV", "EL", "PN", "RD", "JH", "MO", "CB", "ZU"]
    )

    /// Long enough to wrap several five-letter groups; must survive encode → group → letters → decode.
    static let recoveryPlaintext = "THESECRETWISDOMOFTHISMESSAGEMUSTSURVIVEROUNDTRIP"

    static func run() -> [EnigmaSelfTestFailure] {
        var failures: [EnigmaSelfTestFailure] = []

        func check(_ name: String, _ actual: String, _ expected: String) {
            if actual != expected {
                failures.append(EnigmaSelfTestFailure(name: name, expected: expected, actual: actual))
            }
        }

        parseVRingIVPlug(check: check, failures: &failures)
        loadExampleFileIfPresent(check: check, failures: &failures)
        recoverOriginalLetterStream(check: check, failures: &failures)
        recoverThroughGroupedCipher(check: check, failures: &failures)
        exportImportThenRecover(check: check, failures: &failures)
        parseIRingVIPlug(check: check, failures: &failures)
        rejectFiveRotors(check: check, failures: &failures)

        return failures
    }

    // MARK: Parse

    private static func parseVRingIVPlug(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        do {
            let parsed = try EnigmaSettings.parse(vRingIVPlugSheet)
            check(
                "REGRESSION rotors must be 4 not 5 (V is a ring, not a wheel)",
                "\(parsed.rotorNames.count):\(parsed.rotorNames.joined(separator: "-"))",
                "4:Gamma-VII-VIII-VI"
            )
            check("REGRESSION rings VUQK", parsed.rings, "VUQK")
            check("REGRESSION windows MAYO", parsed.positions, "MAYO")
            check("REGRESSION UKW B-Thin", parsed.reflector, "B-Thin")
            check("REGRESSION mode m4", parsed.mode.rawValue, "m4")
            check(
                "REGRESSION stecker IV is a plug not rotor IV",
                parsed.plugPairs.contains("IV") ? "IV" : parsed.plugPairs.joined(separator: " "),
                "IV"
            )
            check(
                "REGRESSION full stecker",
                parsed.plugPairs.joined(separator: " "),
                expectedVRingConfig.plugPairs.joined(separator: " ")
            )
            if parsed.rotorNames.contains("V") {
                failures.append(EnigmaSelfTestFailure(
                    name: "REGRESSION rotor list must not include ring letter V",
                    expected: "Gamma VII VIII VI",
                    actual: parsed.rotorNames.joined(separator: " ")
                ))
            }
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION codebook parse (V-ring / IV-plug)",
                expected: "4 rotors Gamma-VII-VIII-VI",
                actual: error.localizedDescription
            ))
        }
    }

    private static func loadExampleFileIfPresent(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        let urls = exampleURLs()
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return
        }
        do {
            let disk = try String(contentsOf: url, encoding: .utf8)
            let fromDisk = try EnigmaSettings.parse(disk)
            let fromEmbedded = try EnigmaSettings.parse(vRingIVPlugSheet)
            check(
                "REGRESSION Examples/regression-v-ring-iv-plug-codebook.txt matches embedded sheet",
                fromDisk.summary,
                fromEmbedded.summary
            )
            check(
                "REGRESSION example file rotor count",
                "\(fromDisk.rotorNames.count)",
                "4"
            )
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION example codebook file",
                expected: "parse 4 rotors",
                actual: "\(url.path): \(error.localizedDescription)"
            ))
        }
    }

    // MARK: Recover original text

    private static func recoverOriginalLetterStream(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        do {
            let config = try EnigmaSettings.parse(vRingIVPlugSheet).validated()
            let enciphered = try EnigmaMachine(configuration: config).processMessage(recoveryPlaintext)
            let deciphered = try EnigmaMachine(configuration: config).processMessage(enciphered)
            check(
                "REGRESSION recover original letter stream",
                deciphered,
                recoveryPlaintext
            )
            if enciphered == recoveryPlaintext {
                failures.append(EnigmaSelfTestFailure(
                    name: "REGRESSION ciphertext must differ from plaintext",
                    expected: "scrambled",
                    actual: enciphered
                ))
            }
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION letter-stream recovery",
                expected: recoveryPlaintext,
                actual: error.localizedDescription
            ))
        }
    }

    /// Operator path: Encipher with Group in fives on, then Decipher the spaced groups.
    private static func recoverThroughGroupedCipher(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        do {
            let config = try EnigmaSettings.parse(vRingIVPlugSheet).validated()
            let cipher = try EnigmaMachine(configuration: config).processMessage(recoveryPlaintext)
            let grouped = EnigmaText.grouped(cipher)
            if !grouped.contains(" ") {
                failures.append(EnigmaSelfTestFailure(
                    name: "REGRESSION grouped ciphertext must contain spaces",
                    expected: "five-letter groups",
                    actual: grouped
                ))
            }
            let asDecipherInput = EnigmaText.letters(from: grouped, spellNumbers: false)
            check("REGRESSION grouped cipher strips to same letters", asDecipherInput, cipher)
            let recovered = try EnigmaMachine(configuration: config).processMessage(asDecipherInput)
            check(
                "REGRESSION recover original text from grouped ciphertext + codebook",
                recovered,
                recoveryPlaintext
            )
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION grouped-cipher recovery",
                expected: recoveryPlaintext,
                actual: error.localizedDescription
            ))
        }
    }

    private static func exportImportThenRecover(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        do {
            let exported = EnigmaSettings.exportCodebook(expectedVRingConfig)
            let imported = try EnigmaSettings.parse(exported).validated()
            check(
                "REGRESSION export/import rotor count",
                "\(imported.rotorNames.count)",
                "4"
            )
            check("REGRESSION export/import rotors", imported.rotorNames.joined(separator: "-"), "Gamma-VII-VIII-VI")
            check("REGRESSION export/import rings", imported.rings, "VUQK")
            check("REGRESSION export/import windows", imported.positions, "MAYO")
            check(
                "REGRESSION export/import IV plug",
                imported.plugPairs.contains("IV") ? "IV" : imported.plugPairs.joined(separator: " "),
                "IV"
            )
            let cipher = try EnigmaMachine(configuration: imported).processMessage(recoveryPlaintext)
            let recovered = try EnigmaMachine(configuration: imported).processMessage(cipher)
            check("REGRESSION recover after export/import codebook", recovered, recoveryPlaintext)
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION export/import recovery",
                expected: recoveryPlaintext,
                actual: error.localizedDescription
            ))
        }
    }

    private static func parseIRingVIPlug(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        do {
            let parsed = try EnigmaSettings.parse(iRingVIPlugSheet).validated()
            check(
                "REGRESSION I-ring rotors",
                "\(parsed.rotorNames.count):\(parsed.rotorNames.joined(separator: "-"))",
                "4:Beta-I-II-III"
            )
            check("REGRESSION I-ring rings", parsed.rings, "IVAA")
            check(
                "REGRESSION VI is a plug not a fifth rotor",
                parsed.plugPairs.contains("VI") ? "VI" : parsed.plugPairs.joined(separator: " "),
                "VI"
            )
            let plain = "RECOVERYCHECK"
            let cipher = try EnigmaMachine(configuration: parsed).processMessage(plain)
            let back = try EnigmaMachine(configuration: parsed).processMessage(cipher)
            check("REGRESSION I-ring / VI-plug recover", back, plain)
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION I-ring / VI-plug sheet",
                expected: "4 rotors Beta-I-II-III rings IVAA plug VI",
                actual: error.localizedDescription
            ))
        }
    }

    private static func rejectFiveRotors(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        let five = EnigmaConfiguration(
            mode: .m4,
            rotorNames: ["Gamma", "VII", "VIII", "VI", "V"],
            reflector: "B-Thin",
            rings: "VUQK",
            positions: "MAYO",
            plugPairs: expectedVRingConfig.plugPairs
        )
        do {
            _ = try five.validated()
            failures.append(EnigmaSelfTestFailure(
                name: "REGRESSION five-rotor M4 must not validate",
                expected: "invalidRotorCount",
                actual: "accepted \(five.rotorNames.joined(separator: "-"))"
            ))
        } catch {
            let text = error.localizedDescription
            if !text.localizedCaseInsensitiveContains("4") || !text.localizedCaseInsensitiveContains("5") {
                check(
                    "REGRESSION five-rotor error names the counts",
                    text,
                    "M4 mode requires 4 rotors, but 5 were provided."
                )
            }
        }
    }

    private static func exampleURLs() -> [URL] {
        let name = "regression-v-ring-iv-plug-codebook.txt"
        var urls: [URL] = []
        if let bundled = Bundle.main.url(forResource: "regression-v-ring-iv-plug-codebook", withExtension: "txt") {
            urls.append(bundled)
        }
        if let resources = Bundle.main.resourceURL {
            urls.append(resources.appendingPathComponent("Examples/\(name)"))
            urls.append(resources.appendingPathComponent(name))
        }
        let sourceRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        urls.append(sourceRoot.appendingPathComponent("Examples/\(name)"))
        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Examples/\(name)"))
        return urls
    }
}
