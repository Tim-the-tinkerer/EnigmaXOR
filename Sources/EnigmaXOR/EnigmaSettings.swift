import Foundation

/// Plain-text machine settings and a historical-style Schlüsselzettel.
/// Neither is a custom ciphertext format — both are human-readable key sheets
/// that this app can read back so a message can be deciphered later.
enum EnigmaSettings {
    static func exportSettings(_ configuration: EnigmaConfiguration) -> String {
        let config = configuration.normalized
        let plugs = config.plugPairs.isEmpty ? "—" : config.plugPairs.joined(separator: " ")
        let machine = config.mode == .m4 ? "M4" : "M3"
        let xor = config.xorKey.isEmpty ? "—" : config.xorKey
        return """
        Enigma XOR machine settings
        The rotors are a historical M3 or M4. XOR-Schlüssel is the one addition.
        Empty XOR means encipher and decipher are the same rotor pass. With a
        Schlüssel, encipher is rotors then XOR; decipher is XOR then rotors.
        Reset Grundstellung before each message.

        Machine:       \(machine)
        UKW:           \(config.reflector)
        Walzenlage:    \(config.rotorNames.joined(separator: " "))
        Ringstellung:  \(spacedLetters(config.rings))
        Grundstellung: \(spacedLetters(config.positions))
        Stecker:       \(plugs)
        XOR-Schlüssel: \(xor)
        """
    }

    static func exportCodebook(_ configuration: EnigmaConfiguration) -> String {
        let config = configuration.normalized
        let machine = config.mode == .m4 ? "M4  —  Kriegsmarine" : "M3  —  Kriegsmarine / Heer"
        let plugs = config.plugPairs.isEmpty ? "—" : config.plugPairs.joined(separator: " ")
        let walzen = config.rotorNames.joined(separator: " ")
        let rings = spacedLetters(config.rings)
        let grund = spacedLetters(config.positions)
        let kenngruppen = (0..<4).map { _ in randomGroup(length: 4) }.joined(separator: "  ")
        let xor = config.xorKey.isEmpty ? "—" : config.xorKey

        return """
        GEHEIM
        Schlüsseltafel
        Enigma XOR  \(machine)

        Tag   UKW      Walzenlage             Ringstellung   Steckerbrett                         Grundstellung
        ----  -------  ---------------------  -------------  -----------------------------------  --------------
           1  \(pad(config.reflector, 7))  \(pad(walzen, 21))  \(pad(rings, 13))  \(pad(plugs, 35))  \(grund)

        XOR-Schlüssel: \(xor)

        Procedure
        1. Insert rotors left to right as listed (Zusatzwalze leftmost on M4).
        2. Set each alphabet ring to Ringstellung.
        3. Set the windows to Grundstellung before the first letter of the message.
        4. Fit the Steckerbrett pairs (at most ten).
        5. Type only letters. Umlauts become AE/OE/UE, ß becomes SS. Output is in five-symbol groups.
        6. After the lamp, XOR the letter index (A = 0) with the next XOR-Schlüssel letter. Values 26–31 are written as digits 2–7.
        7. To decipher, restore these settings, XOR each ciphertext symbol first, then run the rotors.

        Kenngruppen (identification only — not part of the cipher):  \(kenngruppen)
        """
    }

    static func looksLikeSettings(_ text: String) -> Bool {
        let upper = text.uppercased()
        if upper.contains("WALZENLAGE") && (upper.contains("GRUNDSTELLUNG") || upper.contains("RINGSTELLUNG")) {
            return true
        }
        if upper.contains("MACHINE:") && (upper.contains("UKW") || upper.contains("REFLECTOR")) {
            return true
        }
        if upper.contains("SCHLÜSSELTAFEL") || upper.contains("SCHLUESSELTAFEL") || upper.contains("SCHLUSSELTAFEL") {
            return true
        }
        if let data = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           obj["rotorNames"] != nil, obj["mode"] != nil {
            return true
        }
        return false
    }

    static func parse(_ text: String) throws -> EnigmaConfiguration {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EnigmaValidationError.emptySettings }

        if let json = try parseJSON(trimmed) {
            return try json.validated()
        }

        if let fromTable = try parseCodebookTable(trimmed) {
            return try fromTable.validated()
        }

