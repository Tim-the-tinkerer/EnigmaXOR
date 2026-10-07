import Foundation

enum EnigmaMode: String, Codable {
    case m3
    case m4
}

/// Classic M3 / M4 Naval machine settings, plus the XOR-Schlüssel.
/// Rotor field names match EnigmaVault's classic configuration object, so a
/// Vault `configuration` JSON blob can be imported (missing `xorKey` means
/// none). This app never wraps ciphertext in an archive.
struct EnigmaConfiguration: Codable, Equatable {
    var mode: EnigmaMode
    var rotorNames: [String]
    var reflector: String
    var rings: String
    var positions: String
    var plugPairs: [String]
    /// A–Z Stichwort applied as a bitwise XOR after the lamp. Empty is historical Enigma.
    var xorKey: String

    init(
        mode: EnigmaMode,
        rotorNames: [String],
        reflector: String,
        rings: String,
        positions: String,
        plugPairs: [String],
        xorKey: String = ""
    ) {
        self.mode = mode
        self.rotorNames = rotorNames
        self.reflector = reflector
        self.rings = rings
        self.positions = positions
        self.plugPairs = plugPairs
        self.xorKey = xorKey
    }

    enum CodingKeys: String, CodingKey {
        case mode, rotorNames, reflector, rings, positions, plugPairs, xorKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(EnigmaMode.self, forKey: .mode)
        rotorNames = try container.decode([String].self, forKey: .rotorNames)
        reflector = try container.decode(String.self, forKey: .reflector)
        rings = try container.decode(String.self, forKey: .rings)
        positions = try container.decode(String.self, forKey: .positions)
        plugPairs = try container.decode([String].self, forKey: .plugPairs)
        xorKey = try container.decodeIfPresent(String.self, forKey: .xorKey) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(rotorNames, forKey: .rotorNames)
        try container.encode(reflector, forKey: .reflector)
        try container.encode(rings, forKey: .rings)
        try container.encode(positions, forKey: .positions)
        try container.encode(plugPairs, forKey: .plugPairs)
        try container.encode(xorKey, forKey: .xorKey)
    }

    /// M4 preset used at launch. Rotors are a full naval set; UBOATNINETYSIX is the XOR-Schlüssel.
    static let maximumSecurity = EnigmaConfiguration(
        mode: .m4,
        rotorNames: ["Gamma", "VIII", "IV", "I"],
        reflector: "C-Thin",
        rings: "RNCT",
        positions: "JWMQ",
        plugPairs: ["AZ", "BY", "CX", "DW", "EV", "FU", "GT", "HS", "IR", "JQ"],
        xorKey: "UBOATNINETYSIX"
    )

    static func `default`(mode: EnigmaMode = .m4) -> EnigmaConfiguration {
        switch mode {
        case .m3:
            return EnigmaConfiguration(
                mode: .m3,
                rotorNames: ["I", "II", "III"],
                reflector: "B",
                rings: "AAA",
                positions: "AAA",
                plugPairs: []
            )
        case .m4:
            return maximumSecurity
        }
    }

    /// Canonical wiki / textbook vector (Enigma I / M3).
    static let wikiTestVector = EnigmaConfiguration(
        mode: .m3,
        rotorNames: ["I", "II", "III"],
        reflector: "B",
        rings: "AAA",
        positions: "AAA",
        plugPairs: []
    )

    var normalized: EnigmaConfiguration {
        var copy = self
        copy.rings = copy.rings.uppercased()
        copy.positions = copy.positions.uppercased()
        copy.plugPairs = copy.plugPairs.map { $0.uppercased() }
        copy.xorKey = String(copy.xorKey.uppercased().filter { $0 >= "A" && $0 <= "Z" })
        return copy
    }

    func validated() throws -> EnigmaConfiguration {
        try EnigmaValidation.validate(self)
    }
}

final class EnigmaMachine {
    private struct Rotor {
        let forward: [Int]
        let reverse: [Int]
        let notchMask: UInt32
    }

