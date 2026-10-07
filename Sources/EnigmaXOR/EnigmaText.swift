import Foundation

enum EnigmaOutputName {
    /// `Words of wisdom-cipher` → `Words of wisdom` so saves do not become `…-cipher-cipher`.
    static func messageBase(from fileBase: String) -> String {
        var name = fileBase
        while true {
            let lowered = name.lowercased()
            if lowered.hasSuffix("-cipher") {
                name = String(name.dropLast("-cipher".count))
            } else if lowered.hasSuffix("-decipher") {
                name = String(name.dropLast("-decipher".count))
            } else {
                break
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "message" : trimmed
    }

    static func saveFilename(base: String, deciphered: Bool) -> String {
        "\(messageBase(from: base))-\(deciphered ? "decipher" : "cipher").txt"
    }
}

enum EnigmaText {
    /// Historical letter stream: optional English number words, umlauts expanded, ß → SS, everything else dropped.
    static func letters(from raw: String, spellNumbers: Bool = false) -> String {
        let source = spellNumbers ? Self.spellNumbers(in: raw) : raw
        var expanded = ""
        expanded.reserveCapacity(source.count * 2)
        for character in source {
            switch character {
            case "Ä", "ä": expanded.append("AE")
            case "Ö", "ö": expanded.append("OE")
            case "Ü", "ü": expanded.append("UE")
            case "ß": expanded.append("SS")
            default: expanded.append(character)
            }
        }

        var letters = ""
        letters.reserveCapacity(expanded.count)
        for character in expanded {
            guard character.isASCII else { continue }
            let upper = character.uppercased()
            guard let first = upper.first, first >= "A", first <= "Z" else { continue }
            letters.append(first)
        }
        return letters
    }

    /// Cipher alphabet: A–Z are XOR results 0–25, digits 2–7 are results 26–31.
    static let mixedAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    static func symbol(forMixed value: Int) -> Character {
        precondition((0..<32).contains(value), "XOR result out of range: \(value)")
        return mixedAlphabet[value]
    }

    static func mixedValue(of character: Character) -> Int? {
        guard let first = character.uppercased().first, let ascii = first.asciiValue else { return nil }
        if first >= "A" && first <= "Z" { return Int(ascii - 65) }
        if first >= "2" && first <= "7" { return 26 + Int(ascii - 50) }
        return nil
    }

    /// Ciphertext symbols only. Keeps A–Z and 2–7. Does not spell numbers.
    static func cipherSymbols(from raw: String) -> String {
        var symbols = ""
        symbols.reserveCapacity(raw.count)
        for character in raw {
            guard let value = mixedValue(of: character) else { continue }
            symbols.append(symbol(forMixed: value))
        }
        return symbols
    }

    /// Replace digit runs with English cardinal words before encoding.
    /// `42` → `FORTY TWO`, `3.14` → `THREE POINT ONE FOUR`, `007` → `ZERO ZERO SEVEN`.
    static func spellNumbers(in raw: String) -> String {
        let chars = Array(raw)
        var index = 0
        var output = ""

        while index < chars.count {
            let character = chars[index]
            if isMinusSign(character), index + 1 < chars.count, isDigit(chars[index + 1]) {
                let unary = isUnaryMinus(in: chars, at: index)
                let (words, consumed) = readNumber(chars, from: index + 1, negative: unary)
                appendSpelled(&output, words)
                index += 1 + consumed
                continue
            }
            if isDigit(character) {
                let (words, consumed) = readNumber(chars, from: index, negative: false)
                appendSpelled(&output, words)
                index += consumed
                continue
            }
            output.append(character)
            index += 1
        }
        return output
    }

    /// Groups ciphertext symbols. A deciphered `?` (XOR recovered 26–31) is kept
    /// so a wrong Schlüssel stays visible when Group in fives is on.
    static func grouped(_ symbols: String, size: Int = 5) -> String {
        var clean = ""
        clean.reserveCapacity(symbols.count)
        for character in symbols {
            if character == "?" {
                clean.append("?")
            } else if let value = mixedValue(of: character) {
                clean.append(symbol(forMixed: value))
            }
        }
        guard !clean.isEmpty else { return "" }
        var groups: [String] = []
        var current = ""
        for character in clean {
            current.append(character)
            if current.count == size {
                groups.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups.joined(separator: " ")
    }

    static func ungrouped(_ text: String) -> String {
        letters(from: text)
    }

    // MARK: Number scan

    private static func appendSpelled(_ output: inout String, _ words: String) {
        if !output.isEmpty, let last = output.last, !last.isWhitespace {
            output.append(" ")
        }
        output.append(words)
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character >= "0" && character <= "9"
    }

    private static func isMinusSign(_ character: Character) -> Bool {
        character == "-" || character == "−" || character == "–"
    }

    /// Unary minus only at the start of a token: string start, after whitespace,
    /// or after opening punctuation. `2026-09-14` and `555-1234` are not negative.
    private static func isUnaryMinus(in chars: [Character], at index: Int) -> Bool {
        if index == 0 { return true }
        let previous = chars[index - 1]
        if previous.isWhitespace { return true }
        switch previous {
        case "(", "[", "{", "<", "\"", "'", "“", "‘", "«":
            return true
        default:
            return false
        }
    }

    private static func readNumber(_ chars: [Character], from start: Int, negative: Bool) -> (String, Int) {
        var index = start
        var integerDigits = ""
        var sawComma = false
        var commaGroup = 0
        var commaValid = true

        while index < chars.count {
            let character = chars[index]
            if isDigit(character) {
                integerDigits.append(character)
                if sawComma { commaGroup += 1 }
                index += 1
                continue
            }
            if character == ",",
               index + 1 < chars.count,
               isDigit(chars[index + 1]),
               !integerDigits.isEmpty {
                if sawComma && commaGroup != 3 {
                    commaValid = false
                    break
                }
                sawComma = true
                commaGroup = 0
                index += 1
                continue
            }
            break
        }

        if sawComma && commaGroup != 3 {
            commaValid = false
        }
        if !commaValid {
            integerDigits = ""
            index = start
            while index < chars.count, isDigit(chars[index]) {
                integerDigits.append(chars[index])
                index += 1
            }
        }

        var fractionDigits = ""
        if index < chars.count,
           chars[index] == ".",
           index + 1 < chars.count,
           isDigit(chars[index + 1]) {
            index += 1
            while index < chars.count, isDigit(chars[index]) {
                fractionDigits.append(chars[index])
                index += 1
            }
        }

        let consumed = index - start
        var words: [String] = []
        if negative { words.append("MINUS") }
        if fractionDigits.isEmpty,
           !sawComma,
           let hours = spellHours(integerDigits),
           followedByHours(chars, at: index) {
            words.append(contentsOf: hours)
        } else {
            words.append(contentsOf: spellIntegerPart(integerDigits).split(separator: " ").map(String.init))
            if !fractionDigits.isEmpty {
                words.append("POINT")
                for digit in fractionDigits {
                    words.append(digitWord(digit))
                }
            }
        }
        return (words.joined(separator: " "), consumed)
    }

    /// `1800 HOURS` / `1850 hours` — clock digits, not a thousands cardinal.
    /// Leaves the word HOURS in the input for the main loop.
    private static func followedByHours(_ chars: [Character], at index: Int) -> Bool {
        var i = index
        while i < chars.count, chars[i].isWhitespace { i += 1 }
        var letters = ""
        while i < chars.count, chars[i].isLetter {
            letters.append(chars[i])
            i += 1
        }
        return letters.uppercased() == "HOURS"
    }

    /// 4-digit `HHMM` or 3-digit `HMM`. `1800` → EIGHTEEN HUNDRED;
    /// `1850` → EIGHTEEN HUNDRED AND FIFTY. Hour `08` → ZERO EIGHT.
    /// Does not check that the clock is valid: `1260 HOURS` is still
    /// TWELVE HUNDRED AND SIXTY; `2400 HOURS` is TWENTY FOUR HUNDRED.
    private static func spellHours(_ digits: String) -> [String]? {
        let hourDigits: String
        let minuteDigits: String
        if digits.count == 4 {
            hourDigits = String(digits.prefix(2))
            minuteDigits = String(digits.suffix(2))
        } else if digits.count == 3 {
            hourDigits = String(digits.prefix(1))
            minuteDigits = String(digits.suffix(2))
        } else {
            return nil
        }
        guard let minutes = Int(minuteDigits) else { return nil }

        var parts: [String] = []
        parts.append(contentsOf: spellHourDigits(hourDigits))
        parts.append("HUNDRED")
        if minutes != 0 {
            parts.append("AND")
            parts.append(contentsOf: underThousand(minutes))
        }
        return parts
    }

    private static func spellHourDigits(_ digits: String) -> [String] {
        if digits.count == 2, digits.hasPrefix("0") {
            if digits == "00" { return ["ZERO"] }
            return ["ZERO", digitWord(digits.last!)]
        }
        guard let value = Int(digits) else { return ["ZERO"] }
        if value == 0 { return ["ZERO"] }
        return underThousand(value)
    }

    private static func spellIntegerPart(_ digits: String) -> String {
        guard !digits.isEmpty else { return "ZERO" }
        if digits.count > 1, digits.hasPrefix("0") {
            return digits.map { digitWord($0) }.joined(separator: " ")
        }
        if digits.count > 15 {
            return digits.map { digitWord($0) }.joined(separator: " ")
        }
        guard let value = UInt64(digits) else {
            return digits.map { digitWord($0) }.joined(separator: " ")
        }
        return cardinal(value)
    }

    // MARK: Cardinal English

    private static let small = [
        "ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE",
        "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN",
        "SEVENTEEN", "EIGHTEEN", "NINETEEN"
    ]

    private static let tens = [
        "", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"
    ]

    private static func digitWord(_ character: Character) -> String {
        guard let value = character.wholeNumberValue, (0...9).contains(value) else { return "ZERO" }
        return small[value]
    }

    static func cardinal(_ value: UInt64) -> String {
        if value == 0 { return "ZERO" }
        var remaining = value
        var parts: [String] = []
        let scales: [(UInt64, String)] = [
            (1_000_000_000_000, "TRILLION"),
            (1_000_000_000, "BILLION"),
            (1_000_000, "MILLION"),
            (1_000, "THOUSAND")
        ]
        for (scale, name) in scales {
            if remaining >= scale {
                let count = remaining / scale
                parts.append(contentsOf: underThousand(Int(count)))
                parts.append(name)
                remaining %= scale
            }
        }
        if remaining > 0 {
            parts.append(contentsOf: underThousand(Int(remaining)))
        }
        return parts.joined(separator: " ")
    }

    private static func underThousand(_ value: Int) -> [String] {
        var n = value
        var parts: [String] = []
        if n >= 100 {
            parts.append(small[n / 100])
            parts.append("HUNDRED")
            n %= 100
        }
        if n >= 20 {
            parts.append(tens[n / 10])
            n %= 10
            if n > 0 { parts.append(small[n]) }
        } else if n > 0 {
            parts.append(small[n])
        }
        return parts
    }
}