        return try parseLabeledSheet(trimmed).validated()
    }

    // MARK: JSON (EnigmaVault configuration object, for convenience)

    private static func parseJSON(_ text: String) throws -> EnigmaConfiguration? {
        let start = text.firstIndex(where: { $0 == "{" })
        guard let start else { return nil }
        let jsonText = String(text[start...])
        guard jsonText.contains("rotorNames") else { return nil }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(EnigmaConfiguration.self, from: Data(jsonText.utf8))
        } catch {
            throw EnigmaValidationError.unreadableSettings(error.localizedDescription)
        }
    }

    // MARK: Labeled sheet

    private static func parseLabeledSheet(_ text: String) throws -> EnigmaConfiguration {
        var machine: EnigmaMode?
        var reflector: String?
        var rotors: [String] = []
        var rings: String?
        var positions: String?
        var plugs: [String] = []
        var xorKey = ""
        var sawXOR = false
        var sawAny = false

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = normalizeKey(String(line[..<colon]))
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            switch key {
            case "machine", "mode", "modell", "model":
                machine = parseMachine(value)
                sawAny = true
            case "ukw", "reflector", "umkehrwalze", "ukwtype":
                reflector = try parseReflector(value)
                sawAny = true
            case "walzenlage", "rotors", "wheels", "walzen":
                rotors = parseRotors(value)
                sawAny = true
            case "ringstellung", "rings", "ring":
                rings = parseLetterField(value)
                sawAny = true
            case "grundstellung", "positions", "windows", "start", "grund":
                positions = parseLetterField(value)
                sawAny = true
            case "stecker", "steckerbrett", "plugboard", "plugs", "steckerverbindungen":
                plugs = parsePlugs(value)
                sawAny = true
            case "xor", "xorkey", "xorschlussel", "xorschluessel", "stichwort":
                xorKey = parseXORValue(value)
                sawXOR = true
                sawAny = true
            default:
                continue
            }
        }

        guard sawAny else {
            throw EnigmaValidationError.emptySettings
        }

        if machine == nil {
            machine = rotors.count == 4 ? .m4 : .m3
        }
        let mode = machine ?? .m3
        if rotors.isEmpty {
            throw EnigmaValidationError.unreadableSettings("missing Walzenlage")
        }
        if mode == .m4, let first = rotors.first {
            rotors[0] = EnigmaValidation.normalizeRotorName(first, greekSlot: true)
        }

        return EnigmaConfiguration(
            mode: mode,
            rotorNames: rotors,
            reflector: reflector ?? (mode == .m4 ? "B-Thin" : "B"),
            rings: rings ?? String(repeating: "A", count: rotors.count),
            positions: positions ?? String(repeating: "A", count: rotors.count),
            plugPairs: plugs,
            xorKey: sawXOR ? xorKey : xorKeyFromLabels(text)
        )
    }

    // MARK: Codebook table

    private static func parseCodebookTable(_ text: String) throws -> EnigmaConfiguration? {
        let upper = text.uppercased()
        guard upper.contains("WALZENLAGE") || upper.contains("SCHLUSSELTAFEL")
                || upper.contains("SCHLUESSELTAFEL") || text.localizedCaseInsensitiveContains("Schlüsseltafel") else {
            return nil
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Prefer labeled fields if present (exportCodebook also has Procedure text).
        if let labeled = try? parseLabeledSheet(text), !labeled.rotorNames.isEmpty {
            // Codebook export is table-only; fall through if we didn't get rotors from labels.
            if text.contains("Walzenlage:") || text.contains("WALZENLAGE:") {
                return labeled
            }
        }

        var machine: EnigmaMode = text.uppercased().contains("M3") && !text.uppercased().contains("M4") ? .m3 : .m4
        if text.uppercased().contains("M4") { machine = .m4 }
        if text.uppercased().contains("M3") && !text.uppercased().contains("M4") { machine = .m3 }

        for line in lines {
            if line.hasPrefix("----") || line.uppercased().hasPrefix("TAG") { continue }
            if line.uppercased().hasPrefix("GEHEIM") || line.uppercased().hasPrefix("PROCEDURE") { continue }
            if line.uppercased().hasPrefix("KENNGRUPPEN") { continue }
            if line.hasPrefix("1.") || line.hasPrefix("2.") || line.hasPrefix("3.")
                || line.hasPrefix("4.") || line.hasPrefix("5.") || line.hasPrefix("6.") {
                continue
            }

            // Data row starts with a day number.
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let first = tokens.first, Int(first) != nil, tokens.count >= 6 else { continue }

            // Tag, UKW, then exactly 3 (M3) or 4 (M4) rotors, then rings, plugs, grundstellung.
            // Stop at the expected count: ring letters I and V are also rotor names, and
            // plug pair IV would otherwise be swallowed as a fifth wheel.
            var i = 1
            guard i < tokens.count else { continue }
            let reflector = try parseReflector(tokens[i])
            i += 1

            let expectedRotors = machine == .m4 ? 4 : 3
            var rotors: [String] = []
            while i < tokens.count,
                  rotors.count < expectedRotors,
                  looksLikeRotorToken(tokens[i], greekSlot: rotors.isEmpty && machine == .m4) {
                rotors.append(tokens[i])
                i += 1
            }
            if rotors.isEmpty { continue }
            if rotors.count == 4 { machine = .m4 }
            if rotors.count == 3 { machine = .m3 }
            rotors = rotors.enumerated().map { index, name in
                EnigmaValidation.normalizeRotorName(name, greekSlot: machine == .m4 && index == 0)
            }

            let expected = rotors.count
            var ringTokens: [String] = []
            while i < tokens.count, ringTokens.count < expected, isLetterOrRingNumber(tokens[i]) {
                ringTokens.append(tokens[i])
                i += 1
            }
            let rings = parseLetterField(ringTokens.joined(separator: " "))

            var plugTokens: [String] = []
            while i < tokens.count, plugTokens.count < 10, isPlugToken(tokens[i]) {
                plugTokens.append(tokens[i])
                i += 1
            }
            // Remaining tokens are Grundstellung (letters, possibly spaced).
            let rest = Array(tokens[i...])
            let positions: String
            if rest.isEmpty {
                positions = String(repeating: "A", count: expected)
            } else if rest.count == 1, rest[0].count == expected {
                positions = rest[0].uppercased()
            } else {
                positions = parseLetterField(rest.joined(separator: " "))
            }

            return EnigmaConfiguration(
                mode: machine,
                rotorNames: rotors,
                reflector: reflector,
                rings: rings,
                positions: positions,
                plugPairs: parsePlugs(plugTokens.joined(separator: " ")),
                xorKey: xorKeyFromLabels(text)
            )
        }

        return nil
    }

    // MARK: Field parsers

    private static func parseMachine(_ value: String) -> EnigmaMode {
        let upper = value.uppercased()
        if upper.contains("M4") || upper.contains("NAVAL") { return .m4 }
        return .m3
    }

    /// Accepts `B`, `C`, `B-Thin`, `C-Thin`, with an optional UKW prefix and
    /// `Dünn` / `Duenn` for thin. Anything else, including `UKW-Z`, is an error.
    static func parseReflector(_ value: String) throws -> String {
        var compact = value.uppercased()
            .replacingOccurrences(of: "DÜNN", with: "THIN")
            .replacingOccurrences(of: "DUENN", with: "THIN")
            .replacingOccurrences(of: "DUNN", with: "THIN")
            .replacingOccurrences(of: "UMKEHRWALZE", with: "")
            .replacingOccurrences(of: "REFLECTOR", with: "")
            .replacingOccurrences(of: "UKW", with: "")
        compact = String(compact.filter(\.isLetter))

        switch compact {
        case "B": return "B"
        case "C": return "C"
        case "BTHIN", "THINB": return "B-Thin"
        case "CTHIN", "THINC": return "C-Thin"
        default:
            let shown = value.trimmingCharacters(in: .whitespacesAndNewlines)
            throw EnigmaValidationError.invalidReflector(shown.isEmpty ? "(empty)" : shown)
        }
    }

    static func parseRotors(_ value: String) -> [String] {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, token in
                EnigmaValidation.normalizeRotorName(token, greekSlot: index == 0)
            }
    }

    static func parseLetterField(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" || trimmed == "-" { return "" }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count > 1 {
            var letters = ""
            for token in tokens {
                if let number = Int(token), (1...26).contains(number) {
                    letters.append(Character(UnicodeScalar(64 + number)!))
                } else if token.count == 1, let ch = token.uppercased().first, ch >= "A", ch <= "Z" {
                    letters.append(ch)
                } else {
                    letters.append(contentsOf: token.uppercased().filter { $0 >= "A" && $0 <= "Z" })
                }
            }
            return letters
        }

        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        if let number = Int(compact), compact.count <= 2, (1...26).contains(number) {
            return String(Character(UnicodeScalar(64 + number)!))
        }
        return compact.uppercased().filter { $0 >= "A" && $0 <= "Z" }
    }

    static func parsePlugs(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" || trimmed == "-" { return [] }
        return EnigmaValidation.parsePlugPairTokens(trimmed)
    }

    static func parseXORValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" || trimmed == "-" { return "" }
        if trimmed.uppercased() == "NONE" { return "" }
        return trimmed
    }

    /// Reads an `XOR-Schlüssel:` line from a codebook that is otherwise a table.
    private static func xorKeyFromLabels(_ text: String) -> String {
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = normalizeKey(String(line[..<colon]))
            guard key == "xor" || key == "xorkey" || key == "xorschlussel"
                    || key == "xorschluessel" || key == "stichwort" else { continue }
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return parseXORValue(value)
        }
        return ""
    }

    private static func normalizeKey(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ß", with: "ss")
            .filter { $0.isLetter }
    }

    private static func looksLikeRotorToken(_ token: String, greekSlot: Bool = false) -> Bool {
        let name = EnigmaValidation.normalizeRotorName(token, greekSlot: greekSlot)
        return EnigmaValidation.rotorNames.contains(name)
    }

    private static func isLetterOrRingNumber(_ token: String) -> Bool {
        if let number = Int(token), (1...26).contains(number) { return true }
        let upper = token.uppercased()
        return upper.count == 1 && upper >= "A" && upper <= "Z"
    }

    private static func isPlugToken(_ token: String) -> Bool {
        let letters = token.uppercased().filter { $0 >= "A" && $0 <= "Z" }
        return letters.count == 2 && letters.first != letters.last
    }

    private static func spacedLetters(_ value: String) -> String {
        value.map(String.init).joined(separator: " ")
    }

    private static func pad(_ value: String, _ width: Int) -> String {
        if value.count >= width { return String(value.prefix(width)) }
        return value + String(repeating: " ", count: width - value.count)
    }

    private static func randomGroup(length: Int) -> String {
        String((0..<length).map { _ in Character(UnicodeScalar(65 + UInt8.random(in: 0..<26))) })
    }
}