    /// Historical wirings (Ringstellung A). Turnover letters are the window
    /// letter when the notch engages the stepping lever.
    private static let rotorData: [String: (wiring: String, notch: String)] = [
        "I": ("EKMFLGDQVZNTOWYHXUSPAIBRCJ", "Q"),
        "II": ("AJDKSIRUXBLHWTMCQGZNPYFVOE", "E"),
        "III": ("BDFHJLCPRTXVZNYEIWGAKMUSQO", "V"),
        "IV": ("ESOVPZJAYQUIRHXLNFTGKDCMWB", "J"),
        "V": ("VZBRGITYUPSDNHLXAWMJQOFECK", "Z"),
        "VI": ("JPGVOUMFYQBENHZRDKASXLICTW", "ZM"),
        "VII": ("NZJHGRCXMYSWBOUFAIVLPEKQDT", "ZM"),
        "VIII": ("FKQHTLXOCBJSPDZRAMEWNIUYGV", "ZM"),
        "Beta": ("LEYJVCNIXWPBQMDRTAKZGFUHOS", ""),
        "Gamma": ("FSOKANUERHMBTIYCWLQPZXVGJD", "")
    ]

    private static let reflectorData: [String: String] = [
        "B": "YRUHQSLDPXNGOKMIEBFZCWVJAT",
        "C": "FVPJIAOYEDRZXWGCTKUQSBNMHL",
        "B-Thin": "ENKQAUYWJICOPBLMDXZVFTHRGS",
        "C-Thin": "RDOBJNTKVEHMLFCWZAXGYIPSUQ"
    ]

    private var mode: EnigmaMode
    private var rotorNames: [String]
    private var reflectorName: String
    private var rotors: [Rotor] = []
    private var reflector: [Int] = []
    private var rings: [Int] = []
    private var positions: [Int] = []
    private var plugboard: [Int] = Array(0..<26)
    /// 0-based Stichwort indices. Empty means XOR with 0 (historical Enigma).
    private var xorKey: [Int] = []

    init(configuration: EnigmaConfiguration) throws {
        let config = try configuration.validated()
        mode = config.mode
        rotorNames = config.rotorNames
        reflectorName = config.reflector
        reset(
            rotorNames: config.rotorNames,
            reflector: config.reflector,
            rings: config.rings,
            positions: config.positions
        )
        try setPlugboard(pairs: config.plugPairs)
        xorKey = config.xorKey.map(Self.charToIndex)
    }

    func reset(
        rotorNames: [String],
        reflector reflectorKey: String,
        rings: String,
        positions: String
    ) {
        self.rotorNames = rotorNames
        rotors = rotorNames.map { Self.makeRotor(name: $0) }

        guard let refData = Self.reflectorData[reflectorKey] else {
            preconditionFailure("Invalid reflector after validation: \(reflectorKey)")
        }
        reflectorName = reflectorKey
        self.reflector = refData.map(Self.charToIndex)

        self.rings = Self.lettersToIndices(rings)
        self.positions = Self.lettersToIndices(positions)
    }

    func setPlugboard(pairs: [String]) throws {
        try EnigmaValidation.validatePlugPairs(pairs)
        plugboard = Array(0..<26)
        for pair in pairs {
            let letters = pair.uppercased().filter(\.isLetter)
            let chars = Array(letters)
            let a = Self.charToIndex(chars[0])
            let b = Self.charToIndex(chars[1])
            plugboard[a] = b
            plugboard[b] = a
        }
    }

    func currentPositions() -> String {
        positions.map(Self.indexToChar).map(String.init).joined()
    }

    /// One letter through encipher, including the XOR. The Schlüssel index is 0.
    func encryptLetter(_ character: Character) -> Character {
        let encoded = encipherMessage(String(character))
        return encoded.first ?? character
    }

    /// Encipher A–Z. Non-letters are skipped. With an empty XOR-Schlüssel this is
    /// historical Enigma (an involution). With a Schlüssel the lamp index is
    /// XORed and the result may be a digit 2–7.
    func processMessage(_ text: String) -> String {
        encipherMessage(text)
    }

    func encipherMessage(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var result = ""
        result.reserveCapacity(text.count)
        var ordinal = 0
        for character in text {
            guard let plain = Self.letterIndex(character) else { continue }
            let lamp = encryptLetterIndex(plain)
            let mixed = lamp ^ xorMask(at: ordinal)
            ordinal += 1
            result.append(EnigmaText.symbol(forMixed: mixed))
        }
        return result
    }

