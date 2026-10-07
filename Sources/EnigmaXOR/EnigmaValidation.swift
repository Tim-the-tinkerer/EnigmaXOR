import Foundation

enum EnigmaValidationError: LocalizedError {
    case invalidRotorCount(mode: EnigmaMode, expected: Int, actual: Int)
    case unknownRotor(String)
    case duplicateRotor(String)
    case invalidReflector(String)
    case incompatibleReflector(String)
    case invalidRingLength(expected: Int)
    case invalidPositionLength(expected: Int)
    case invalidRingCharacter(Character)
    case invalidPositionCharacter(Character)
    case invalidPlugPair(String)
    case tooManyPlugPairs(Int)
    case duplicatePlugLetter(Character)
    case invalidM4GreekRotor(String)
    case invalidXORKey(Character)
    case xorKeyTooLong(Int)
    case emptySettings
    case unreadableSettings(String)

    var errorDescription: String? {
        switch self {
        case .invalidRotorCount(let mode, let expected, let actual):
            return "\(mode.rawValue.uppercased()) mode requires \(expected) rotors, but \(actual) were provided."
        case .unknownRotor(let name):
            return "Unknown rotor: \(name). Valid rotors are I–VIII, Beta, and Gamma."
        case .duplicateRotor(let name):
            return "Rotor \(name) is used more than once. Each rotor can appear only once."
        case .invalidReflector(let name):
            return "Unknown reflector: \(name)."
        case .incompatibleReflector(let explanation):
            return explanation
        case .invalidRingLength(let expected):
            return "Ring settings must contain exactly \(expected) letters (A–Z)."
        case .invalidPositionLength(let expected):
            return "Starting positions must contain exactly \(expected) letters (A–Z)."
        case .invalidRingCharacter(let letter):
            return "Ring settings may only contain letters A–Z. Invalid character: \(letter)."
        case .invalidPositionCharacter(let letter):
            return "Starting positions may only contain letters A–Z. Invalid character: \(letter)."
        case .invalidPlugPair(let pair):
            return "Invalid plugboard pair: \(pair). Each pair must be two distinct letters."
        case .tooManyPlugPairs(let count):
            return "The plugboard supports at most 10 pairs, but \(count) were provided."
        case .duplicatePlugLetter(let letter):
            return "Letter \(letter) appears in more than one plugboard pair."
        case .invalidM4GreekRotor(let name):
            return "M4 mode requires Beta or Gamma as the leftmost rotor, not \(name)."
        case .invalidXORKey(let character):
            return "XOR-Schlüssel may only contain letters A–Z. Invalid character: \(character)."
        case .xorKeyTooLong(let count):
            return "XOR-Schlüssel is limited to 32 letters, but \(count) were provided."
        case .emptySettings:
            return "No machine settings found in that file."
        case .unreadableSettings(let detail):
            return "Could not read machine settings: \(detail)"
        }
    }
}

enum EnigmaValidation {
    static let rotorNames: Set<String> = [
        "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "Beta", "Gamma"
    ]

    static let reflectorNames: Set<String> = ["B", "C", "B-Thin", "C-Thin"]

    static let greekRotors: Set<String> = ["Beta", "Gamma"]

    static func normalizeRotorName(_ name: String) -> String {
        normalizeRotorName(name, greekSlot: false)
    }

