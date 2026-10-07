import AppKit
import Foundation

let args = CommandLine.arguments

if args.contains("--self-test") {
    let failures = EnigmaSelfTest.run()
    if failures.isEmpty {
        print("SELF-TEST OK")
        print("REGRESSION codebook recovery: V-ring / IV-plug sheet, 4 rotors, grouped-cipher round-trip.")
        print("Wiki vector AAAAA → BDZGO, XOR Z → Y2A7X, U-264, Scharnhorst, Dönitz indicator,")
        print("double-step, M4/M3 compatibility, settings and codebook round-trip, number spelling.")
        exit(0)
    } else {
        let regressions = failures.filter { $0.name.hasPrefix("REGRESSION") }
        if !regressions.isEmpty {
            fputs("REGRESSION FAILED — codebook parse would lose the original text (\(regressions.count))\n", stderr)
        }
        fputs("SELF-TEST FAILED (\(failures.count))\n", stderr)
        for failure in failures {
            fputs("  \(failure.name)\n    expected: \(failure.expected)\n    actual:   \(failure.actual)\n", stderr)
        }
        exit(1)
    }
}

if args.contains("--help") || args.contains("-h") {
    print("""
    Enigma XOR \(AppInfo.version) — historical M3 / M4, plus an XOR-Schlüssel

    Usage:
      EnigmaXOR                      Launch the app
      EnigmaXOR --self-test          Check historical vectors and the XOR step
      EnigmaXOR FILE.txt             Open a text file (or settings/codebook) at launch

    There is no custom archive. Ciphertext is plain text. An empty XOR key is
    historical Enigma. With a key, encipher is rotors then XOR, and values
    26–31 are the digits 2–7. On encipher, digits in the message become
    English words. Machine settings and codebooks are separate plain-text sheets.
    """)
    exit(0)
}

autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