    /// Reverse of `encipherMessage`. XOR comes off first, then the same rotor pass.
    /// A recovered lamp above 25 (wrong Schlüssel) steps the rotors and writes `?`.
    func decipherMessage(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var result = ""
        result.reserveCapacity(text.count)
        var ordinal = 0
        for character in text {
            guard let mixed = EnigmaText.mixedValue(of: character) else { continue }
            let lamp = mixed ^ xorMask(at: ordinal)
            ordinal += 1
            if lamp > 25 {
                step()
                result.append("?")
                continue
            }
            result.append(Self.indexToChar(encryptLetterIndex(lamp)))
        }
        return result
    }

    private func xorMask(at ordinal: Int) -> Int {
        guard !xorKey.isEmpty else { return 0 }
        return xorKey[ordinal % xorKey.count]
    }

    /// Military Eintrittswalze is the identity, so the signal enters the right-hand
    /// rotor directly. Stepping happens before the wiring, as on the real machine.
    private func encryptLetterIndex(_ signal: Int) -> Int {
        var value = plugboard[signal]
        step()
        for index in stride(from: rotors.count - 1, through: 0, by: -1) {
            value = applyRotor(value, rotor: rotors[index], position: positions[index], ring: rings[index], forward: true)
        }
        value = reflector[value]
        for index in 0..<rotors.count {
            value = applyRotor(value, rotor: rotors[index], position: positions[index], ring: rings[index], forward: false)
        }
        return plugboard[value]
    }

    /// Historical pawl-and-ratchet stepping, including the middle-rotor double-step.
    /// On M4 the Greek (leftmost) rotor does not step.
    private func step() {
        let count = rotors.count
        guard count > 0 else { return }

        let stepStart = mode == .m4 ? 1 : 0

        let rightIndex = count - 1
        let middleIndex = count - 2
        let leftIndex = count - 3

        let rightPosition = positions[rightIndex]
        let middlePosition = middleIndex >= stepStart ? positions[middleIndex] : -1

        let stepMiddle = (rotors[rightIndex].notchMask & (1 << UInt32(rightPosition))) != 0
        let stepLeft = middleIndex >= stepStart
            && (rotors[middleIndex].notchMask & (1 << UInt32(middlePosition))) != 0

        positions[rightIndex] = (rightPosition + 1) % 26

        if stepMiddle, middleIndex >= stepStart {
            positions[middleIndex] = (middlePosition + 1) % 26
        }

        if stepMiddle && stepLeft, leftIndex >= stepStart {
            positions[leftIndex] = (positions[leftIndex] + 1) % 26
        } else if stepLeft && !stepMiddle, middleIndex >= stepStart, leftIndex >= stepStart {
            positions[leftIndex] = (positions[leftIndex] + 1) % 26
            positions[middleIndex] = (positions[middleIndex] + 1) % 26
        }
    }

    private func applyRotor(_ value: Int, rotor: Rotor, position: Int, ring: Int, forward: Bool) -> Int {
        let offset = (position - ring + 26) % 26
        var signal = (value + offset) % 26
        signal = forward ? rotor.forward[signal] : rotor.reverse[signal]
        return (signal - offset + 26) % 26
    }

    private static func makeRotor(name: String) -> Rotor {
        guard let data = rotorData[name] else {
            preconditionFailure("Invalid rotor name after validation: \(name)")
        }
        let forward = data.wiring.map(charToIndex)
        var reverse = Array(repeating: 0, count: 26)
        for (input, output) in forward.enumerated() {
            reverse[output] = input
        }

        var notchMask: UInt32 = 0
        for character in data.notch {
            notchMask |= 1 << UInt32(charToIndex(character))
        }
        return Rotor(forward: forward, reverse: reverse, notchMask: notchMask)
    }

    private static func lettersToIndices(_ value: String) -> [Int] {
        value.uppercased().map(charToIndex)
    }

    private static func letterIndex(_ character: Character) -> Int? {
        guard character.isASCII,
              let value = character.uppercased().first?.asciiValue,
              let base = Character("A").asciiValue,
              value >= base, value < base + 26 else {
            return nil
        }
        return Int(value - base)
    }

    private static func charToIndex(_ character: Character) -> Int {
        letterIndex(character) ?? 0
    }

    private static func indexToChar(_ index: Int) -> Character {
        Character(UnicodeScalar(65 + UInt8(index % 26)))
    }
}

struct EnigmaSelfTestFailure {
    let name: String
    let expected: String
    let actual: String
}