    /// `b`/`c` mean Beta/Gamma only when they are the Greek (leftmost M4) slot.
    static func normalizeRotorName(_ name: String, greekSlot: Bool) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if greekSlot {
            switch trimmed.lowercased() {
            case "beta", "β", "b": return "Beta"
            case "gamma", "γ", "c": return "Gamma"
            default: break
            }
        }
        switch trimmed.lowercased() {
        case "beta", "β": return "Beta"
        case "gamma", "γ": return "Gamma"
        default: return trimmed.uppercased()
        }
    }

    static func validate(_ configuration: EnigmaConfiguration) throws -> EnigmaConfiguration {
        var config = configuration.normalized
        config.rotorNames = config.rotorNames.enumerated().map { index, name in
            normalizeRotorName(name, greekSlot: config.mode == .m4 && index == 0)
        }
        let expectedRotors = config.mode == .m3 ? 3 : 4

        guard config.rotorNames.count == expectedRotors else {
            throw EnigmaValidationError.invalidRotorCount(
                mode: config.mode,
                expected: expectedRotors,
                actual: config.rotorNames.count
            )
        }

        var seenRotors = Set<String>()
        for name in config.rotorNames {
            guard rotorNames.contains(name) else {
                throw EnigmaValidationError.unknownRotor(name)
            }
            guard seenRotors.insert(name).inserted else {
                throw EnigmaValidationError.duplicateRotor(name)
            }
        }

        if config.mode == .m4 {
            guard let first = config.rotorNames.first, greekRotors.contains(first) else {
                throw EnigmaValidationError.invalidM4GreekRotor(config.rotorNames.first ?? "")
            }
        }

        guard reflectorNames.contains(config.reflector) else {
            throw EnigmaValidationError.invalidReflector(config.reflector)
        }

        if config.mode == .m3 && ["B-Thin", "C-Thin"].contains(config.reflector) {
            throw EnigmaValidationError.incompatibleReflector("\(config.reflector) requires M4 mode.")
        }
        if config.mode == .m4 && ["B", "C"].contains(config.reflector) {
            throw EnigmaValidationError.incompatibleReflector(
                "\(config.reflector) is a wide reflector. M4 requires UKW-B Thin or UKW-C Thin."
            )
        }

        try validateLetterSettings(
            config.rings,
            expected: expectedRotors,
            invalidCharacter: EnigmaValidationError.invalidRingCharacter,
            invalidLength: EnigmaValidationError.invalidRingLength
        )
        try validateLetterSettings(
            config.positions,
            expected: expectedRotors,
            invalidCharacter: EnigmaValidationError.invalidPositionCharacter,
            invalidLength: EnigmaValidationError.invalidPositionLength
        )

        try validatePlugPairs(config.plugPairs)
        config.xorKey = try normalizeXORKey(config.xorKey)
        return config
    }

    /// Empty, "—", and spaces are no XOR. Other characters must be A–Z.
    static func normalizeXORKey(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" || trimmed == "-" { return "" }
        if trimmed.uppercased() == "NONE" { return "" }
        var letters = ""
        for character in trimmed.uppercased() {
            if character == " " || character == "-" || character == "_" { continue }
            guard character >= "A", character <= "Z" else {
                throw EnigmaValidationError.invalidXORKey(character)
            }
            letters.append(character)
        }
        guard letters.count <= 32 else {
            throw EnigmaValidationError.xorKeyTooLong(letters.count)
        }
        return letters
    }

    static func validatePlugPairs(_ pairs: [String]) throws {
        guard pairs.count <= 10 else {
            throw EnigmaValidationError.tooManyPlugPairs(pairs.count)
        }

        var used = Set<Character>()
        for pair in pairs {
            let letters = pair.uppercased().filter(\.isLetter)
            guard letters.count == 2 else {
                throw EnigmaValidationError.invalidPlugPair(pair)
            }

            let chars = Array(letters)
            guard chars[0] != chars[1] else {
                throw EnigmaValidationError.invalidPlugPair(pair)
            }

            for char in chars {
                guard used.insert(char).inserted else {
                    throw EnigmaValidationError.duplicatePlugLetter(char)
                }
            }
        }
    }

    static func parsePlugPairTokens(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }

    private static func validateLetterSettings(
        _ value: String,
        expected: Int,
        invalidCharacter: (Character) -> EnigmaValidationError,
        invalidLength: (Int) -> EnigmaValidationError
    ) throws {
        let uppercased = value.uppercased()
        guard uppercased.count == expected else {
            throw invalidLength(expected)
        }

        for character in uppercased {
            guard character.isLetter, character.isASCII, character >= "A", character <= "Z" else {
                throw invalidCharacter(character)
            }
        }
    }
}