enum EnigmaSelfTest {
    static func run() -> [EnigmaSelfTestFailure] {
        var failures: [EnigmaSelfTestFailure] = []
        failures.append(contentsOf: CodebookRecoveryRegression.run())

        func check(_ name: String, _ actual: String, _ expected: String) {
            if actual != expected {
                failures.append(EnigmaSelfTestFailure(name: name, expected: expected, actual: actual))
            }
        }

        func process(_ config: EnigmaConfiguration, _ text: String) -> String {
            guard let machine = try? EnigmaMachine(configuration: config) else {
                return "<init failed>"
            }
            return machine.processMessage(text)
        }

        // Canonical smoke test used by EnigmaVault and textbook simulators.
        check(
            "wiki AAAAA → BDZGO",
            process(.wikiTestVector, "AAAAA"),
            "BDZGO"
        )
        check(
            "wiki HELLOWORLD → ILBDAAMTAZ",
            process(.wikiTestVector, "HELLOWORLD"),
            "ILBDAAMTAZ"
        )

        // Reciprocal: same settings restore the plaintext.
        let cipher = process(.wikiTestVector, "HELLOWORLD")
        check("round-trip HELLOWORLD", process(.wikiTestVector, cipher), "HELLOWORLD")

        // No letter ever encrypts to itself (reflector property).
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let mapped = process(.wikiTestVector, alphabet)
        if mapped.count == 26 {
            for (a, b) in zip(alphabet, mapped) where a == b {
                failures.append(EnigmaSelfTestFailure(
                    name: "no self-encryption",
                    expected: "no letter maps to itself",
                    actual: "\(a) → \(b)"
                ))
            }
        } else {
            check("alphabet length", mapped, alphabet)
        }

        // Ring setting on the fast rotor shifts the first output.
        var ringShift = EnigmaConfiguration.wikiTestVector
        ringShift.rings = "AAB"
        check("right ring 02: AAAAA → UBDZG", process(ringShift, "AAAAA"), "UBDZG")

        // UKW-C on the same default machine.
        var ukwC = EnigmaConfiguration.wikiTestVector
        ukwC.reflector = "C"
        check("UKW-C AAAAA → PJBUZ", process(ukwC, "AAAAA"), "PJBUZ")

        // Double-step: III turnover V, II turnover E.
        // Start ADU → after 1: ADV; after 2: AEW; after 3: BFX.
        do {
            let config = EnigmaConfiguration(
                mode: .m3,
                rotorNames: ["I", "II", "III"],
                reflector: "B",
                rings: "AAA",
                positions: "ADU",
                plugPairs: []
            )
            let machine = try EnigmaMachine(configuration: config)
            _ = machine.processMessage("A")
            check("double-step after 1", machine.currentPositions(), "ADV")
            _ = machine.processMessage("A")
            check("double-step after 2", machine.currentPositions(), "AEW")
            _ = machine.processMessage("A")
            check("double-step after 3", machine.currentPositions(), "BFX")
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "double-step setup",
                expected: "machine",
                actual: error.localizedDescription
            ))
        }

        // M4 with Beta at A + thin B is electrically identical to M3 UKW-B.
        let m3 = process(.wikiTestVector, "HELLOWORLD")
        let m4Compat = EnigmaConfiguration(
            mode: .m4,
            rotorNames: ["Beta", "I", "II", "III"],
            reflector: "B-Thin",
            rings: "AAAA",
            positions: "AAAA",
            plugPairs: []
        )
        check("M4 Beta/A + UKW-B thin ≡ M3 UKW-B", process(m4Compat, "HELLOWORLD"), m3)

        // Default M4 preset round-trip. XOR makes encipher and decipher different passes.
        do {
            let machine = try EnigmaMachine(configuration: .maximumSecurity)
            let plain = EnigmaText.letters(from: "Attack at dawn. Ägypten ß.")
            let cipherText = machine.encipherMessage(plain)
            check("M4 Greek rotor stays put", String(machine.currentPositions().prefix(1)), "J")
            let machine2 = try EnigmaMachine(configuration: .maximumSecurity)
            check("M4 preset round-trip", machine2.decipherMessage(cipherText), plain)
            var bare = EnigmaConfiguration.maximumSecurity
            bare.xorKey = ""
            let historical = process(bare, plain)
            if historical == cipherText {
                failures.append(EnigmaSelfTestFailure(
                    name: "M4 XOR changes the ciphertext",
                    expected: "different from historical lamps",
                    actual: cipherText
                ))
            }
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "M4 preset",
                expected: "round-trip",
                actual: error.localizedDescription
            ))
        }

        // XOR is the only non-historical step. Key letter A is XOR 0.
        var xorB = EnigmaConfiguration.wikiTestVector
        xorB.xorKey = "B"
        check("XOR B: AAAAA → ACYHP", process(xorB, "AAAAA"), "ACYHP")
        var xorA = EnigmaConfiguration.wikiTestVector
        xorA.xorKey = "AAAAA"
        check("XOR AAAAA equals no XOR", process(xorA, "AAAAA"), "BDZGO")
        var xorZ = EnigmaConfiguration.wikiTestVector
        xorZ.xorKey = "Z"
        check("XOR Z overflows into 2–7", process(xorZ, "AAAAA"), "Y2A7X")
        var xorBQ = EnigmaConfiguration.wikiTestVector
        xorBQ.xorKey = "BQ"
        check("XOR BQ repeats across the message", process(xorBQ, "AAAAA"), "ATYWP")
        do {
            let enciphered = process(xorZ, "AAAAA")
            let machine = try EnigmaMachine(configuration: xorZ)
            check("XOR Z decipher", machine.decipherMessage(enciphered), "AAAAA")
            let grouped = EnigmaText.grouped(enciphered)
            let symbols = EnigmaText.cipherSymbols(from: grouped)
            check("XOR symbols survive grouping", symbols, "Y2A7X")
            let dropped = EnigmaText.letters(from: enciphered)
            check("letter filter drops XOR digits", dropped, "YAX")
            let wrongKey = EnigmaConfiguration.wikiTestVector
            let recovered = try EnigmaMachine(configuration: wrongKey).decipherMessage("Y2A7X")
            if !recovered.contains("?") {
                failures.append(EnigmaSelfTestFailure(
                    name: "wrong XOR writes ?",
                    expected: "?",
                    actual: recovered
                ))
            }
            let shown = EnigmaText.grouped(recovered)
            if !shown.contains("?") {
                failures.append(EnigmaSelfTestFailure(
                    name: "grouping keeps wrong-XOR ?",
                    expected: "?",
                    actual: shown
                ))
            }
            check("grouped question marks stay in fives", EnigmaText.grouped("ABCD?EFGH"), "ABCD? EFGH")
            let again = process(xorB, "AAAAA")
            if process(xorB, again) == "AAAAA" {
                failures.append(EnigmaSelfTestFailure(
                    name: "XOR is not an involution",
                    expected: "encipher twice ≠ plaintext",
                    actual: "AAAAA"
                ))
            }
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "XOR round-trip",
                expected: "AAAAA",
                actual: error.localizedDescription
            ))
        }

        historicalMessages(check: check, failures: &failures)
        reflectorRules(check: check, failures: &failures)

        // Settings and codebook round-trip.
        do {
            let original = EnigmaConfiguration.maximumSecurity
            let settings = EnigmaSettings.exportSettings(original)
            let parsedSettings = try EnigmaSettings.parse(settings)
            if parsedSettings != original {
                failures.append(EnigmaSelfTestFailure(
                    name: "settings round-trip",
                    expected: original.summary,
                    actual: parsedSettings.summary
                ))
            }
            let codebook = EnigmaSettings.exportCodebook(original)
            let parsedBook = try EnigmaSettings.parse(codebook)
            if parsedBook != original {
                failures.append(EnigmaSelfTestFailure(
                    name: "codebook round-trip",
                    expected: original.summary,
                    actual: parsedBook.summary
                ))
            }
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "settings/codebook parse",
                expected: "parse ok",
                actual: error.localizedDescription
            ))
        }

        // Numeric Ringstellung 01 01 01 == AAA.
        do {
            let text = """
            Machine: M3
            UKW: B
            Walzenlage: I II III
            Ringstellung: 01 01 01
            Grundstellung: AAA
            Stecker:
            """
            let parsed = try EnigmaSettings.parse(text)
            check("numeric rings", parsed.rings, "AAA")
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "numeric rings",
                expected: "AAA",
                actual: error.localizedDescription
            ))
        }

        // Text prep: umlauts, ß, drop punctuation.
        check(
            "umlaut prep",
            EnigmaText.letters(from: "Über ß-Test!"),
            "UEBERSSTEST"
        )
        check(
            "group of five",
            EnigmaText.grouped("BDZGOWCXLT"),
            "BDZGO WCXLT"
        )
        check("digits dropped by default", EnigmaText.letters(from: "A1B"), "AB")
        check("spell 5", EnigmaText.letters(from: "5", spellNumbers: true), "FIVE")
        check("spell 42", EnigmaText.letters(from: "42", spellNumbers: true), "FORTYTWO")
        check("spell 21", EnigmaText.spellNumbers(in: "21"), "TWENTY ONE")
        check("spell 100", EnigmaText.letters(from: "100", spellNumbers: true), "ONEHUNDRED")
        check("spell 101", EnigmaText.letters(from: "101", spellNumbers: true), "ONEHUNDREDONE")
        check("spell 1942", EnigmaText.letters(from: "1942", spellNumbers: true), "ONETHOUSANDNINEHUNDREDFORTYTWO")
        check("spell 1,234", EnigmaText.letters(from: "1,234", spellNumbers: true), "ONETHOUSANDTWOHUNDREDTHIRTYFOUR")
        check("spell 007", EnigmaText.letters(from: "007", spellNumbers: true), "ZEROZEROSEVEN")
        check("spell 3.14", EnigmaText.letters(from: "3.14", spellNumbers: true), "THREEPOINTONEFOUR")
        check("spell -4", EnigmaText.letters(from: "-4", spellNumbers: true), "MINUSFOUR")
        check("spell space-minus", EnigmaText.letters(from: "lost -4", spellNumbers: true), "LOSTMINUSFOUR")
        check("spell paren-minus", EnigmaText.letters(from: "(-4)", spellNumbers: true), "MINUSFOUR")
        check(
            "spell date not minus",
            EnigmaText.letters(from: "2026-09-14", spellNumbers: true),
            "TWOTHOUSANDTWENTYSIXZERONINEFOURTEEN"
        )
        check(
            "spell phone not minus",
            EnigmaText.letters(from: "555-1234", spellNumbers: true),
            "FIVEHUNDREDFIFTYFIVEONETHOUSANDTWOHUNDREDTHIRTYFOUR"
        )
        check("spell n-1 not minus", EnigmaText.letters(from: "n-1", spellNumbers: true), "NONE")
        check("spell in sentence", EnigmaText.letters(from: "Attack at 5.", spellNumbers: true), "ATTACKATFIVE")
        check("spell time 12:30", EnigmaText.letters(from: "12:30", spellNumbers: true), "TWELVETHIRTY")
        check(
            "spell 1800 HOURS",
            EnigmaText.letters(from: "1800 HOURS", spellNumbers: true),
            "EIGHTEENHUNDREDHOURS"
        )
        check(
            "spell 1850 HOURS",
            EnigmaText.letters(from: "1850 HOURS", spellNumbers: true),
            "EIGHTEENHUNDREDANDFIFTYHOURS"
        )
        check(
            "spell 1800 without HOURS is thousands",
            EnigmaText.letters(from: "1800", spellNumbers: true),
            "ONETHOUSANDEIGHTHUNDRED"
        )
        check(
            "spell 0800 HOURS",
            EnigmaText.letters(from: "0800 HOURS", spellNumbers: true),
            "ZEROEIGHTHUNDREDHOURS"
        )
        check(
            "spell 1815 hours",
            EnigmaText.letters(from: "1815 hours", spellNumbers: true),
            "EIGHTEENHUNDREDANDFIFTEENHOURS"
        )
        check(
            "spell 1260 HOURS (invalid minutes, still hours path)",
            EnigmaText.letters(from: "1260 HOURS", spellNumbers: true),
            "TWELVEHUNDREDANDSIXTYHOURS"
        )
        check(
            "spell 2400 HOURS (hour 24, still hours path)",
            EnigmaText.letters(from: "2400 HOURS", spellNumbers: true),
            "TWENTYFOURHUNDREDHOURS"
        )
        check(
            "save name from cipher file",
            EnigmaOutputName.saveFilename(base: "Words of wisdom-cipher", deciphered: true),
            "Words of wisdom-decipher.txt"
        )
        check(
            "save name strips cipher-cipher",
            EnigmaOutputName.messageBase(from: "hello-cipher-cipher"),
            "hello"
        )
        check(
            "save name encipher",
            EnigmaOutputName.saveFilename(base: "hello", deciphered: false),
            "hello-cipher.txt"
        )
        check("cardinal 0", EnigmaText.cardinal(0), "ZERO")
        check("cardinal 1_000_000", EnigmaText.cardinal(1_000_000), "ONE MILLION")

        // EnigmaVault configuration JSON import.
        do {
            let json = """
            {"mode":"m4","rotorNames":["Gamma","VIII","IV","I"],"reflector":"C-Thin","rings":"RNCT","positions":"JWMQ","plugPairs":["AZ","BY","CX","DW","EV","FU","GT","HS","IR","JQ"]}
            """
            let parsed = try EnigmaSettings.parse(json)
            var expected = EnigmaConfiguration.maximumSecurity
            expected.xorKey = ""
            if parsed != expected {
                failures.append(EnigmaSelfTestFailure(
                    name: "vault JSON import",
                    expected: expected.summary,
                    actual: parsed.summary
                ))
            }
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "vault JSON import",
                expected: "parse ok",
                actual: error.localizedDescription
            ))
        }

        return failures
    }

    /// M4 is thin reflectors only. An unrecognized UKW name does not become B.
    private static func reflectorRules(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        func reject(_ name: String, _ config: EnigmaConfiguration, _ needle: String) {
            do {
                _ = try config.validated()
                failures.append(EnigmaSelfTestFailure(
                    name: name,
                    expected: needle,
                    actual: "accepted \(config.reflector)"
                ))
            } catch {
                let text = error.localizedDescription
                if !text.localizedCaseInsensitiveContains(needle) {
                    check(name, text, needle)
                }
            }
        }

        var wideB = EnigmaConfiguration.maximumSecurity
        wideB.reflector = "B"
        reject("M4 rejects wide UKW-B", wideB, "thin")
        var wideC = EnigmaConfiguration.maximumSecurity
        wideC.reflector = "C"
        reject("M4 rejects wide UKW-C", wideC, "thin")

        var thinOnM3 = EnigmaConfiguration.wikiTestVector
        thinOnM3.reflector = "B-Thin"
        reject("M3 rejects UKW-B Thin", thinOnM3, "M4")

        do {
            _ = try EnigmaSettings.parseReflector("UKW-B")
            check("parse UKW-B", try EnigmaSettings.parseReflector("UKW-B"), "B")
            check("parse UKW-C Thin", try EnigmaSettings.parseReflector("UKW-C Thin"), "C-Thin")
            check("parse B Dünn", try EnigmaSettings.parseReflector("B Dünn"), "B-Thin")
        } catch {
            failures.append(EnigmaSelfTestFailure(
                name: "parse known reflectors",
                expected: "B / C-Thin / B-Thin",
                actual: error.localizedDescription
            ))
        }

        func unknownReflector(_ raw: String) {
            let expected = "Unknown reflector: \(raw)."
            do {
                _ = try EnigmaSettings.parseReflector(raw)
                failures.append(EnigmaSelfTestFailure(
                    name: "\(raw) must not become UKW-B",
                    expected: expected,
                    actual: "accepted"
                ))
            } catch {
                check("unknown reflector \(raw)", error.localizedDescription, expected)
            }
        }
        unknownReflector("UKW-Z")
        unknownReflector("UKW Z")
        unknownReflector("Reflector Z")

        let sheet = """
        Machine: M4
        UKW: Z
        Walzenlage: Beta II IV I
        Ringstellung: A A A V
        Grundstellung: V J N A
        Stecker:
        """
        do {
            _ = try EnigmaSettings.parse(sheet)
            failures.append(EnigmaSelfTestFailure(
                name: "settings UKW-Z import",
                expected: "unknown reflector",
                actual: "imported"
            ))
        } catch {
            if !error.localizedDescription.localizedCaseInsensitiveContains("unknown reflector") {
                check("settings UKW-Z import", error.localizedDescription, "unknown reflector")
            }
        }
    }

    /// Published traffic. Rings written as German numbers are 01 = A.
    private static func historicalMessages(
        check: (String, String, String) -> Void,
        failures: inout [EnigmaSelfTestFailure]
    ) {
        func letters(_ text: String) -> String {
            String(text.uppercased().filter { $0 >= "A" && $0 <= "Z" })
        }

        func roundTrip(
            _ name: String,
            _ config: EnigmaConfiguration,
            cipher: String,
            plain: String
        ) {
            let expectedCipher = letters(cipher)
            let expectedPlain = letters(plain)
            do {
                let enciphered = try EnigmaMachine(configuration: config).encipherMessage(expectedPlain)
                check("\(name) encipher", enciphered, expectedCipher)
                let deciphered = try EnigmaMachine(configuration: config).decipherMessage(expectedCipher)
                check("\(name) decipher", deciphered, expectedPlain)
            } catch {
                failures.append(EnigmaSelfTestFailure(
                    name: "\(name) setup",
                    expected: "machine",
                    actual: error.localizedDescription
                ))
            }
        }

        // Kapitänleutnant Hartwig Looks, U-264, 1942. Beta does not step.
        roundTrip(
            "U-264",
            EnigmaConfiguration(
                mode: .m4,
                rotorNames: ["Beta", "II", "IV", "I"],
                reflector: "B-Thin",
                rings: "AAAV",
                positions: "VJNA",
                plugPairs: ["AT", "BL", "DF", "GJ", "HM", "NW", "OP", "QY", "RZ", "VX"]
            ),
            cipher: """
            NCZW VUSX PNYM INHZ XMQX SFWX WLKJ AHSH NMCO CCAK UQPM KCSM HKSE INJU SBLK \
            IOSX CKUB HMLL XCSJ USRR DVKO HULX WCCB GVLI YXEO AHXR HKKF VDRE WEZL XOBA \
            FGYU JQUK GRTV UKAM EURB VEKS UHHV OYHA BCJW MAKL FKLM YFVN RIZR VVRT KOFD \
            ANJM OLBG FFLE OPRG TFLV RHOW OPBE KVWM UQFM PWPA RMFH AGKX IIBG
            """,
            plain: """
            VONV ONJL OOKS JHFF TTTE INSE INSD REIZ WOYY QNNS NEUN INHA LTXX BEIA NGRI \
            FFUN TERW ASSE RGED RUEC KTYW ABOS XLET ZTER GEGN ERST ANDN ULAC HTDR EINU \
            LUHR MARQ UANT ONJO TANE UNAC HTSE YHSD REIY ZWOZ WONU LGRA DYAC HTSM YSTO \
            SSEN ACHX EKNS VIER MBFA ELLT YNNN NNNO OOVI ERYS ICHT EINS NULL
            """
        )

        // Scharnhorst, Konteradmiral Erich Bey, 1943. M3 with naval rotors VI and VIII.
        roundTrip(
            "Scharnhorst",
            EnigmaConfiguration(
                mode: .m3,
                rotorNames: ["III", "VI", "VIII"],
                reflector: "B",
                rings: "AHM",
                positions: "UZV",
                plugPairs: ["AN", "EZ", "HK", "IJ", "LR", "MQ", "OT", "PV", "SW", "UX"]
            ),
            cipher: "YKAEN ZAPMS CHZBF OCUVM RMDPY COFHA DZIZM EFXTH FLOLP ZLFGG BOTGO XGRET DWTJI QHLMX VJWKZ UASTR",
            plain: "STEUE REJTA NAFJO RDJAN STAND ORTQU AAACC CVIER NEUNN EUNZW OFAHR TZWON ULSMX XSCHA RNHOR STHCO"
        )

        // Indicator of the 1 May 1945 Dönitz message: grundstellung NAEM enciphers QEOB to CDSZ.
        roundTrip(
            "Dönitz indicator",
            EnigmaConfiguration(
                mode: .m4,
                rotorNames: ["Beta", "V", "VI", "VIII"],
                reflector: "C-Thin",
                rings: "EPEL",
                positions: "NAEM",
                plugPairs: ["AE", "BF", "CM", "DQ", "HU", "JN", "LX", "PR", "SZ", "VW"]
            ),
            cipher: "CDSZ",
            plain: "QEOB"
        )
    }

    static func passed() -> Bool {
        run().isEmpty
    }
}

extension EnigmaConfiguration {
    var summary: String {
        let plugs = plugPairs.isEmpty ? "—" : plugPairs.joined(separator: " ")
        let xor = xorKey.isEmpty ? "—" : xorKey
        return "\(mode.rawValue.uppercased()) UKW-\(reflector) \(rotorNames.joined(separator: "-")) rings \(rings) pos \(positions) stecker \(plugs) xor \(xor)"
    }
}
